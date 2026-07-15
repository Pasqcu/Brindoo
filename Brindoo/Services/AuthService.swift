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
    case emailAlreadyRegistered
    case invalidCredentials
    case userNotFound
    case networkError
    case emailNotConfirmed
    case appleSignInCancelled
    case appleSignInFailed
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
             (.emailAlreadyRegistered, .emailAlreadyRegistered),
             (.invalidCredentials, .invalidCredentials),
             (.userNotFound, .userNotFound),
             (.networkError, .networkError),
             (.emailNotConfirmed, .emailNotConfirmed),
             (.appleSignInCancelled, .appleSignInCancelled),
             (.appleSignInFailed, .appleSignInFailed):
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

    var isValid: Bool {
        hasMinLength && hasNumber && hasSpecialChar
    }

    /// Numero di criteri soddisfatti (per progress bar 0/3, 1/3, 2/3, 3/3)
    var strengthLevel: Int {
        [hasMinLength, hasNumber, hasSpecialChar].filter { $0 }.count
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
            hasSpecialChar: hasSpecialChar
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
        if !validation.hasNumber { return .passwordMissingNumber }
        if !validation.hasSpecialChar { return .passwordMissingSpecialChar }
        return nil
    }

    // MARK: - Registrazione email

    func signUp(email: String, password: String) async throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard isValidEmail(trimmedEmail) else {
            throw BrindooAuthError.invalidEmail
        }

        if let error = passwordError(password) {
            throw error
        }

        do {
            _ = try await auth.signUp(
                email: trimmedEmail,
                password: password,
                redirectTo: redirectURL
            )
            print("✅ Registrazione completata per: \(trimmedEmail)")
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
            print("✅ Login effettuato per: \(trimmedEmail)")
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
            print("✅ Logout effettuato")
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
            print("✅ Login con Apple effettuato")
        } catch {
            BrindooLog.error("Errore login Apple: \(error)")
            throw mapError(error)
        }
    }

    // MARK: - Deep link

    func handleDeepLink(_ url: URL) async {
        do {
            try await auth.session(from: url)
            print("✅ Sessione attivata via deep link")
        } catch {
            BrindooLog.error("Errore handle deep link: \(error)")
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
            print("✅ Richiesta cambio email inviata a: \(trimmed)")
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
                redirectTo: redirectURL
            )
            print("✅ Email di reset password inviata a: \(trimmedEmail)")
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
