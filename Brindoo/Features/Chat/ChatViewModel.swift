//
//  ChatViewModel.swift
//  Brindoo
//
//  Parte "dati e regole" della chat: messaggi, invio (anche senza linea),
//  modifica, blocco, trattativa collegata. ChatView resta solo interfaccia.
//
//  Perché: le regole stavano dentro la vista, mescolate a venti pezzi di
//  stato dell'interfaccia, e nessun test poteva raggiungerle. Qui entrano
//  dall'esterno tramite ChatDataSource, quindi si provano senza rete.
//

import Foundation
import Observation
import Realtime
import UIKit

@MainActor
@Observable
final class ChatViewModel {

    private let data: ChatDataSource
    private let conversation: Conversation
    private let otherUser: Profile
    /// Chi sta usando l'app: serve a capire quali messaggi sono suoi.
    private var currentUserId: UUID?

    // MARK: - Stato dei dati

    private(set) var messages: [Message] = []
    private(set) var isSending = false
    private(set) var isBlocked = false
    private(set) var otherIsTyping = false
    private(set) var linkedProposal: OfferProposal?
    var sendErrorMessage: String?

    // MARK: - Stato della scrittura

    /// Testo in scrittura. Lo tiene il modello perché è l'ingrediente
    /// dell'invio, non un dettaglio visivo.
    var inputText = ""
    private(set) var replyingTo: Message?
    private(set) var editingMessage: Message?

    // MARK: - Sottoscrizioni

    private var realtimeSubscription: RealtimeSubscription?
    private var typingHideTask: Task<Void, Never>?

    init(
        conversation: Conversation,
        otherUser: Profile,
        currentUserId: UUID?,
        data: ChatDataSource? = nil
    ) {
        self.conversation = conversation
        self.otherUser = otherUser
        self.currentUserId = currentUserId
        self.data = data ?? .live
    }

    /// La sessione arriva dall'ambiente e può cambiare dopo la creazione.
    func updateCurrentUser(_ userId: UUID?) {
        currentUserId = userId
    }

    // MARK: - Regole in chiaro

    /// Avviso da mostrare prima di bloccare, se c'è un impegno ancora aperto.
    var pendingEventWarning: String? { linkedProposal?.pendingAgreementWarning }

