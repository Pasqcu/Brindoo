//
//  AccountService.swift
//  Brindoo
//
//  Service per operazioni di gestione dell'account:
//  cancellazione completa (richiesta Apple per pubblicazione App Store).
//

import Foundation
import Supabase

@MainActor
final class AccountService {
    
    static let shared = AccountService()
    private init() {}
    
    private var client: SupabaseClient {
        SupabaseManager.shared.client
    }
    
    /// Elimina l'account dell'utente corrente in modo definitivo.
    /// Cancella: profilo, conversazioni, messaggi, richieste, candidature,
    /// recensioni, portfolio (DB + Storage), e l'utente in auth.users.
    func deleteMyAccount() async throws {
        guard let userId = SupabaseManager.shared.currentUserID else {
            throw NSError(domain: "AccountService", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Devi essere loggato"])
        }
        
        // 1. Cancella file Storage (best effort, prima del DB)
        await deleteUserStorageFiles(userId: userId)
        
        // 2. Chiama la RPC che cancella tutti i record DB e l'utente auth
        do {
            try await client
                .rpc("delete_my_account")
                .execute()
            
            BrindooLog.info("Account eliminato")
        } catch {
            BrindooLog.error("Errore eliminazione account: \(error)")
            throw error
        }
        
        // 3. Forza signOut locale (la sessione è ormai invalida)
        try? await SupabaseManager.shared.auth.signOut()
    }
    
    /// Cancella avatar e tutte le foto del portfolio dallo Storage.
    /// Best effort: se fallisce, prosegue comunque (i record DB verranno cancellati).
    private func deleteUserStorageFiles(userId: UUID) async {
        let userFolder = userId.uuidString
        
        // Avatars: lista i file nella cartella e cancellali
        do {
            let files = try await SupabaseManager.shared.storage
                .from("avatars")
                .list(path: userFolder)
            
            if !files.isEmpty {
                let paths = files.map { "\(userFolder)/\($0.name)" }
                _ = try await SupabaseManager.shared.storage
                    .from("avatars")
                    .remove(paths: paths)
            }
        } catch {
            BrindooLog.error("Errore cancellazione avatars: \(error)")
        }
        
        // Portfolio: lista e cancella
        do {
            let files = try await SupabaseManager.shared.storage
                .from("portfolio")
                .list(path: userFolder)
            
            if !files.isEmpty {
                let paths = files.map { "\(userFolder)/\($0.name)" }
                _ = try await SupabaseManager.shared.storage
                    .from("portfolio")
                    .remove(paths: paths)
            }
        } catch {
            BrindooLog.error("Errore cancellazione portfolio: \(error)")
        }
    }
}
