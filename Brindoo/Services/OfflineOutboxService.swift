//
//  OfflineOutboxService.swift
//  Brindoo
//
//  Coda delle cose scritte senza linea.
//
//  Prima: messaggio inviato in metropolitana = errore e testo perso.
//  Ora il messaggio si mette in coda sul telefono, resta visibile con
//  l'etichetta "in attesa di rete" e parte da solo appena torna il segnale.
//
//  In coda finiscono solo azioni ripetibili senza danno (per ora i messaggi
//  di testo): niente pagamenti, niente accettazioni di trattativa, che
//  devono restare gesti consapevoli fatti con la linea attiva.
//

import Foundation
import Observation

/// Azione in attesa di essere inviata.
struct PendingAction: Codable, Identifiable, Equatable {

    enum Kind: String, Codable {
        case sendMessage
    }

    let id: UUID
    let kind: Kind
    let createdAt: Date
    /// Conversazione a cui appartiene il messaggio.
    let conversationId: UUID
    let text: String
    let repliedToId: UUID?
    var attempts: Int

    init(
        id: UUID = UUID(),
        kind: Kind = .sendMessage,
        createdAt: Date = Date(),
        conversationId: UUID,
        text: String,
        repliedToId: UUID? = nil,
        attempts: Int = 0
    ) {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
        self.conversationId = conversationId
        self.text = text
        self.repliedToId = repliedToId
        self.attempts = attempts
    }
}

@MainActor
@Observable
final class OfflineOutboxService {

    static let shared = OfflineOutboxService()
    private init() {}

    private(set) var pending: [PendingAction] = []
    private var loaded = false
    private var flushing = false

    /// Dopo troppi tentativi falliti l'azione viene lasciata cadere: meglio
    /// che riprovare all'infinito un messaggio che il server rifiuta.
    private let maxAttempts = 5

    // MARK: - Lettura e scrittura

    func loadIfNeeded() async {
        guard !loaded else { return }
        pending = await LocalCacheStore.shared.load([PendingAction].self, for: BrindooCacheKey.outbox) ?? []
        loaded = true
    }

    private func persist() async {
        await LocalCacheStore.shared.save(pending, for: BrindooCacheKey.outbox)
    }

    /// Messaggi ancora da inviare per una conversazione (per mostrarli in chat).
    func pendingMessages(for conversationId: UUID) -> [PendingAction] {
        pending.filter { $0.conversationId == conversationId && $0.kind == .sendMessage }
    }

    // MARK: - Accodamento

    func enqueueMessage(conversationId: UUID, text: String, repliedToId: UUID?) async {
        await loadIfNeeded()
        pending.append(PendingAction(
            conversationId: conversationId,
            text: text,
            repliedToId: repliedToId
        ))
        await persist()
    }

    func remove(id: UUID) async {
        await loadIfNeeded()
        pending.removeAll { $0.id == id }
        await persist()
    }

    // MARK: - Svuotamento

    /// Riprova a inviare tutto quello che è in coda. Sicuro da chiamare
    /// spesso: se è già in corso o non c'è linea, non fa nulla.
    @discardableResult
    func flush() async -> Int {
        await loadIfNeeded()
        guard !flushing, !pending.isEmpty, NetworkMonitor.shared.isOnline else { return 0 }
        flushing = true
        defer { flushing = false }

        var sent = 0
        // Ordine di arrivo: i messaggi devono restare nella sequenza giusta.
        for action in pending.sorted(by: { $0.createdAt < $1.createdAt }) {
            do {
                switch action.kind {
                case .sendMessage:
                    _ = try await MessageService.shared.sendMessage(
                        conversationId: action.conversationId,
                        content: action.text,
                        repliedToId: action.repliedToId
                    )
                }
                pending.removeAll { $0.id == action.id }
                sent += 1
            } catch {
                BrindooLog.error("Coda offline, invio fallito: \(error)")
                if let index = pending.firstIndex(where: { $0.id == action.id }) {
                    pending[index].attempts += 1
                    if pending[index].attempts >= maxAttempts {
                        pending.remove(at: index)
                    }
                }
                // Se il primo fallisce probabilmente manca ancora la linea:
                // ci si ferma e si riprova al prossimo giro.
                break
            }
        }
        await persist()
        return sent
    }
}
