//
//  DepositAndTrustTests.swift
//  BrindooTests
//
//  Prove sulle regole nuove: stato dell'acconto (dichiarato / confermato)
//  e distintivo di affidabilità del cliente.
//

import XCTest
@testable import Brindoo

final class DepositAndTrustTests: XCTestCase {

    // MARK: - Acconto

    private func proposal(
        organizerId: UUID = UUID(),
        clientId: UUID = UUID(),
        price: Double = 500,
        depositAmount: Double? = nil,
        depositMethod: String? = nil,
        declaredBy: UUID? = nil,
        declaredAt: String? = nil,
        confirmedBy: UUID? = nil,
        confirmedAt: String? = nil
    ) throws -> OfferProposal {
        var json: [String: Any] = [
            "id": UUID().uuidString,
            "offer_id": UUID().uuidString,
            "client_id": clientId.uuidString,
            "organizer_id": organizerId.uuidString,
            "current_price": price,
            "last_proposer": "client",
            "status": "accepted",
            "created_at": "2026-01-01T10:00:00Z",
            "updated_at": "2026-01-01T10:00:00Z"
        ]
        json["deposit_amount"] = depositAmount
        json["deposit_method"] = depositMethod
        json["deposit_declared_by"] = declaredBy?.uuidString
        json["deposit_declared_at"] = declaredAt
        json["deposit_confirmed_by"] = confirmedBy?.uuidString
        json["deposit_confirmed_at"] = confirmedAt

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(OfferProposal.self, from: data)
    }

    func test_accontoNonRegistrato() throws {
        let p = try proposal()
        XCTAssertFalse(p.isDepositPaid)
        XCTAssertFalse(p.isDepositAwaitingConfirmation)
    }

    func test_dichiaratoMaNonConfermato_nonVale() throws {
        let organizer = UUID()
        let p = try proposal(
            organizerId: organizer,
            depositAmount: 100,
            declaredBy: organizer,
            declaredAt: "2026-05-01T10:00:00Z"
        )
        XCTAssertFalse(p.isDepositPaid, "Senza conferma dell'altra parte non è versato")
        XCTAssertTrue(p.isDepositAwaitingConfirmation)
    }

    func test_confermaSpettaAllAltraParte() throws {
        let organizer = UUID()
        let client = UUID()
        let p = try proposal(
            organizerId: organizer,
            clientId: client,
            depositAmount: 100,
            declaredBy: organizer,
            declaredAt: "2026-05-01T10:00:00Z"
        )
        XCTAssertTrue(p.canConfirmDeposit(as: client))
        XCTAssertFalse(p.canConfirmDeposit(as: organizer), "Chi dichiara non può confermarsi da solo")
    }

    func test_accontoConfermato_valeEMostraIlResto() throws {
        let organizer = UUID()
        let client = UUID()
        let p = try proposal(
            organizerId: organizer,
            clientId: client,
            price: 500,
            depositAmount: 150,
            depositMethod: "cash",
            declaredBy: organizer,
            declaredAt: "2026-05-01T10:00:00Z",
            confirmedBy: client,
            confirmedAt: "2026-05-01T11:00:00Z"
        )
        XCTAssertTrue(p.isDepositPaid)
        XCTAssertFalse(p.isDepositAwaitingConfirmation)
        XCTAssertEqual(p.depositMethod, .cash)
        XCTAssertNotNil(p.balanceDueDisplay, "350 € restano da saldare")
    }

    func test_accontoPariAlTotale_nessunResto() throws {
        let p = try proposal(price: 300, depositAmount: 300,
                             declaredBy: UUID(), declaredAt: "2026-05-01T10:00:00Z",
                             confirmedBy: UUID(), confirmedAt: "2026-05-01T11:00:00Z")
        XCTAssertNil(p.balanceDueDisplay)
    }

    // MARK: - Affidabilità cliente

    func test_nessunDistintivoSottoDueEventi() {
        let trust = ClientTrust(clientId: UUID(), honoredCount: 1, noShowCount: 0,
                                cancelledLateCount: 0, totalCount: 1)
        XCTAssertNil(trust.badge, "Un solo evento non basta per etichettare qualcuno")
    }

    func test_clienteAffidabile() {
        let trust = ClientTrust(clientId: UUID(), honoredCount: 4, noShowCount: 0,
                                cancelledLateCount: 0, totalCount: 4)
        let badge = trust.badge
        XCTAssertEqual(badge?.isPositive, true)
        XCTAssertTrue(badge?.label.contains("affidabile") == true)
    }

    func test_problemiRicorrenti_distintivoDiAvviso() {
        let trust = ClientTrust(clientId: UUID(), honoredCount: 1, noShowCount: 2,
                                cancelledLateCount: 1, totalCount: 4)
        XCTAssertEqual(trust.badge?.isPositive, false)
    }

    func test_qualcheProblemaMaMaggioranzaOk_restaNeutro() {
        let trust = ClientTrust(clientId: UUID(), honoredCount: 5, noShowCount: 1,
                                cancelledLateCount: 0, totalCount: 6)
        XCTAssertEqual(trust.badge?.isPositive, true)
    }

    // MARK: - Ricerca salvata

    func test_riassuntoRicercaSalvata() {
        let categoria = ServiceCategory(
            id: UUID(), slug: "music", name: "Musica e DJ", icon: "music.note",
            description: nil, sortOrder: 1, isActive: true, createdAt: Date()
        )
        let search = SavedSearch(
            name: "DJ",
            categoryIds: [categoria.id],
            areaSlugs: [],
            searchText: "dj",
            minRating: 4,
            maxPrice: 500
        )
        let summary = search.summary(categories: [categoria])
        XCTAssertTrue(summary.contains("Musica e DJ"))
        XCTAssertTrue(summary.contains("tutto il Lazio"))
        XCTAssertTrue(summary.contains("4 stelle"))
    }
}
