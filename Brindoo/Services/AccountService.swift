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
    ///
    /// Tutto avviene sul server (edge function `delete-account`): prima i
    /// dati, con l'avviso alle controparti degli accordi ancora da svolgere,
    /// poi foto e vocali. Prima l'app cancellava i file per primi: se la
    /// parte dati falliva si restava con l'account vivo e le foto sparite.
    func deleteMyAccount() async throws {
        guard SupabaseManager.shared.currentUserID != nil else {
            throw BrindooServiceError.notLoggedIn
        }

        do {
            try await client.functions.invoke("delete-account")
            BrindooLog.info("Account eliminato")
        } catch {
            BrindooLog.error("Errore eliminazione account: \(error)")
            throw error
        }

        // La sessione è ormai invalida: si esce anche in locale.
        try? await SupabaseManager.shared.auth.signOut()
    }
}
