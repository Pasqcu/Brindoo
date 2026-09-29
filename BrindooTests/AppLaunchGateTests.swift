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
