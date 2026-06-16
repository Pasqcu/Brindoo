//
//  SupabaseManager.swift
//  Brindoo
//
//  Gestore centrale per la connessione a Supabase.
//  Tutta l'app accede al backend tramite SupabaseManager.shared.client
//
//  USO TIPICO:
//  - Query tabelle:   SupabaseManager.shared.client.from("servizi").select()...
//  - Funzioni RPC:    SupabaseManager.shared.client.rpc("nome_funzione")...
//  - Auth:            SupabaseManager.shared.auth.signIn(...)
//  - Storage:         SupabaseManager.shared.storage.from("avatars")...
//  - Realtime (chat): SupabaseManager.shared.realtime...
//

import Foundation
import Supabase

/// Singleton che espone il client Supabase configurato.
@MainActor
final class SupabaseManager {
    
    /// Istanza condivisa unica per tutta l'app
    static let shared = SupabaseManager()
    
    /// Client Supabase configurato con URL e anon key.
    /// È l'oggetto principale: da qui si accede a from(), rpc(), schema(), ecc.
    let client: SupabaseClient
    
    private init() {
        guard let url = URL(string: Secrets.supabaseURL) else {
            fatalError("⚠️ URL Supabase non valido. Controlla Secrets.swift")
        }

        self.client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: Secrets.supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }
    
    // MARK: - Helper di accesso rapido
    
    /// Auth (login, registrazione, sign in with apple)
    var auth: AuthClient {
        client.auth
    }
    
    /// Storage (upload foto profilo, portfolio, mood-board)
    var storage: SupabaseStorageClient {
        client.storage
    }
    
    /// Realtime (chat in tempo reale, broadcast eventi)
    var realtime: RealtimeClientV2 {
        client.realtimeV2
    }
    
    // MARK: - Sessione corrente
    
    /// Restituisce true se c'è un utente loggato
    var isAuthenticated: Bool {
        client.auth.currentSession != nil
    }
    
    /// ID dell'utente loggato, nil se non autenticato
    var currentUserID: UUID? {
        client.auth.currentUser?.id
    }
}
