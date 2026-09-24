//
//  AuthService.swift
//  Brindoo
//
//  Service che gestisce le operazioni di autenticazione:
//  - Validazione email e password
//  - Sign up / sign in / sign out
//  - Sign in with Apple
//  - Recupero password e deep link
//

import Foundation
import Supabase
import Auth
import AuthenticationServices

// MARK: - Errori auth

/// Errori di autenticazione user-friendly
enum BrindooAuthError: LocalizedError, Equatable {
    case invalidEmail
    case weakPassword
    case passwordMissingNumber
    case passwordMissingSpecialChar
    case passwordMissingCase
    case emailAlreadyRegistered
    case invalidCredentials
    case userNotFound
    case networkError
    case emailNotConfirmed
    case appleSignInCancelled
    case appleSignInFailed
    case googleSignInCancelled
    case googleSignInFailed
    case googleSignInExpired
    case samePassword
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Inserisci un'email valida"
        case .weakPassword:
            return "La password deve avere almeno 8 caratteri"
        case .passwordMissingNumber:
            return "La password deve contenere almeno un numero"
        case .passwordMissingSpecialChar:
            return "La password deve contenere almeno un carattere speciale (es. !@#$%)"
        case .passwordMissingCase:
            return "La password deve contenere almeno una lettera maiuscola e una minuscola"
        case .emailAlreadyRegistered:
            return "Questa email è già registrata. Prova ad accedere."
        case .invalidCredentials:
            return "Email o password non corrette"
        case .userNotFound:
            return "Nessun account trovato con questa email"
        case .networkError:
            return "Connessione assente. Controlla internet e riprova."
        case .emailNotConfirmed:
            return "Conferma prima la tua email cliccando sul link che ti abbiamo inviato"
        case .appleSignInCancelled:
            return "Accesso con Apple annullato"
        case .appleSignInFailed:
            return "Impossibile accedere con Apple. Riprova."
        case .googleSignInCancelled:
            return "Accesso con Google annullato"
        case .googleSignInFailed:
            return "Impossibile accedere con Google. Riprova."
        case .googleSignInExpired:
            return "L'accesso ha impiegato troppo tempo ed è scaduto. Tocca di nuovo \"Continua con Google\": stavolta sarà più rapido."
        case .samePassword:
            return "La nuova password deve essere diversa da quella attuale"
        case .unknown(let message):
            return message
        }
    }

    // MARK: Equatable
    static func == (lhs: BrindooAuthError, rhs: BrindooAuthError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidEmail, .invalidEmail),
             (.weakPassword, .weakPassword),
             (.passwordMissingNumber, .passwordMissingNumber),
             (.passwordMissingSpecialChar, .passwordMissingSpecialChar),
             (.passwordMissingCase, .passwordMissingCase),
             (.samePassword, .samePassword),
             (.emailAlreadyRegistered, .emailAlreadyRegistered),
             (.invalidCredentials, .invalidCredentials),
             (.userNotFound, .userNotFound),
             (.networkError, .networkError),
             (.emailNotConfirmed, .emailNotConfirmed),
             (.appleSignInCancelled, .appleSignInCancelled),
             (.appleSignInFailed, .appleSignInFailed),
             (.googleSignInCancelled, .googleSignInCancelled),
             (.googleSignInFailed, .googleSignInFailed),
             (.googleSignInExpired, .googleSignInExpired):
            return true
        case (.unknown(let a), .unknown(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - Validazione password (UI feedback)

/// Stato di validazione di una password (per UI feedback live)
struct PasswordValidation {
    let hasMinLength: Bool      // almeno 8 caratteri
    let hasNumber: Bool          // almeno 1 cifra
    let hasSpecialChar: Bool     // almeno 1 carattere speciale
    // Maiuscola e minuscola le pretende il server (policy password di
    // Supabase Auth): senza questi due controlli la lista diventava tutta
    // verde e poi la registrazione falliva con un messaggio in inglese.
    let hasUppercase: Bool
    let hasLowercase: Bool

    private var criteria: [Bool] {
        [hasMinLength, hasUppercase, hasLowercase, hasNumber, hasSpecialChar]
    }

    static let criteriaCount = 5

    var isValid: Bool {
        criteria.allSatisfy { $0 }
    }

    /// Numero di criteri soddisfatti (per la barra di robustezza)
    var strengthLevel: Int {
        criteria.filter { $0 }.count
    }
}

// MARK: - Service

@MainActor
final class AuthService {

    static let shared = AuthService()
    private init() {}

    private var auth: AuthClient {
        SupabaseManager.shared.auth
    }

    /// URL di redirect per email di conferma e reset password (deep link).
    private var redirectURL: URL {
        URL(string: "com.pasqcu.brindoo://auth/callback")!
    }

    // MARK: - Validazione

    func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }

    /// Valida una password e restituisce dettaglio per la UI live
    func validatePassword(_ password: String) -> PasswordValidation {
        let hasMinLength = password.count >= 8
        let hasNumber = password.contains { $0.isNumber }

        // Caratteri speciali: punteggiatura comune e simboli ASCII
        let specialChars = "!@#$%^&*()_-+=[]{}|\\:;\"'<>,.?/~`"
        let hasSpecialChar = password.contains { specialChars.contains($0) }

        return PasswordValidation(
            hasMinLength: hasMinLength,
            hasNumber: hasNumber,
            hasSpecialChar: hasSpecialChar,
            hasUppercase: password.contains { $0.isUppercase },
            hasLowercase: password.contains { $0.isLowercase }
        )
    }

    /// Versione boolean rapida
    func isValidPassword(_ password: String) -> Bool {
        validatePassword(password).isValid
    }

    /// Restituisce l'errore specifico per la prima validazione fallita
    private func passwordError(_ password: String) -> BrindooAuthError? {
        let validation = validatePassword(password)
        if !validation.hasMinLength { return .weakPassword }
        if !validation.hasUppercase || !validation.hasLowercase { return .passwordMissingCase }
        if !validation.hasNumber { return .passwordMissingNumber }
        if !validation.hasSpecialChar { return .passwordMissingSpecialChar }
        return nil
    }

    // MARK: - Registrazione email

    /// Registra l'account. Restituisce true se serve confermare l'email
    /// prima di entrare, false se il server ha già aperto la sessione
    /// (conferma email spenta nel progetto: `mailer_autoconfirm`).
    @discardableResult
    func signUp(email: String, password: String) async throws -> Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard isValidEmail(trimmedEmail) else {
            throw BrindooAuthError.invalidEmail
        }

        if let error = passwordError(password) {
            throw error
        }

        do {
            let response = try await auth.signUp(
                email: trimmedEmail,
                password: password,
                redirectTo: redirectURL
            )
            BrindooLog.info("Registrazione completata")
            return response.session == nil
        } catch {
            BrindooLog.error("Errore registrazione: \(error)")
            throw mapError(error)
        }
    }

    // MARK: - Login email

    func signIn(email: String, password: String) async throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard isValidEmail(trimmedEmail) else {
            throw BrindooAuthError.invalidEmail
        }
        guard !password.isEmpty else {
            throw BrindooAuthError.invalidCredentials
        }

        do {
            _ = try await auth.signIn(
                email: trimmedEmail,
                password: password
            )
            BrindooLog.info("Login effettuato")
        } catch {
            BrindooLog.error("Errore login: \(error)")
            throw mapError(error)
        }
    }

    // MARK: - Logout

    /// Esegue il sign-out. Il SessionStore reagisce automaticamente via `authStateChanges`.
    /// Prima del signOut rimuoviamo i device token per evitare che l'utente
    /// continui a ricevere push notification dopo aver fatto logout.
    func signOut() async {
        // Rimuovi device tokens PRIMA del signOut: dopo il signOut la sessione
        // è invalida e RLS rifiuta la DELETE.
        await NotificationService.shared.removeDeviceToken()

        // Termina tutte le Live Activity attive al logout per evitare che
        // restino visibili in Lock Screen dopo il cambio utente.
        await LiveActivityManager.shared.endAll()

        do {
            try await auth.signOut()
            BrindooLog.info("Logout effettuato")
        } catch {
            BrindooLog.error("Errore logout: \(error.localizedDescription)")
        }
    }

    // MARK: - Sign in with Apple

    func signInWithApple(credential: ASAuthorizationAppleIDCredential, nonce: String) async throws {
        guard let identityTokenData = credential.identityToken else {
            throw BrindooAuthError.appleSignInFailed
        }

        guard let idTokenString = String(data: identityTokenData, encoding: .utf8) else {
            throw BrindooAuthError.appleSignInFailed
        }

        do {
            try await auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .apple,
                    idToken: idTokenString,
                    nonce: nonce
                )
            )
            BrindooLog.info("Login con Apple effettuato")
        } catch {
            BrindooLog.error("Errore login Apple: \(error)")
            throw mapError(error)
        }

        // Apple manda il nome solo al primo accesso e non sta nel token:
        // se non lo si mette da parte adesso, poi bisognerebbe chiederlo
        // all'utente, e le regole di Apple lo vietano (Guideline 4).
        if let name = Self.displayName(from: credential.fullName) {
            do {
                try await auth.update(user: UserAttributes(data: ["full_name": .string(name)]))
            } catch {
                BrindooLog.error("Nome da Apple non salvato: \(error)")
            }
        }
    }

    private static func displayName(from components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let name = PersonNameComponentsFormatter()
            .string(from: components)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    /// Nome arrivato dal fornitore dell'accesso (Apple o Google), se c'è.
    var providerFullName: String? {
        guard let metadata = auth.currentUser?.userMetadata else { return nil }
        for key in ["full_name", "name"] {
            if case .string(let value)? = metadata[key] {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }

    /// True se l'account è entrato con "Accedi con Apple": a queste persone
    /// il nome non si può chiedere come obbligatorio.
    var isAppleAccount: Bool {
        auth.currentUser?.identities?.contains { $0.provider == "apple" } ?? false
    }

    // MARK: - Sign in with Google

    /// Indirizzo a cui Google rimanda al termine dell'accesso. Lo schema
    /// `com.pasqcu.brindoo` è già registrato in Info.plist.
    static let oauthRedirectURL = URL(string: "com.pasqcu.brindoo://login-callback")!

    /// Accesso con account Google.
    ///
    /// Apre la pagina di Google in una finestra sicura di sistema
    /// (`ASWebAuthenticationSession`): la password viene digitata da Google,
    /// l'app non la vede mai. Al ritorno Supabase crea o ritrova l'account
    /// con la stessa email.
    func signInWithGoogle() async throws {
        do {
            try await auth.signInWithOAuth(
                provider: .google,
                redirectTo: Self.oauthRedirectURL
            ) { session in
                // Ogni tentativo parte pulito.
                //
                // Con la sessione condivisa di Safari, dopo un tentativo
                // fallito il browser rigiocava la pagina di ritorno vecchia:
                // il secondo tentativo arrivava con un codice già consumato
                // ("both auth code and code verifier should be non-empty").
                // Perdiamo il riconoscimento automatico dell'account Google
                // già attivo, ma il giro diventa ripetibile e prevedibile.
                session.prefersEphemeralWebBrowserSession = true
            }
            BrindooLog.info("Login con Google effettuato")
        } catch {
            if Self.isUserCancellation(error) {
                throw BrindooAuthError.googleSignInCancelled
            }
            // Il gettone temporaneo di Supabase dura pochi minuti: se
            // l'utente ci mette troppo sulla pagina di Google, scade.
            if "\(error)".contains("bad_oauth_state")
                || "\(error)".contains("OAuth state has expired") {
                BrindooLog.error("Accesso Google scaduto: \(error)")
                throw BrindooAuthError.googleSignInExpired
            }
            BrindooLog.error("Errore login Google: \(error)")
            throw mapError(error)
        }
    }

    /// L'utente ha chiuso la finestra di Google senza completare.
    private static func isUserCancellation(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == ASWebAuthenticationSessionErrorDomain
            && nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue
    }

    // MARK: - Deep link

    /// Indirizzo a cui rimanda il link di reset. Con il flusso PKCE il link
    /// porta solo `?code=` e la libreria non emette `passwordRecovery`: è da
    /// questo percorso che si capisce che l'utente deve scegliere una nuova
    /// password. Già ammesso sul server da `com.pasqcu.brindoo://**`.
    static let passwordResetURL = URL(string: "com.pasqcu.brindoo://auth/reset")!

    static func isPasswordResetLink(_ url: URL) -> Bool {
        url.scheme == passwordResetURL.scheme
            && url.host == passwordResetURL.host
            && url.path == passwordResetURL.path
    }

    /// Esito di un link di autenticazione: serve solo a sapere se aprire la
    /// schermata della nuova password.
    enum DeepLinkOutcome {
        case handled
        case passwordRecovery
        case passwordRecoveryFailed
    }

    @discardableResult
    func handleDeepLink(_ url: URL) async -> DeepLinkOutcome {
        let isReset = Self.isPasswordResetLink(url)
        do {
            try await auth.session(from: url)
            BrindooLog.info("Sessione attivata via deep link")
            return isReset ? .passwordRecovery : .handled
        } catch {
            BrindooLog.error("Errore handle deep link: \(error)")
            return isReset ? .passwordRecoveryFailed : .handled
        }
    }

    /// Nuova password dopo il link di reset (l'utente ha già la sessione).
    func updatePassword(_ newPassword: String) async throws {
        if let error = passwordError(newPassword) {
            throw error
        }
        do {
            try await auth.update(user: UserAttributes(password: newPassword))
            BrindooLog.info("Password aggiornata")
        } catch {
            BrindooLog.error("Errore aggiornamento password: \(error)")
            throw mapError(error)
        }
    }

    // MARK: - Cambio email

    /// Avvia il cambio email per l'utente loggato. Supabase invia una mail di
    /// conferma al NUOVO indirizzo: il cambio è effettivo solo dopo che l'utente
    /// clicca sul link ricevuto. Fino a quel momento l'email di login resta la vecchia.
    func updateEmail(_ newEmail: String) async throws {
        let trimmed = newEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard isValidEmail(trimmed) else {
            throw BrindooAuthError.invalidEmail
        }

        do {
            _ = try await auth.update(user: UserAttributes(email: trimmed))
            BrindooLog.info("Richiesta cambio email inviata")
        } catch {
            BrindooLog.error("Errore cambio email: \(error)")
            throw mapError(error)
        }
    }

    // MARK: - Recupero password

    func resetPassword(email: String) async throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard isValidEmail(trimmedEmail) else {
            throw BrindooAuthError.invalidEmail
        }

        do {
            try await auth.resetPasswordForEmail(
                trimmedEmail,
                redirectTo: Self.passwordResetURL
            )
            BrindooLog.info("Email di reset password inviata")
        } catch {
            BrindooLog.error("Errore reset password: \(error)")
            throw mapError(error)
        }
    }

    // MARK: - Mapping errori

    private func mapError(_ error: Error) -> BrindooAuthError {
        let description = error.localizedDescription.lowercased()

        if description.contains("invalid login credentials") ||
           description.contains("invalid_credentials") {
            return .invalidCredentials
        }
        if description.contains("user already registered") ||
           description.contains("already_registered") ||
           description.contains("user_already_exists") {
            return .emailAlreadyRegistered
        }
        if description.contains("email not confirmed") ||
           description.contains("not_confirmed") {
            return .emailNotConfirmed
        }
        if description.contains("user not found") {
            return .userNotFound
        }
        if description.contains("should be different from the old password") ||
           description.contains("same_password") {
            return .samePassword
        }
        if description.contains("password should contain") {
            return .passwordMissingCase
        }
        if description.contains("password should be at least") ||
           description.contains("weak_password") {
            return .weakPassword
        }
        if description.contains("invalid email") {
            return .invalidEmail
        }
        if description.contains("network") ||
           description.contains("offline") ||
           description.contains("internet") {
            return .networkError
        }

        return .unknown(error.localizedDescription)
    }
}
