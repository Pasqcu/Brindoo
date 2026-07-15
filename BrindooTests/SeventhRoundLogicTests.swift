//
//  SeventhRoundLogicTests.swift
//  BrindooTests
//
//  Rete di sicurezza sulle logiche del settimo giro:
//  richieste dei clienti (bacheca inversa) e pacchetti prezzo.
//

import XCTest
@testable import Brindoo

final class SeventhRoundLogicTests: XCTestCase {

    // MARK: - Richieste clienti

    private func request(
        eventDate: String? = nil,
        budget: Double? = nil,
        status: ClientRequestStatus = .open
    ) -> ClientRequest {
        ClientRequest(
            id: UUID(),
            clientId: UUID(),
            title: "Fotografo per matrimonio",
            description: nil,
            area: "Latina",
            eventDate: eventDate,
            budget: budget,
            categoryId: nil,
            status: status,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    func test_dataEvento_leggibileInItaliano() {
        let r = request(eventDate: "2026-09-20")
        XCTAssertEqual(r.eventDateDisplay, "20 settembre 2026")
    }

    func test_dataEvento_assente_oNonValida() {
        XCTAssertNil(request(eventDate: nil).eventDateDisplay)
        XCTAssertNil(request(eventDate: "non-una-data").eventDateDisplay)
    }

    func test_budget_interoSenzaDecimali() {
        let display = request(budget: 800).budgetDisplay
        XCTAssertNotNil(display)
        XCTAssertTrue(display!.contains("800"))
        XCTAssertFalse(display!.contains(",00"))
    }

    func test_budget_assente() {
        XCTAssertNil(request(budget: nil).budgetDisplay)
    }

    func test_statoRichiesta_etichette() {
        XCTAssertEqual(ClientRequestStatus.open.displayName, "Aperta")
        XCTAssertEqual(ClientRequestStatus.closed.displayName, "Chiusa")
    }

    // MARK: - Pacchetti prezzo

    private func package(price: Double) -> OfferPackage {
        OfferPackage(
            id: UUID(),
            offerId: UUID(),
            name: "Base",
            description: nil,
            price: price,
            sortOrder: 0
        )
    }

    func test_prezzoPacchetto_interoSenzaDecimali() {
        let display = package(price: 350).priceDisplay
        XCTAssertTrue(display.contains("350"))
        XCTAssertFalse(display.contains(",00"))
    }

    func test_prezzoPacchetto_conDecimali() {
        let display = package(price: 99.5).priceDisplay
        XCTAssertTrue(display.contains("99,50"))
    }

    // MARK: - Conto alla rovescia evento

    func test_contoAllaRovescia_giorniMancanti() {
        // 2026-07-15 12:00 UTC → all'evento del 20/07 mancano 5 giorni.
        let now = Date(timeIntervalSince1970: 1_784_116_800)
        XCTAssertEqual(EventCountdownRow.daysUntil("2026-07-20", from: now), 5)
        XCTAssertEqual(EventCountdownRow.daysUntil("2026-07-15", from: now), 0)
    }

    func test_contoAllaRovescia_dataPassata_negativa() {
        let now = Date(timeIntervalSince1970: 1_784_116_800)
        let days = EventCountdownRow.daysUntil("2026-07-10", from: now)
        XCTAssertNotNil(days)
        XCTAssertLessThan(days!, 0)
    }

    func test_contoAllaRovescia_formatoNonValido() {
        XCTAssertNil(EventCountdownRow.daysUntil("20/07/2026"))
    }
}
