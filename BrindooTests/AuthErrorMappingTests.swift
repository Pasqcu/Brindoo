//
//  AuthErrorMappingTests.swift
//  BrindooTests
//
//  Gli errori del server di autenticazione arrivano in inglese: a schermo
//  deve andare sempre una frase italiana.
//

import XCTest
@testable import Brindoo

@MainActor
final class AuthErrorMappingTests: XCTestCase {

    private struct ServerError: LocalizedError {
        let errorDescription: String?
        init(_ text: String) { errorDescription = text }
    }

    private func mapped(_ text: String) -> BrindooAuthError {
        AuthService.shared.mapError(ServerError(text))
    }

    func test_limiteDiRichieste_diventaTroppiTentativi() {
        XCTAssertEqual(mapped("Email rate limit exceeded"), .tooManyAttempts)
        XCTAssertEqual(mapped("For security purposes, you can only request this after 60 seconds."), .tooManyAttempts)
    }

    func test_emailNonSpedita_haUnaFraseItaliana() {
        XCTAssertEqual(mapped("Error sending recovery email"), .emailNotSent)
    }

    func test_erroreSconosciuto_nonMostraIlTestoDelServer() {
        let error = mapped("Signups not allowed for this instance")
        XCTAssertEqual(error.errorDescription, "Qualcosa non ha funzionato. Riprova tra poco.")
    }

    func test_credenzialiSbagliate_restanoRiconosciute() {
        XCTAssertEqual(mapped("Invalid login credentials"), .invalidCredentials)
    }
}
