//
//  SixthRoundLogicTests.swift
//  BrindooTests
//
//  Rete di sicurezza sulle logiche del sesto giro:
//  etichetta "Nuovo" e archivio risposte rapide.
//

import XCTest
@testable import Brindoo

final class SixthRoundLogicTests: XCTestCase {

    // MARK: - Etichetta "Nuovo"

    private func offer(createdDaysAgo days: Double, now: Date) -> ServiceOffer {
        ServiceOffer(
            id: UUID(),
            organizerId: UUID(),
            title: "Test",
            description: "Descrizione di prova",
            coverageArea: "Roma",
            price: 100,
            status: .active,
            imageUrl: nil,
            createdAt: now.addingTimeInterval(-days * 24 * 60 * 60),
            updatedAt: now
        )
    }

    func test_offertaFresca_eNuova() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertTrue(offer(createdDaysAgo: 0, now: now).isNew(asOf: now))
        XCTAssertTrue(offer(createdDaysAgo: 6.9, now: now).isNew(asOf: now))
    }

    func test_offertaVecchia_nonENuova() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertFalse(offer(createdDaysAgo: 7.1, now: now).isNew(asOf: now))
        XCTAssertFalse(offer(createdDaysAgo: 30, now: now).isNew(asOf: now))
    }

    // MARK: - Risposte rapide

    private var testDefaults: UserDefaults {
        let d = UserDefaults(suiteName: "brindoo.tests.quickreplies")!
        d.removePersistentDomain(forName: "brindoo.tests.quickreplies")
        return d
    }

    func test_senzaSalvataggi_usaLeFrasiDiDefault() {
        XCTAssertEqual(QuickRepliesStore.load(defaults: testDefaults), QuickRepliesStore.defaultReplies)
    }

    func test_salvaECarica() {
        let d = testDefaults
        QuickRepliesStore.save(["Ciao!", "A presto"], defaults: d)
        XCTAssertEqual(QuickRepliesStore.load(defaults: d), ["Ciao!", "A presto"])
    }

    func test_salvataggio_scartaFrasiVuoteERispettaIlLimite(){
        let d = testDefaults
        let tante = (1...20).map { "Frase \($0)" } + ["   ", ""]
        QuickRepliesStore.save(tante, defaults: d)
        let caricate = QuickRepliesStore.load(defaults: d)
        XCTAssertEqual(caricate.count, QuickRepliesStore.maxCount)
        XCTAssertFalse(caricate.contains(where: { $0.trimmingCharacters(in: .whitespaces).isEmpty }))
    }

    func test_listaVuotaSalvata_restaVuota() {
        let d = testDefaults
        QuickRepliesStore.save([], defaults: d)
        XCTAssertEqual(QuickRepliesStore.load(defaults: d), [])
    }
}
