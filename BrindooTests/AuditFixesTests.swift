//
//  AuditFixesTests.swift
//  BrindooTests
//
//  Regole rese uniche dopo l'audit del 2026-09-23: chi può recensire,
//  quando un evento si segna svolto, cosa vuol dire "torno il", da dove
//  viene il Pro, quando una richiesta è scaduta, come si leggono i
//  rifiuti del database. Sono le stesse regole dei trigger sul server.
//

import XCTest
@testable import Brindoo

@MainActor
final class AuditFixesTests: XCTestCase {

    private let client = UUID()
    private let organizer = UUID()

    private func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    private func day(_ offset: Int) -> String {
        let d = BrindooFormat.dayCalendar.date(byAdding: .day, value: offset, to: BrindooFormat.startOfDay())!
        return BrindooFormat.dayString(from: d)
    }

    private func proposal(status: String = "accepted", booking: String? = "confirmed", eventDate: String?) throws -> OfferProposal {
        var json: [String: Any] = [
            "id": UUID().uuidString,
            "offer_id": UUID().uuidString,
            "client_id": client.uuidString,
            "organizer_id": organizer.uuidString,
            "current_price": 500,
            "last_proposer": "client",
            "status": status,
            "created_at": "2026-01-01T10:00:00Z",
            "updated_at": "2026-01-01T10:00:00Z"
        ]
        json["booking_status"] = booking
        json["event_date"] = eventDate
        return try decoder().decode(OfferProposal.self, from: JSONSerialization.data(withJSONObject: json))
    }

    private func profile(vacationUntil: String? = nil, iap: String? = nil, bonus: String? = nil, pro: String? = nil) throws -> Profile {
        var json: [String: Any] = [
            "id": UUID().uuidString,
            "role": "organizer",
            "created_at": "2026-01-01T10:00:00Z",
            "updated_at": "2026-01-01T10:00:00Z"
        ]
        json["vacation_until"] = vacationUntil
        json["iap_pro_expires_at"] = iap
        json["bonus_pro_expires_at"] = bonus
        json["pro_expires_at"] = pro
        return try decoder().decode(Profile.self, from: JSONSerialization.data(withJSONObject: json))
    }

    // MARK: - Recensioni

    func testRecensioneSoloDopoEventoSvoltoONonAnnullato() throws {
        XCTAssertTrue(try proposal(booking: "completed", eventDate: day(0)).allowsReview(by: client))
        XCTAssertTrue(try proposal(booking: "confirmed", eventDate: day(-2)).allowsReview(by: client))
        // Annullato con data passata: prima dava una recensione "verificata".
        XCTAssertFalse(try proposal(booking: "cancelled", eventDate: day(-2)).allowsReview(by: client))
        XCTAssertFalse(try proposal(booking: "confirmed", eventDate: day(3)).allowsReview(by: client))
        XCTAssertFalse(try proposal(booking: "completed", eventDate: day(-2)).allowsReview(by: organizer))
        XCTAssertFalse(try proposal(status: "pending", booking: nil, eventDate: day(-2)).allowsReview(by: client))
    }

    func testSvoltoSoloDalGiornoDellEvento() throws {
        XCTAssertTrue(try proposal(eventDate: day(0)).canMarkCompleted)
        XCTAssertTrue(try proposal(eventDate: day(-1)).canMarkCompleted)
        XCTAssertFalse(try proposal(eventDate: day(1)).canMarkCompleted)
        XCTAssertFalse(try proposal(eventDate: nil).canMarkCompleted)
    }

    func testPrenotazioneMancanteValeConfermata() throws {
        XCTAssertEqual(try proposal(status: "pending", booking: nil, eventDate: nil).effectiveBooking, .confirmed)
    }

    // MARK: - Vacanza

    func testGiornoDelRitornoNonEVacanza() throws {
        let p = try profile(vacationUntil: day(3))
        XCTAssertTrue(p.isOnVacation)
        let dayBefore = BrindooFormat.day(from: day(2))!
        let returnDay = BrindooFormat.day(from: day(3))!
        XCTAssertTrue(p.isOnVacation(on: dayBefore))
        XCTAssertFalse(p.isOnVacation(on: returnDay))
        XCTAssertFalse(try profile(vacationUntil: day(0)).isOnVacation)
        XCTAssertFalse(try profile().isOnVacation)
    }

    // MARK: - Fonti del Pro

    func testProRegalatoEPagatoDistinti() throws {
        let future = BrindooFormat.iso(Date().addingTimeInterval(20 * 86_400))
        let past = BrindooFormat.iso(Date().addingTimeInterval(-86_400))
        let gifted = try profile(iap: past, bonus: future, pro: future)
        XCTAssertTrue(gifted.isPro)
        XCTAssertTrue(gifted.hasOnlyGiftedPro)
        XCTAssertFalse(gifted.hasPaidPro)

        let paid = try profile(iap: future, bonus: nil, pro: future)
        XCTAssertTrue(paid.hasPaidPro)
        XCTAssertFalse(paid.hasOnlyGiftedPro)
    }

    // MARK: - Richieste

    func testRichiestaConDataPassataEScaduta() throws {
        func request(_ eventDate: String?) throws -> ClientRequest {
            var json: [String: Any] = [
                "id": UUID().uuidString,
                "client_id": UUID().uuidString,
                "title": "Fotografo",
                "area": "roma",
                "status": "open",
                "created_at": "2026-01-01T10:00:00Z",
                "updated_at": "2026-01-01T10:00:00Z"
            ]
            json["event_date"] = eventDate
            return try decoder().decode(ClientRequest.self, from: JSONSerialization.data(withJSONObject: json))
        }
        XCTAssertTrue(try request(day(-1)).isExpired)
        XCTAssertFalse(try request(day(0)).isExpired)
        XCTAssertFalse(try request(nil).isExpired)
    }

    // MARK: - Rifiuti del database

    func testRegoleDelServerTradotte() {
        struct Fake: Error, CustomStringConvertible { let description: String }
        XCTAssertEqual(
            BrindooErrorText.serverRule(Fake(description: "PostgrestError(message: \"Utente bloccato: non potete interagire\")")),
            "Non puoi interagire con questo utente."
        )
        XCTAssertEqual(
            BrindooErrorText.serverRule(Fake(description: "Data occupata: il professionista ha gia' un evento confermato quel giorno")),
            "Il professionista ha già un evento confermato in quella data."
        )
        XCTAssertNil(BrindooErrorText.serverRule(Fake(description: "timeout")))
    }
}
