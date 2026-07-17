//
//  PurchaseService.swift
//  Brindoo
//
//  Service che gestisce gli acquisti in-app tramite StoreKit 2.
//

import Foundation
import StoreKit
import Supabase

/// Identificatori prodotti (devono corrispondere ad App Store Connect)
enum BrindooProduct {
    static let proMonthly = "com.pasqcu.Brindoo.pro.monthly"
    static let boostDay = "com.pasqcu.Brindoo.boost.1day"
    static let boostWeek = "com.pasqcu.Brindoo.boost.1week"
    
    static let allIds: Set<String> = [proMonthly, boostDay, boostWeek]
    
    /// I prodotti consumabili (boost) — non sono entitlement permanenti
    static let consumables: Set<String> = [boostDay, boostWeek]
    
    /// Prodotti subscription (Pro)
    static let subscriptions: Set<String> = [proMonthly]
}

@MainActor
@Observable
final class PurchaseService {
    
    static let shared = PurchaseService()
    
    /// Prodotti caricati da App Store
    private(set) var products: [Product] = []
    
    /// True quando sta caricando i prodotti o un'operazione è in corso
    private(set) var isLoading: Bool = false
    
    /// Listener delle transazioni (StoreKit chiama questo continuously).
    /// Non viene mai cancellato perché PurchaseService è singleton
    /// e vive per tutta la durata dell'app.
    private var transactionListener: Task<Void, Never>?
    
    private var client: SupabaseClient {
        SupabaseManager.shared.client
    }
    
    private init() {
        // Avvia ascolto transazioni in background
        transactionListener = listenForTransactions()
    }
    
    // MARK: - Caricamento prodotti
    
    /// Carica i prodotti da App Store Connect (o dallo StoreKit Configuration File se attivo)
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let storeProducts = try await Product.products(for: BrindooProduct.allIds)
            
            // Ordina: subscription prima, poi consumable per prezzo
            self.products = storeProducts.sorted { lhs, rhs in
                if lhs.type == .autoRenewable && rhs.type != .autoRenewable {
                    return true
                }
                if lhs.type != .autoRenewable && rhs.type == .autoRenewable {
                    return false
                }
                return lhs.price < rhs.price
            }
            
            BrindooLog.info("Caricati \(products.count) prodotti")
        } catch {
            BrindooLog.error("Errore caricamento prodotti: \(error)")
        }
    }
    
    /// Cerca un prodotto per ID
    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }
    
    // MARK: - Acquisto
    
    enum PurchaseResult {
        case success
        case userCancelled
        case pending          // attesa autorizzazione (es. parental controls)
        case failed(Error)
    }
    
    /// Avvia l'acquisto di un prodotto
    func purchase(_ product: Product) async -> PurchaseResult {
        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                // La verifica client-side passa solo il `verified`, ma per anti-frode
                // serve anche la re-verifica server-side. Passiamo il JWS firmato
                // alla Edge Function `validate-iap-receipt` che verifica la firma
                // Apple e aggiorna gli entitlement con service_role.
                await submitToServer(verification: verification)
                await transaction.finish()
                return .success

            case .userCancelled:
                return .userCancelled

            case .pending:
                return .pending

            @unknown default:
                return .failed(NSError(
                    domain: "PurchaseService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Stato sconosciuto"]
                ))
            }
        } catch {
            BrindooLog.error("Errore acquisto: \(error)")
            return .failed(error)
        }
    }
    
    // MARK: - Restore
    
    /// Ripristina gli acquisti (richiamabile da bottone "Ripristina acquisti")
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            BrindooLog.info("Acquisti ripristinati")
        } catch {
            BrindooLog.error("Errore restore: \(error)")
        }
    }
    
    // MARK: - Aggiornamento entitlements

    /// Re-invia al server TUTTE le transazioni attive (subscription + consumable
    /// non scaduti). Utile all'avvio dell'app, dopo restore o cambio device.
    ///
    /// La Edge Function `validate-iap-receipt` ricalcola gli entitlement DB
    /// in modo idempotente. Non aggiorniamo più i campi `profiles.pro_expires_at`
    /// e `boost_expires_at` direttamente: il trigger DB (vedi migration
    /// 20260515_reports_and_compliance.sql) li blocca per i client.
    func refreshEntitlements() async {
        for await result in Transaction.currentEntitlements {
            guard SupabaseManager.shared.currentUserID != nil else { return }
            await submitToServer(verification: result)
        }
    }

    // MARK: - Server submission

    /// Body request per la Edge Function `validate-iap-receipt`.
    /// Estratto fuori da `submitToServer` perché Swift non permette di
    /// dichiarare struct nested in funzioni generiche.
    private struct ValidateReceiptBody: Encodable {
        let signed_transaction: String
    }

    /// Invia il JWS firmato Apple alla Edge Function `validate-iap-receipt`,
    /// che ne verifica la firma e aggiorna l'entitlement DB con service_role.
    private func submitToServer(verification: VerificationResult<Transaction>) async {
        // Estraggo il JWS originale firmato da Apple.
        // `jwsRepresentation` è disponibile solo su VerificationResult<Transaction>
        // (e su altre specializzazioni concrete), non sul generico.
        let jws = verification.jwsRepresentation

        do {
            _ = try await client.functions
                .invoke(
                    "validate-iap-receipt",
                    options: FunctionInvokeOptions(
                        body: ValidateReceiptBody(signed_transaction: jws)
                    )
                )
            BrindooLog.info("Entitlement validato server-side")
        } catch {
            BrindooLog.error("Errore validazione server-side: \(error)")
        }
    }

    // MARK: - Listener transazioni

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { continue }
                // Verifica client-side rapida (per sicurezza locale).
                do {
                    let transaction = try await self.checkVerified(result)
                    // Invia al server per la verifica autoritativa.
                    await self.submitToServer(verification: result)
                    await transaction.finish()
                } catch {
                    BrindooLog.error("Transazione non verificata: \(error)")
                }
            }
        }
    }

    // MARK: - Verifica crittografica StoreKit

    enum StoreError: Error {
        case failedVerification
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            throw StoreError.failedVerification
        }
    }
}
