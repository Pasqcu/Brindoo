//
//  AppLaunchGateTests.swift
//  BrindooTests
//
//  I fogli del primo avvio (benvenuto e spiegazione delle notifiche) vanno
//  in fila: aperti insieme si chiudevano a vicenda.
//

import XCTest
@testable import Brindoo

@MainActor
final class AppLaunchGateTests: XCTestCase {

    private let gate = AppLaunchGate.shared

    override func tearDown() async throws {
        gate.releaseLaunchSheet(.welcome)
        gate.releaseLaunchSheet(.notifications)
    }

    func test_conBenvenutoAperto_laSpiegazioneAspettaIlSuoTurno() {
        XCTAssertTrue(gate.claimLaunchSheet(.welcome))
        XCTAssertFalse(gate.claimLaunchSheet(.notifications))

        gate.releaseLaunchSheet(.welcome)

        XCTAssertNil(gate.launchSheet)
        XCTAssertTrue(gate.claimLaunchSheet(.notifications))
        XCTAssertEqual(gate.launchSheet, .notifications)
    }

    func test_chiudereUnFoglioNonSuo_nonLiberaIlTurno() {
        XCTAssertTrue(gate.claimLaunchSheet(.notifications))

        gate.releaseLaunchSheet(.welcome)

        XCTAssertEqual(gate.launchSheet, .notifications)
    }

    func test_ripetereLaPrenotazioneDelloStessoFoglio_restaValida() {
        XCTAssertTrue(gate.claimLaunchSheet(.welcome))
        XCTAssertTrue(gate.claimLaunchSheet(.welcome))
    }
}

/// Il pannello dei Termini non deve aprirsi e richiudersi in un lampo
/// davanti a chi ha appena accettato nell'onboarding.
@MainActor
final class TermsGateTests: XCTestCase {

    private let key = "brindoo.legal.acceptedTermsAt"
    private var savedLocalConsent: String?

    override func setUp() async throws {
        savedLocalConsent = UserDefaults.standard.string(forKey: key)
    }

    override func tearDown() async throws {
        UserDefaults.standard.set(savedLocalConsent, forKey: key)
    }

    private func clientWithoutTerms() throws -> Profile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Profile.self, from: Data("""
        {"id":"\(UUID())","role":"client","full_name":"Martina Rossi","city":"Roma","province":"RM",
         "created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}
        """.utf8))
    }

    func test_consensoLocaleInAttesa_pannelloNonSiApre() throws {
        UserDefaults.standard.set("2026-09-29T08:00:00Z", forKey: key)
        let session = SessionStore()
        session.updateLocalProfile(try clientWithoutTerms())

        XCTAssertTrue(session.hasPendingLocalTermsConsent)
        XCTAssertFalse(session.showsTermsGate)
        XCTAssertFalse(session.showsLegalGate)
    }

    func test_registrazioneSilenziosaFallita_pannelloSiApre() throws {
        UserDefaults.standard.set("2026-09-29T08:00:00Z", forKey: key)
        let session = SessionStore()
        session.updateLocalProfile(try clientWithoutTerms())

        session.silentTermsRecordFailed = true

        XCTAssertTrue(session.showsTermsGate)
    }

    func test_senzaConsensoSuQuestoTelefono_pannelloSiApre() throws {
        UserDefaults.standard.removeObject(forKey: key)
        let session = SessionStore()
        session.updateLocalProfile(try clientWithoutTerms())

        XCTAssertFalse(session.hasPendingLocalTermsConsent)
        XCTAssertTrue(session.showsTermsGate)
    }
}
