//
//  NegotiationLogicTests.swift
//  BrindooTests
//
//  Rete di sicurezza sulla logica delle trattative: a chi tocca rispondere,
//  stato dell'appuntamento e date evento.
//

import XCTest
@testable import Brindoo

final class NegotiationLogicTests: XCTestCase {

    private let clientId = UUID()
    private let organizerId = UUID()

    private func proposal(
        lastProposer: ProposerRole = .client,
        status: OfferProposalStatus = .pending,
        eventDate: String? = nil,
        bookingStatus: BookingStatus? = nil
    ) -> OfferProposal {
        OfferProposal(
            id: UUID(),
            offerId: UUID(),
            clientId: clientId,
            organizerId: organizerId,
            currentPrice: 350,
            lastProposer: lastProposer,
            lastMessage: nil,
            status: status,
            eventDate: eventDate,
            bookingStatus: bookingStatus,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    // MARK: - A chi tocca rispondere

    func test_propostaDelCliente_toccaAlProfessionista() {
        let p = proposal(lastProposer: .client)
        XCTAssertTrue(p.awaitingAction(by: organizerId))
        XCTAssertFalse(p.awaitingAction(by: clientId))
    }

    func test_controproposta_toccaAlCliente() {
        let p = proposal(lastProposer: .organizer)
        XCTAssertTrue(p.awaitingAction(by: clientId))
        XCTAssertFalse(p.awaitingAction(by: organizerId))
    }

    func test_trattativaConclusa_nonAspettaNessuno() {
        for status in [OfferProposalStatus.accepted, .rejected, .withdrawn] {
            let p = proposal(status: status)
            XCTAssertFalse(p.awaitingAction(by: clientId))
            XCTAssertFalse(p.awaitingAction(by: organizerId))
        }
    }

    // MARK: - Stato appuntamento

    func test_accettataSenzaStato_eConfermata() {
        let p = proposal(status: .accepted, bookingStatus: nil)
        XCTAssertEqual(p.effectiveBooking, .confirmed)
    }

    func test_statoEsplicito_vince() {
        XCTAssertEqual(proposal(status: .accepted, bookingStatus: .cancelled).effectiveBooking, .cancelled)
        XCTAssertEqual(proposal(status: .accepted, bookingStatus: .completed).effectiveBooking, .completed)
    }

    // MARK: - Data evento

    func test_eventoPassato() {
        XCTAssertTrue(proposal(eventDate: "2000-01-01").isEventPast)
    }

    func test_eventoFuturo_oSenzaData_nonEPassato() {
        XCTAssertFalse(proposal(eventDate: "2999-12-31").isEventPast)
        XCTAssertFalse(proposal(eventDate: nil).isEventPast)
        XCTAssertFalse(proposal(eventDate: "data-non-valida").isEventPast)
    }

    func test_dataEventoLeggibile() {
        XCTAssertEqual(proposal(eventDate: "2026-05-21").eventDateDisplay, "21 maggio 2026")
        XCTAssertNil(proposal(eventDate: nil).eventDateDisplay)
    }
}
