//
//  PendingAgreementWarningTests.swift
//  BrindooTests
//
//  L'avviso mostrato prima di tagliare i ponti con qualcuno (blocco,
//  cancellazione della chat) quando c'è ancora un impegno aperto.
//  Prima questa regola viveva dentro ChatView e non era verificabile.
//

import XCTest
@testable import Brindoo

@MainActor
final class PendingAgreementWarningTests: XCTestCase {

    private func proposal(
        status: String = "accepted",
        bookingStatus: String? = "confirmed",
        eventDate: String? = nil,
        price: Double = 500
    ) throws -> OfferProposal {
        var json: [String: Any] = [
            "id": UUID().uuidString,
            "offer_id": UUID().uuidString,
            "client_id": UUID().uuidString,
            "organizer_id": UUID().uuidString,
            "current_price": price,
            "last_proposer": "client",
            "status": status,
            "created_at": "2026-01-01T10:00:00Z",
            "updated_at": "2026-01-01T10:00:00Z"
        ]
        json["booking_status"] = bookingStatus
        json["event_date"] = eventDate

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(OfferProposal.self, from: data)
    }

    private var domani: String {
        let d = BrindooFormat.dayCalendar.date(byAdding: .day, value: 1, to: BrindooFormat.startOfDay())!
        return BrindooFormat.dayString(from: d)
    }

    private var ieri: String {
        let d = BrindooFormat.dayCalendar.date(byAdding: .day, value: -1, to: BrindooFormat.startOfDay())!
        return BrindooFormat.dayString(from: d)
    }

    func test_eventoFuturoConcordato_avvisaConDataEPrezzo() throws {
        let p = try proposal(eventDate: domani, price: 750)
        let avviso = try XCTUnwrap(p.pendingAgreementWarning)
        XCTAssertTrue(avviso.contains("evento concordato"), avviso)
        XCTAssertTrue(avviso.contains("750"), avviso)
    }

    func test_accordoSenzaData_avvisaComunque() throws {
        let p = try proposal(eventDate: nil, price: 300)
        let avviso = try XCTUnwrap(p.pendingAgreementWarning)
        XCTAssertTrue(avviso.contains("data ancora da fissare"), avviso)
        XCTAssertTrue(avviso.contains("300"), avviso)
    }

    func test_eventoGiaPassato_nessunAvviso() throws {
        let p = try proposal(eventDate: ieri)
        XCTAssertNil(p.pendingAgreementWarning)
    }

    func test_trattativaNonAccettata_nessunAvviso() throws {
        let p = try proposal(status: "pending", eventDate: domani)
        XCTAssertNil(p.pendingAgreementWarning)
    }

    func test_appuntamentoAnnullato_nessunAvviso() throws {
        let p = try proposal(bookingStatus: "cancelled", eventDate: domani)
        XCTAssertNil(p.pendingAgreementWarning)
    }

    func test_appuntamentoSvolto_nessunAvviso() throws {
        let p = try proposal(bookingStatus: "completed", eventDate: domani)
        XCTAssertNil(p.pendingAgreementWarning)
    }
}
