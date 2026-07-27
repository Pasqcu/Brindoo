//
//  ChatViewModelTests.swift
//  BrindooTests
//
//  Le regole della chat, provate senza rete: cosa parte, cosa finisce in
//  coda quando la linea manca, cosa si svuota, chi può modificare cosa.
//  Prima vivevano dentro ChatView e nessun test poteva raggiungerle.
//

import XCTest
@testable import Brindoo

@MainActor
final class ChatViewModelTests: XCTestCase {

    // MARK: - Finte

    /// Registro di cosa è stato chiesto all'esterno durante la prova.
    private final class Spia {
        var inviati: [(text: String, replyId: UUID?)] = []
        var inCoda: [(text: String, replyId: UUID?)] = []
        var modificati: [(id: UUID, text: String)] = []
        var bozzaCancellata = 0
        var conversazioniEliminate = 0
        var bloccati: [UUID] = []
    }

    private let clientId = UUID()
    private let organizerId = UUID()
    private let conversationId = UUID()

    private func conversazione() throws -> Conversation {
        let json: [String: Any] = [
            "id": conversationId.uuidString,
            "client_id": clientId.uuidString,
            "organizer_id": organizerId.uuidString,
            "created_at": "2026-01-01T10:00:00Z",
            "last_message_at": "2026-01-01T10:00:00Z"
        ]
        return try decodifica(json, as: Conversation.self)
    }

    private func profilo(_ id: UUID) throws -> Profile {
        let json: [String: Any] = [
            "id": id.uuidString,
            "role": "organizer",
            "created_at": "2026-01-01T10:00:00Z",
            "updated_at": "2026-01-01T10:00:00Z"
        ]
        return try decodifica(json, as: Profile.self)
    }

    private func messaggio(
        id: UUID = UUID(),
        senderId: UUID,
        content: String = "ciao",
        createdAt: String? = nil,
        type: String = "text"
    ) throws -> Message {
        let json: [String: Any] = [
            "id": id.uuidString,
            "conversation_id": conversationId.uuidString,
            "sender_id": senderId.uuidString,
            "content": content,
            "created_at": createdAt ?? ISO8601DateFormatter().string(from: Date()),
            "message_type": type
        ]
        return try decodifica(json, as: Message.self)
    }

