//
//  SessionStore.swift
//  Brindoo
//
//  Stato globale dell'utente: gestisce login, logout, profilo corrente.
//  Tutta l'app osserva questo oggetto per sapere se l'utente è loggato
//  e se il suo profilo è stato completato.
//

import Foundation
import SwiftUI
import Observation
import Supabase
import Auth

/// Stato di autenticazione dell'utente
enum AuthState {
    /// Stiamo controllando se c'è una sessione salvata o caricando il profilo
    case loading

    /// Utente non loggato → mostra onboarding/login
    case signedOut

    /// Utente loggato ma profilo da completare → mostra setup profilo
    case profileSetup

    /// Utente loggato con profilo completo → mostra app principale
    case signedIn
}

@Observable
@MainActor
final class SessionStore {

    /// Stato corrente dell'autenticazione
    private(set) var authState: AuthState = .loading

    /// Email dell'utente loggato (se disponibile)
    private(set) var userEmail: String?

    /// ID univoco dell'utente loggato
    private(set) var userID: UUID?

    /// Profilo dell'utente corrente (nome, ruolo, città, ecc.)
    private(set) var currentProfile: Profile?

    /// Utente Supabase corrente (se loggato).
    @ObservationIgnored
    private var currentUser: User?

    /// Task che ascolta i cambiamenti di sessione
    @ObservationIgnored
    private var authStateTask: Task<Void, Never>?

    init() {
        // All'avvio dell'app, controlla se c'è una sessione attiva
        Task { [weak self] in
            await self?.checkInitialSession()
            self?.startListeningToAuthChanges()
        }
    }

    deinit {
        authStateTask?.cancel()
    }

    // MARK: - Controllo sessione iniziale

    private func checkInitialSession() async {
        do {
            let session = try await SupabaseManager.shared.auth.session
            self.applyUser(session.user)
            await loadProfileAndUpdateState()
            print("✅ Sessione attiva trovata per: \(session.user.email ?? "nessuna email")")
        } catch {
            self.clearUser()
            self.authState = .signedOut
            print("ℹ️ Nessuna sessione attiva")
        }
    }

    // MARK: - Listener cambiamenti auth

    private func startListeningToAuthChanges() {
        authStateTask = Task { [weak self] in
            for await (event, session) in SupabaseManager.shared.auth.authStateChanges {
                guard let self else { return }

                switch event {
                case .signedIn, .tokenRefreshed, .userUpdated:
                    if let user = session?.user {
                        self.applyUser(user)
                        await self.loadProfileAndUpdateState()
                    }

                case .signedOut:
                    self.clearUser()
                    self.authState = .signedOut

                case .initialSession:
                    // Con `emitLocalSessionAsInitialSession: true` la sessione locale
                    // viene emessa subito, anche se scaduta: aspettiamo il refresh
                    // (tokenRefreshed) prima di considerare l'utente loggato.
                    if let session, !session.isExpired {
                        self.applyUser(session.user)
                        await self.loadProfileAndUpdateState()
                    } else if session == nil {
                        self.authState = .signedOut
                    }

                default:
                    break
                }
            }
        }
    }

    // MARK: - Caricamento profilo

    /// Carica il profilo da Supabase e aggiorna lo stato dell'app
    private func loadProfileAndUpdateState() async {
        self.authState = .loading

        do {
            var profile = try await ProfileService.shared.fetchCurrentProfile()

            // Se il profilo non esiste (trigger non eseguito), crealo
            if profile == nil {
                print("ℹ️ Profilo mancante, lo creo...")
                profile = try await ProfileService.shared.createProfileIfNeeded()
            }

            self.currentProfile = profile

            if let profile, profile.isComplete {
                self.authState = .signedIn
            } else {
                self.authState = .profileSetup
            }

        } catch {
            print("❌ Errore caricamento profilo: \(error.localizedDescription)")
            self.authState = .profileSetup
        }
    }

    /// Ricarica il profilo (chiamabile dopo un update manuale)
    func reloadProfile() async {
        await loadProfileAndUpdateState()
    }

    /// Aggiorna direttamente il profilo locale (dopo update riuscito)
    func updateLocalProfile(_ profile: Profile) {
        self.currentProfile = profile
        if profile.isComplete {
            self.authState = .signedIn
        } else {
            self.authState = .profileSetup
        }
    }

    // MARK: - Helpers privati

    private func applyUser(_ user: User) {
        self.currentUser = user
        self.userEmail = user.email
        self.userID = user.id
    }

    private func clearUser() {
        self.currentUser = nil
        self.userEmail = nil
        self.userID = nil
        self.currentProfile = nil
    }

    // MARK: - Logout

    /// Delega ad AuthService.signOut(). Mantenuto per retrocompatibilità con le view.
    func signOut() async {
        await AuthService.shared.signOut()
    }
}
