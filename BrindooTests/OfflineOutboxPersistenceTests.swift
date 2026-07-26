//
//  OfflineOutboxPersistenceTests.swift
//  BrindooTests
//
//  I messaggi scritti senza linea restano in coda sul telefono. Il momento
//  in cui l'utente se ne accorge davvero è la riapertura dell'app: se la
//  coda non si rilegge com'era stata scritta, il messaggio sparisce senza
//  che nessuno lo abbia mai inviato.
//
//  Qui si verifica proprio quel passaggio: scrittura su disco, rilettura
//  dallo stesso posto e con lo stesso tipo che usa l'app all'avvio.
//

import XCTest
@testable import Brindoo

final class OfflineOutboxPersistenceTests: XCTestCase {

    private func makeKey() -> String { "brindoo_test_outbox_\(UUID().uuidString)" }

    /// Riavvio dell'app: la coda salvata deve tornare com'era.
    ///
    /// Nota: la cache scrive le date in formato ISO 8601, che tiene i secondi
    /// interi. Il momento di scrittura torna quindi arrotondato al secondo —
    /// va bene per una coda di invio, ma vuol dire che due azioni create
    /// nello stesso secondo si distinguono solo per l'ordine nella lista.
    func test_codaSopravviveAlRiavvio() async {
        let key = makeKey()
        let conversation = UUID()
        let replied = UUID()
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        let queue = [
            PendingAction(createdAt: created, conversationId: conversation, text: "Ciao, sei libero il 12?"),
            PendingAction(createdAt: created, conversationId: conversation, text: "Ti ho risposto qui", repliedToId: replied, attempts: 2)
        ]

        await LocalCacheStore.shared.save(queue, for: key)
        let reloaded = await LocalCacheStore.shared.load([PendingAction].self, for: key)

        XCTAssertEqual(reloaded, queue)
        await LocalCacheStore.shared.remove(for: key)
    }

    /// Il momento di scrittura sopravvive al riavvio con la precisione al
    /// secondo garantita dal formato usato dalla cache.
    func test_dataDiScritturaSopravviveAlSecondo() async {
        let key = makeKey()
        let action = PendingAction(conversationId: UUID(), text: "Adesso")

        await LocalCacheStore.shared.save([action], for: key)
        let reloaded = await LocalCacheStore.shared.load([PendingAction].self, for: key) ?? []

        let scarto = abs((reloaded.first?.createdAt.timeIntervalSince1970 ?? 0) - action.createdAt.timeIntervalSince1970)
        XCTAssertLessThan(scarto, 1)
        await LocalCacheStore.shared.remove(for: key)
    }

    /// L'ordine di scrittura è l'ordine di invio: non deve cambiare.
    func test_ordineDellaCodaRimaneQuelloDiScrittura() async {
        let key = makeKey()
        let conversation = UUID()
        let queue = (1...5).map {
            PendingAction(
                createdAt: Date(timeIntervalSince1970: TimeInterval(1_700_000_000 + $0)),
                conversationId: conversation,
                text: "Messaggio \($0)"
            )
        }

        await LocalCacheStore.shared.save(queue, for: key)
        let reloaded = await LocalCacheStore.shared.load([PendingAction].self, for: key) ?? []

        XCTAssertEqual(reloaded.map(\.text), queue.map(\.text))
        await LocalCacheStore.shared.remove(for: key)
    }

    /// Il conteggio dei tentativi va salvato: senza, un messaggio che il
    /// server rifiuta ripartirebbe da zero a ogni riavvio, per sempre.
    func test_tentativiFallitiVengonoSalvati() async {
        let key = makeKey()
        let action = PendingAction(conversationId: UUID(), text: "Terzo tentativo", attempts: 3)

        await LocalCacheStore.shared.save([action], for: key)
        let reloaded = await LocalCacheStore.shared.load([PendingAction].self, for: key) ?? []

        XCTAssertEqual(reloaded.first?.attempts, 3)
        await LocalCacheStore.shared.remove(for: key)
    }

    /// Prima installazione o cache ripulita: nessuna coda, nessun errore.
    func test_codaAssenteNonRompeLAvvio() async {
        let reloaded = await LocalCacheStore.shared.load([PendingAction].self, for: makeKey())
        XCTAssertNil(reloaded)
    }
}
