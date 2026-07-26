//
//  NinthRoundLogicTests.swift
//  BrindooTests
//
//  Rete di sicurezza sulle logiche del nono giro:
//  riepilogo accordo, regole di annullamento e mesi di punta.
//

import XCTest
@testable import Brindoo

final class NinthRoundLogicTests: XCTestCase {

    private func offer(title: String = "DJ set per matrimonio") -> ServiceOffer {
        ServiceOffer(
            id: UUID(),
            organizerId: UUID(),
            title: title,
            description: "Descrizione di prova",
            coverageArea: "Roma",
            price: 500,
            status: .active,
            imageUrl: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    private func proposal(
        price: Double = 450,
        eventDate: String? = "2026-09-12",
        depositPaid: Bool? = nil,
        lastMessage: String? = nil
    ) -> OfferProposal {
        OfferProposal(
            id: UUID(),
            offerId: UUID(),
            clientId: UUID(),
            organizerId: UUID(),
            currentPrice: price,
            lastProposer: .organizer,
            lastMessage: lastMessage,
            status: .accepted,
            eventDate: eventDate,
            bookingStatus: .confirmed,
            depositPaid: depositPaid,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    // MARK: - Riepilogo accordo

    func test_riepilogo_contieneDatiPrincipali() {
        let text = AgreementSummary.text(
            offer: offer(),
            organizerName: "Marco Bianchi",
            proposal: proposal(depositPaid: true, lastMessage: "Pacchetto Completo")
        )
        XCTAssertTrue(text.contains("DJ set per matrimonio"))
        XCTAssertTrue(text.contains("Marco Bianchi"))
        XCTAssertTrue(text.contains("450"))
        XCTAssertTrue(text.contains("12 settembre 2026"))
        XCTAssertTrue(text.contains("Acconto: versato"))
        XCTAssertTrue(text.contains("Pacchetto Completo"))
        XCTAssertTrue(text.contains("Regole di annullamento"))
    }

    /// Il nome mancante si omette, la data mancante no: in un promemoria
    /// d'accordo il silenzio sulla data si legge come dimenticanza, quindi
    /// va scritto che è ancora da fissare.
    func test_riepilogo_senzaNome_ometteLaRiga_maDichiaraLaDataMancante() {
        let text = AgreementSummary.text(
            offer: offer(),
            organizerName: nil,
            proposal: proposal(eventDate: nil, depositPaid: nil)
        )
        XCTAssertFalse(text.contains("Professionista:"))
        XCTAssertFalse(text.contains("Cliente:"))
        XCTAssertTrue(text.contains("Data evento: ancora da definire"))
        XCTAssertTrue(text.contains("Acconto: non ancora versato"))
    }

    /// Il riepilogo vale come promemoria fra due persone: entrambe vanno
    /// nominate, e ci va la data in cui l'accordo è stato chiuso.
    func test_riepilogo_nominaEntrambeLePartiEPortaLaData() {
        let text = AgreementSummary.text(
            offer: offer(),
            organizerName: "Studio Rossi",
            clientName: "Anna Bianchi",
            proposal: proposal(eventDate: "2026-09-12", depositPaid: nil)
        )
        XCTAssertTrue(text.contains("Professionista: Studio Rossi"))
        XCTAssertTrue(text.contains("Cliente: Anna Bianchi"))
        XCTAssertTrue(text.contains("Accordo del "))
    }

    // MARK: - Regole di annullamento

    func test_regoleAnnullamento_presenti() {
        XCTAssertEqual(CancellationPolicy.rules.count, 4)
        XCTAssertFalse(CancellationPolicy.note.isEmpty)
        for rule in CancellationPolicy.rules {
            XCTAssertTrue(CancellationPolicy.summaryText.contains(rule))
        }
    }

    // MARK: - FAQ

    func test_faq_limiteEIdentita() {
        XCTAssertEqual(ProfileFAQ.maxCount, 5)
        let a = ProfileFAQ(question: "Porti l'attrezzatura?", answer: "Sì")
        let b = ProfileFAQ(question: "Porti l'attrezzatura?", answer: "No")
        XCTAssertNotEqual(a.id, b.id)
    }

    // MARK: - Mesi di punta

    func test_mesiDiPunta() {
        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: "Europe/Rome")!
        func day(month: Int) -> Date {
            cal.date(from: DateComponents(year: 2026, month: month, day: 15))!
        }
        XCTAssertTrue(Seasonality.isPeak(day(month: 5)))
        XCTAssertTrue(Seasonality.isPeak(day(month: 6)))
        XCTAssertTrue(Seasonality.isPeak(day(month: 7)), "luglio è pieno di matrimoni")
        XCTAssertTrue(Seasonality.isPeak(day(month: 9)))
        XCTAssertTrue(Seasonality.isPeak(day(month: 12)))
        XCTAssertFalse(Seasonality.isPeak(day(month: 2)))
        XCTAssertFalse(Seasonality.isPeak(day(month: 8)), "ad agosto il Lazio si svuota")
    }

    /// Sotto il mese di preavviso il consiglio cambia: non ha più senso
    /// dire "muoviti in anticipo" a chi l'anticipo non ce l'ha più.
    func test_preavvisoBreve() {
        let oggi = Date()
        let cal = Calendar.current
        XCTAssertTrue(Seasonality.isShortNotice(cal.date(byAdding: .day, value: 10, to: oggi)!, from: oggi))
        XCTAssertTrue(Seasonality.isShortNotice(oggi, from: oggi))
        XCTAssertFalse(Seasonality.isShortNotice(cal.date(byAdding: .day, value: 90, to: oggi)!, from: oggi))
    }
}