    private func decodifica<T: Decodable>(_ json: [String: Any], as type: T.Type) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }

    /// Modello pronto all'uso con prese finte.
    private func modello(
        spia: Spia,
        online: Bool = true,
        invioFallisce: Bool = false,
        modificaFallisce: Bool = false,
        eliminazioneFallisce: Bool = false,
        bloccoFallisce: Bool = false,
        bozzaSalvata: String = "",
        trattative: [OfferProposal] = [],
        giaBloccato: Bool = false
    ) throws -> ChatViewModel {
        var data = ChatDataSource.empty
        data.isOnline = { online }
        data.sendMessage = { _, text, replyId in
            if invioFallisce { throw NSError(domain: "test", code: 1) }
            spia.inviati.append((text, replyId))
        }
        data.enqueueMessage = { _, text, replyId in
            spia.inCoda.append((text, replyId))
        }
        data.editMessage = { id, text in
            if modificaFallisce { throw NSError(domain: "test", code: 2) }
            spia.modificati.append((id, text))
        }
        data.clearDraft = { _ in spia.bozzaCancellata += 1 }
        data.draft = { _ in bozzaSalvata }
        data.softDeleteConversation = { _ in
            if eliminazioneFallisce { throw NSError(domain: "test", code: 3) }
            spia.conversazioniEliminate += 1
        }
        data.block = { id in
            if bloccoFallisce { throw NSError(domain: "test", code: 4) }
            spia.bloccati.append(id)
        }
        data.isBlockingOrBlocked = { _ in giaBloccato }
        data.ongoingProposals = { trattative }

        return ChatViewModel(
            conversation: try conversazione(),
            otherUser: try profilo(organizerId),
            currentUserId: clientId,
            data: data
        )
    }

    // MARK: - Invio

    func test_conLinea_ilMessaggioParteENonFinisceInCoda() async throws {
        let spia = Spia()
        let vm = try modello(spia: spia)
        vm.inputText = "  ci vediamo sabato  "

        await vm.send()

        XCTAssertEqual(spia.inviati.map(\.text), ["ci vediamo sabato"], "spazi ai bordi tolti")
        XCTAssertTrue(spia.inCoda.isEmpty)
        XCTAssertEqual(vm.inputText, "", "il campo si svuota")
        XCTAssertEqual(spia.bozzaCancellata, 1, "la bozza salvata va cancellata")
    }

    func test_senzaLinea_ilMessaggioVaInCodaENonSiPerde() async throws {
        let spia = Spia()
        let vm = try modello(spia: spia, online: false)
        vm.inputText = "arrivo alle 18"

        await vm.send()

        XCTAssertTrue(spia.inviati.isEmpty)
        XCTAssertEqual(spia.inCoda.map(\.text), ["arrivo alle 18"])
        XCTAssertEqual(vm.inputText, "")
    }

    func test_invioFallito_finisceInCodaComeSeNonCiFosseLinea() async throws {
        let spia = Spia()
        let vm = try modello(spia: spia, invioFallisce: true)
        vm.inputText = "confermo il preventivo"

        await vm.send()

        XCTAssertTrue(spia.inviati.isEmpty)
        XCTAssertEqual(spia.inCoda.map(\.text), ["confermo il preventivo"],
                       "un errore a metà invio non deve far sparire il messaggio")
    }

    func test_soloSpazi_nonSiManda() async throws {
        let spia = Spia()
        let vm = try modello(spia: spia)
        vm.inputText = "   \n  "

        await vm.send()

        XCTAssertTrue(spia.inviati.isEmpty)
        XCTAssertTrue(spia.inCoda.isEmpty)
        XCTAssertFalse(vm.canSend)
    }

    func test_rispostaAUnMessaggio_portaIlRiferimentoEPoiSiChiude() async throws {
        let spia = Spia()
        let vm = try modello(spia: spia)
        let originale = try messaggio(senderId: organizerId)
        vm.startReply(to: originale)
        vm.inputText = "sì, va bene"

        await vm.send()

        XCTAssertEqual(spia.inviati.first?.replyId, originale.id)
        XCTAssertNil(vm.replyingTo, "dopo l'invio la risposta si chiude")
    }

    // MARK: - Modifica

    func test_modificaSoloSuiPropriMessaggi() async throws {
        let spia = Spia()
        let vm = try modello(spia: spia)
        let altrui = try messaggio(senderId: organizerId, content: "ciao")

        vm.startEditing(altrui)

        XCTAssertFalse(vm.isEditing, "non si modifica il messaggio di un altro")
        XCTAssertEqual(vm.inputText, "")
    }

    func test_modificaScaduta_nonSiEntra() async throws {
        let spia = Spia()
        let vm = try modello(spia: spia)
        let vecchio = try messaggio(
            senderId: clientId,
            createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-600))
        )

        vm.startEditing(vecchio)

        XCTAssertFalse(vm.isEditing, "oltre la finestra di modifica non si entra")
    }

    func test_modificaRiuscita_chiudeLaModifica() async throws {
        let spia = Spia()
        let vm = try modello(spia: spia)
        let mio = try messaggio(senderId: clientId, content: "ci vediamo")
        vm.startEditing(mio)
        XCTAssertTrue(vm.isEditing)
        XCTAssertEqual(vm.inputText, "ci vediamo", "il testo di partenza è quello del messaggio")

        vm.inputText = "ci vediamo alle 21"
        await vm.send()

        XCTAssertEqual(spia.modificati.map(\.text), ["ci vediamo alle 21"])
        XCTAssertTrue(spia.inviati.isEmpty, "in modifica non si manda un messaggio nuovo")
        XCTAssertFalse(vm.isEditing)
        XCTAssertEqual(vm.inputText, "")
    }

    func test_modificaFallita_restaInModificaColTesto() async throws {
        let spia = Spia()
        let vm = try modello(spia: spia, modificaFallisce: true)
        let mio = try messaggio(senderId: clientId, content: "ci vediamo")
        vm.startEditing(mio)
        vm.inputText = "ci vediamo alle 21"

        await vm.send()

        XCTAssertTrue(vm.isEditing, "se la modifica non passa il testo non va perso")
        XCTAssertEqual(vm.inputText, "ci vediamo alle 21")
    }

    func test_annullaModifica_svuotaIlCampo() async throws {
        let vm = try modello(spia: Spia())
        let mio = try messaggio(senderId: clientId, content: "bozza")
        vm.startEditing(mio)

        vm.cancelEditing()

        XCTAssertFalse(vm.isEditing)
        XCTAssertEqual(vm.inputText, "")
    }

    // MARK: - Messaggi in arrivo

    func test_messaggioRipetuto_nonSiDuplica() async throws {
        let vm = try modello(spia: Spia())
        let m = try messaggio(senderId: organizerId)

        vm.receive(m)
        vm.receive(m)

        XCTAssertEqual(vm.messages.count, 1)
    }

    func test_messaggioModificato_sostituisceQuelloInElenco() async throws {
        let vm = try modello(spia: Spia())
        let id = UUID()
        vm.receive(try messaggio(id: id, senderId: organizerId, content: "prima"))

        vm.apply(try messaggio(id: id, senderId: organizerId, content: "dopo"))

        XCTAssertEqual(vm.messages.count, 1)
        XCTAssertEqual(vm.messages.first?.content, "dopo")
    }

    func test_messaggioSconosciutoAggiornato_nonVieneAggiunto() async throws {
        let vm = try modello(spia: Spia())

        vm.apply(try messaggio(senderId: organizerId, content: "mai visto"))

        XCTAssertTrue(vm.messages.isEmpty)
    }

    // MARK: - Blocco ed eliminazione

    func test_bloccoRiuscito_eliminaLaConversazioneEChiude() async throws {
        let spia = Spia()
        let vm = try modello(spia: spia)

        let chiudi = await vm.blockUser()

        XCTAssertTrue(chiudi)
        XCTAssertEqual(spia.bloccati, [organizerId])
        XCTAssertEqual(spia.conversazioniEliminate, 1)
        XCTAssertTrue(vm.isBlocked)
    }

    func test_bloccoFallito_nonChiudeLaSchermata() async throws {
        let spia = Spia()
        let vm = try modello(spia: spia, bloccoFallisce: true)

        let chiudi = await vm.blockUser()

        XCTAssertFalse(chiudi)
        XCTAssertFalse(vm.isBlocked)
        XCTAssertEqual(spia.conversazioniEliminate, 0)
    }

    func test_eliminazioneFallita_nonChiudeLaSchermata() async throws {
        let spia = Spia()
        let vm = try modello(spia: spia, eliminazioneFallisce: true)

        let chiudi = await vm.deleteConversation()

        XCTAssertFalse(chiudi)
    }

    // MARK: - Bozza e risposte rapide

    func test_bozzaRipristinataSoloSeIlCampoEVuoto() async throws {
        let vm = try modello(spia: Spia(), bozzaSalvata: "mezza frase")

        await vm.restoreDraftIfNeeded()
        XCTAssertEqual(vm.inputText, "mezza frase")

        vm.inputText = "sto scrivendo"
        await vm.restoreDraftIfNeeded()
        XCTAssertEqual(vm.inputText, "sto scrivendo", "una bozza non sovrascrive quel che si sta scrivendo")
    }

    func test_rispostaRapida_siAccodaConUnoSpazio() async throws {
        let vm = try modello(spia: Spia())

        vm.appendQuickReply("Buongiorno!")
        XCTAssertEqual(vm.inputText, "Buongiorno!")

        vm.appendQuickReply("Le confermo.")
        XCTAssertEqual(vm.inputText, "Buongiorno! Le confermo.")
    }
}
