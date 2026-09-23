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

    /// True quando l'abbonamento di questo ID Apple è già legato a un altro
    /// account Brindoo: il server lo tiene a quello, qui non diventa Pro.
    private(set) var subscriptionOwnedByOtherAccount: Bool = false

    /// Listener delle transazioni (StoreKit chiama questo continuously).
    /// Non viene mai cancellato perché PurchaseService è singleton
    /// e vive per tutta la durata dell'app.
    private var transactionListener: Task<Void, Never>?

    /// Allineamento con il server in corso: all'avvio lo chiedono sia l'app
    /// sia il login, e due giri insieme mandavano due volte le stesse
    /// transazioni.
    private var refreshTask: Task<Void, Never>?

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
        /// Pagamento riuscito ma il server non ha ancora registrato il diritto.
        /// La transazione resta aperta: StoreKit la riconsegna al prossimo avvio
        /// finché la registrazione non riesce, quindi l'acquisto non si perde.
        case pendingActivation
        case userCancelled
        case pending          // attesa autorizzazione (es. parental controls)
        case failed(Error)
    }

    /// Avvia l'acquisto di un prodotto
    func purchase(_ product: Product) async -> PurchaseResult {
        do {
            // L'acquisto porta con sé l'account Brindoo che lo fa: il server
            // lo assegna a lui, non a chiunque altro usi lo stesso ID Apple.
            var options: Set<Product.PurchaseOption> = []
            if let userId = SupabaseManager.shared.currentUserID {
                options.insert(.appAccountToken(userId))
            }
            let result = try await product.purchase(options: options)

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                // La verifica client-side passa solo il `verified`, ma per anti-frode
                // serve anche la re-verifica server-side. Passiamo il JWS firmato
                // alla Edge Function `validate-iap-receipt` che verifica la firma
                // Apple e aggiorna gli entitlement con service_role.
                //
                // La transazione si chiude SOLO se il server l'ha registrata:
                // chiuderla prima significava, con una rete ballerina, incassare
                // un Boost e non consegnarlo mai (i consumabili chiusi non
                // ricompaiono più in `currentEntitlements`).
                guard await submitToServer(verification: verification) != nil else {
                    return .pendingActivation
                }
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

    enum RestoreOutcome {
        /// Abbonamento attivo trovato e registrato su questo account.
        case restored
        /// Abbonamento attivo, ma appartiene a un altro account Brindoo.
        case ownedByOtherAccount
        /// Nessun abbonamento attivo su questo ID Apple.
        case nothingToRestore
        case failed
    }

    /// Ripristina gli acquisti (bottone "Ripristina") e dice com'è andata.
    func restorePurchases() async -> RestoreOutcome {
        do {
            try await AppStore.sync()
        } catch {
            BrindooLog.error("Errore restore: \(error)")
            return .failed
        }
        await refreshEntitlements()

        var foundPro = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == BrindooProduct.proMonthly {
                foundPro = true
            }
        }
        BrindooLog.info("Acquisti ripristinati")
        if !foundPro { return .nothingToRestore }
        return subscriptionOwnedByOtherAccount ? .ownedByOtherAccount : .restored
    }

    // MARK: - Stato dell'abbonamento Apple

    /// Quello che solo Apple sa: se l'abbonamento si rinnoverà da solo.
    struct SubscriptionState {
        let willAutoRenew: Bool
        let expiresAt: Date?
    }

    /// Stato dell'abbonamento Pro su questo ID Apple, `nil` se non ce n'è uno attivo.
    func proSubscriptionState() async -> SubscriptionState? {
        let product: Product?
        if let loaded = self.product(for: BrindooProduct.proMonthly) {
            product = loaded
        } else {
            product = try? await Product.products(for: [BrindooProduct.proMonthly]).first
        }
        guard let statuses = try? await product?.subscription?.status else { return nil }
        for status in statuses {
            switch status.state {
            case .subscribed, .inGracePeriod, .inBillingRetryPeriod:
                guard case .verified(let renewal) = status.renewalInfo,
                      case .verified(let transaction) = status.transaction else { continue }
                return SubscriptionState(
                    willAutoRenew: renewal.willAutoRenew,
                    expiresAt: transaction.expirationDate
                )
            default:
                continue
            }
        }
        return nil
    }

    // MARK: - Aggiornamento entitlements

    /// Re-invia al server TUTTE le transazioni attive (subscription + consumable
    /// non scaduti). Utile all'avvio dell'app, dopo restore o cambio device.
    ///
    /// La Edge Function `validate-iap-receipt` ricalcola gli entitlement DB
    /// in modo idempotente e li assegna all'account proprietario dell'acquisto.
    /// Un giro alla volta: chi chiama mentre ne è in corso uno aspetta quello.
    func refreshEntitlements() async {
        if let refreshTask {
            await refreshTask.value
            return
        }
        let task = Task { await performRefresh() }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    private func performRefresh() async {
        guard SupabaseManager.shared.currentUserID != nil else { return }

        var ownedElsewhere = false
        for await result in Transaction.currentEntitlements {
            let matches = await submitToServer(verification: result)
            if case .verified(let t) = result,
               t.productID == BrindooProduct.proMonthly,
               matches == false {
                ownedElsewhere = true
            }
        }
        subscriptionOwnedByOtherAccount = ownedElsewhere

        // Acquisti pagati e mai registrati sul server (rete caduta a metà):
        // si riprova adesso e si chiudono solo quando il server li accetta.
        for await result in Transaction.unfinished {
            guard case .verified(let transaction) = result else { continue }
            if await submitToServer(verification: result) != nil {
                await transaction.finish()
            }
        }
    }

    // MARK: - Server submission

    /// Body request per la Edge Function `validate-iap-receipt`.
    /// Estratto fuori da `submitToServer` perché Swift non permette di
    /// dichiarare struct nested in funzioni generiche.
    private struct ValidateReceiptBody: Encodable {
        let signed_transaction: String
    }

    private struct ValidateReceiptResponse: Decodable {
        let owner_matches: Bool?
    }

    /// Invia il JWS firmato Apple alla Edge Function `validate-iap-receipt`,
    /// che ne verifica la firma e aggiorna l'entitlement DB con service_role.
    /// - Returns: `nil` se il server non ha registrato nulla (la transazione
    ///   va lasciata aperta); altrimenti se l'acquisto appartiene a questo
    ///   account (`false` = legato a un altro account Brindoo).
    private func submitToServer(verification: VerificationResult<Transaction>) async -> Bool? {
        // Estraggo il JWS originale firmato da Apple.
        // `jwsRepresentation` è disponibile solo su VerificationResult<Transaction>
        // (e su altre specializzazioni concrete), non sul generico.
        let jws = verification.jwsRepresentation

        do {
            let response: ValidateReceiptResponse = try await client.functions
                .invoke(
                    "validate-iap-receipt",
                    options: FunctionInvokeOptions(
                        body: ValidateReceiptBody(signed_transaction: jws)
                    )
                )
            BrindooLog.info("Entitlement validato server-side")
            return response.owner_matches ?? true
        } catch {
            BrindooLog.error("Errore validazione server-side: \(error)")
            return nil
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
                    // Invia al server per la verifica autoritativa. Se il server
                    // non risponde, la transazione resta aperta e StoreKit la
                    // ripropone: meglio riprovare che perdere un acquisto pagato.
                    // Anche i rimborsi arrivano da qui: il server toglie il diritto.
                    if await self.submitToServer(verification: result) != nil {
                        await transaction.finish()
                    }
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