    /// Il testo scritto, ripulito. Vuoto = niente da mandare.
    var trimmedInput: String {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSend: Bool { !trimmedInput.isEmpty && !isSending }

    var isEditing: Bool { editingMessage != nil }

    // MARK: - Caricamento

    func load() async {
        do {
            guard let userId = currentUserId else { return }
            messages = try await data.fetchMessages(
                conversation.id,
                conversation.visibleAfterDate(for: userId)
            )
        } catch {
            BrindooLog.error("chat load: \(error)")
        }
    }

    func markRead() async {
        try? await data.markMessagesAsRead(conversation.id)
        // Aprire la chat azzera anche il contrassegno manuale "da leggere".
        try? await data.setMarkedUnread(conversation, false)
    }

    func checkBlocked() {
        isBlocked = data.isBlockingOrBlocked(otherUser.id)
    }

    func loadLinkedProposal() async {
        let all = (try? await data.ongoingProposals()) ?? []
        linkedProposal = all.first {
            $0.clientId == otherUser.id || $0.organizerId == otherUser.id
        }
    }

    func restoreDraftIfNeeded() async {
        guard inputText.isEmpty else { return }
        let draft = await data.draft(conversation.id)
        if !draft.isEmpty { inputText = draft }
    }

    func saveDraft(_ text: String) async {
        await data.setDraft(text, conversation.id)
    }

    // MARK: - Scrittura

    func startReply(to message: Message) {
        replyingTo = message
        editingMessage = nil
    }

    func cancelReply() {
        replyingTo = nil
    }

    /// Entra in modifica solo su un proprio messaggio ancora modificabile.
    func startEditing(_ message: Message) {
        guard message.senderId == currentUserId, message.isEditable else { return }
        editingMessage = message
        inputText = message.content
        replyingTo = nil
    }

    func cancelEditing() {
        editingMessage = nil
        inputText = ""
    }

    func appendQuickReply(_ phrase: String) {
        inputText = inputText.isEmpty ? phrase : inputText + " " + phrase
    }

    // MARK: - Invio

    func send() async {
        if isEditing {
            await commitEdit()
        } else {
            await sendText()
        }
    }

    private func sendText() async {
        let text = trimmedInput
        guard !text.isEmpty else { return }

        isSending = true
        defer { isSending = false }

        let replyId = replyingTo?.id

        // Senza linea, o se l'invio fallisce a metà, il messaggio non si
        // perde: va in coda e parte da solo appena torna il segnale.
        if data.isOnline() {
            do {
                try await data.sendMessage(conversation.id, text, replyId)
            } catch {
                BrindooLog.error("chat send: \(error)")
                await data.enqueueMessage(conversation.id, text, replyId)
            }
        } else {
            await data.enqueueMessage(conversation.id, text, replyId)
            BrindooHaptics.notify(.warning)
        }

        await clearComposer()
    }

    private func commitEdit() async {
        guard let editing = editingMessage else { return }
        let text = trimmedInput
        guard !text.isEmpty else { return }

        isSending = true
        defer { isSending = false }

        do {
            try await data.editMessage(editing.id, text)
            inputText = ""
            editingMessage = nil
            await data.clearDraft(conversation.id)
        } catch {
            BrindooLog.error("chat edit: \(error)")
        }
    }

    /// Svuota il campo, chiude la risposta e cancella la bozza salvata.
    private func clearComposer() async {
        inputText = ""
        replyingTo = nil
        await data.clearDraft(conversation.id)
    }

    // MARK: - Foto

    func sendImage(_ image: UIImage, isBomb: Bool) async {
        isSending = true
        defer { isSending = false }
        do {
            try await data.sendImage(conversation.id, image, isBomb)
        } catch {
            BrindooLog.error("chat sendImage: \(error)")
            sendErrorMessage = BrindooErrorText.message(
                for: error,
                fallback: "Invio della foto non riuscito. \(BrindooText.retryHint)"
            )
        }
    }

    /// Invia un vocale registrato. Il file temporaneo lo pulisce il servizio.
    func sendVoice(url: URL, duration: TimeInterval) async {
        isSending = true
        defer { isSending = false }
        do {
            try await data.sendVoice(conversation.id, url, duration)
        } catch {
            BrindooLog.error("chat sendVoice: \(error)")
            sendErrorMessage = BrindooErrorText.message(
                for: error,
                fallback: "Invio del vocale non riuscito. \(BrindooText.retryHint)"
            )
        }
    }

    func reportImageLoadFailure(_ error: Error?) {
        if let error {
            BrindooLog.error("chat loadPickedImage: \(error)")
            sendErrorMessage = BrindooErrorText.message(
                for: error,
                fallback: BrindooText.loadError("la foto selezionata. Riprova.")
            )
        } else {
            sendErrorMessage = BrindooText.loadError("la foto selezionata. Riprova.")
        }
    }

    func markBombViewed(_ message: Message) async {
        try? await data.markBombViewed(message)
    }

    // MARK: - Gestione della conversazione

    func deleteMessage(_ message: Message) async {
        do {
            try await data.deleteMessage(message.id)
        } catch {
            BrindooLog.error("chat deleteMessage: \(error)")
        }
    }

    /// True se la conversazione è stata davvero eliminata (la vista può chiudersi).
    func deleteConversation() async -> Bool {
        do {
            try await data.softDeleteConversation(conversation)
            return true
        } catch {
            BrindooLog.error("chat deleteConversation: \(error)")
            return false
        }
    }

    /// True se il blocco è andato a buon fine (la vista può chiudersi).
    func blockUser() async -> Bool {
        do {
            try await data.block(otherUser.id)
            try await data.softDeleteConversation(conversation)
            isBlocked = true
            return true
        } catch {
            BrindooLog.error("chat blockUser: \(error)")
            return false
        }
    }

    func unblock() async {
        do {
            try await data.unblock(otherUser.id)
            isBlocked = false
        } catch {
            BrindooLog.error("chat unblock: \(error)")
        }
    }

    // MARK: - Tempo reale

    func subscribeRealtime() {
        realtimeSubscription = MessageService.shared.subscribeToMessages(
            conversationId: conversation.id,
            onInsert: { [weak self] newMessage in
                Task { @MainActor in self?.receive(newMessage) }
            },
            onUpdate: { [weak self] updated in
                Task { @MainActor in self?.apply(updated) }
            }
        )
    }

    func subscribeTyping() async {
        guard let userId = currentUserId else { return }
        _ = await TypingService.shared.subscribe(
            conversationId: conversation.id,
            currentUserId: userId
        ) { [weak self] in
            Task { @MainActor in self?.otherStartedTyping() }
        }
    }

    func unsubscribe() {
        let subscription = realtimeSubscription
        let conversationId = conversation.id
        realtimeSubscription = nil
        typingHideTask?.cancel()
        typingHideTask = nil
        Task {
            await subscription?.cancel()
            await TypingService.shared.unsubscribe(conversationId: conversationId)
        }
    }

    /// Messaggio arrivato dal tempo reale.
    func receive(_ message: Message) {
        guard !messages.contains(where: { $0.id == message.id }) else { return }
        messages.append(message)
        guard message.senderId != currentUserId else { return }
        // Se scrive, ha finito di scrivere: l'indicatore va spento.
        otherIsTyping = false
        typingHideTask?.cancel()
        typingHideTask = nil
        Task { await markRead() }
    }

    /// Messaggio modificato o cancellato dall'altra parte.
    func apply(_ updated: Message) {
        guard let idx = messages.firstIndex(where: { $0.id == updated.id }) else { return }
        messages[idx] = updated
    }

    private func otherStartedTyping() {
        otherIsTyping = true
        typingHideTask?.cancel()
        typingHideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.otherIsTyping = false
        }
    }
}
