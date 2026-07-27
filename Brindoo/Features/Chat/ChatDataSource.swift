//
//  ChatDataSource.swift
//  Brindoo
//
//  Le "prese" da cui la chat prende e manda i dati.
//
//  Perché: la schermata chiamava i servizi direttamente (istanze uniche
//  fisse), quindi nessuna delle sue regole — cosa succede se l'invio
//  fallisce, cosa finisce in coda, cosa si svuota — era verificabile senza
//  rete. Qui i servizi entrano dall'esterno: in app quelli veri, nei test
//  finti che rispondono a comando. Stesso schema di BoardDataSource.
//

import UIKit

struct ChatDataSource {

    // Messaggi
    var fetchMessages: (_ conversationId: UUID, _ visibleAfter: Date?) async throws -> [Message]
    var sendMessage: (_ conversationId: UUID, _ content: String, _ repliedToId: UUID?) async throws -> Void
    var editMessage: (_ messageId: UUID, _ newContent: String) async throws -> Void
    var deleteMessage: (_ messageId: UUID) async throws -> Void
    var sendImage: (_ conversationId: UUID, _ image: UIImage, _ isBomb: Bool) async throws -> Void
    var markBombViewed: (_ message: Message) async throws -> Void
    var markMessagesAsRead: (_ conversationId: UUID) async throws -> Void

    // Conversazione
    var setMarkedUnread: (_ conversation: Conversation, _ unread: Bool) async throws -> Void
    var softDeleteConversation: (_ conversation: Conversation) async throws -> Void

    // Blocco
    var isBlockingOrBlocked: (_ userId: UUID) -> Bool
    var block: (_ userId: UUID) async throws -> Void
    var unblock: (_ userId: UUID) async throws -> Void

    // Trattativa collegata
    var ongoingProposals: () async throws -> [OfferProposal]

    // Coda offline e stato della rete
    var enqueueMessage: (_ conversationId: UUID, _ text: String, _ repliedToId: UUID?) async -> Void
    var isOnline: () -> Bool

    // Bozza salvata
    var draft: (_ conversationId: UUID) async -> String
    var setDraft: (_ text: String, _ conversationId: UUID) async -> Void
    var clearDraft: (_ conversationId: UUID) async -> Void
}

extension ChatDataSource {

    /// Le prese vere, collegate ai servizi dell'app.
    @MainActor
    static var live: ChatDataSource {
        ChatDataSource(
            fetchMessages: { conversationId, visibleAfter in
                try await MessageService.shared.fetchMessages(
                    conversationId: conversationId,
                    visibleAfter: visibleAfter
                )
            },
            sendMessage: { conversationId, content, repliedToId in
                _ = try await MessageService.shared.sendMessage(
                    conversationId: conversationId,
                    content: content,
                    repliedToId: repliedToId
                )
            },
            editMessage: { messageId, newContent in
                try await MessageService.shared.editMessage(messageId: messageId, newContent: newContent)
            },
            deleteMessage: { messageId in
                try await MessageService.shared.deleteMessage(messageId: messageId)
            },
            sendImage: { conversationId, image, isBomb in
                _ = try await MessageService.shared.sendImage(
                    conversationId: conversationId,
                    image: image,
                    isBomb: isBomb
                )
            },
            markBombViewed: { message in
                try await MessageService.shared.markBombViewed(message: message)
            },
            markMessagesAsRead: { conversationId in
                try await MessageService.shared.markMessagesAsRead(conversationId: conversationId)
            },
            setMarkedUnread: { conversation, unread in
                try await ConversationService.shared.setMarkedUnread(conversation: conversation, unread: unread)
            },
            softDeleteConversation: { conversation in
                try await ConversationService.shared.softDelete(conversation: conversation)
            },
            isBlockingOrBlocked: { userId in
                BlockService.shared.isBlockingOrBlocked(userId)
            },
            block: { userId in
                try await BlockService.shared.block(userId: userId)
            },
            unblock: { userId in
                try await BlockService.shared.unblock(userId: userId)
            },
            ongoingProposals: {
                try await OfferProposalService.shared.fetchMyOngoingProposals()
            },
            enqueueMessage: { conversationId, text, repliedToId in
                await OfflineOutboxService.shared.enqueueMessage(
                    conversationId: conversationId,
                    text: text,
                    repliedToId: repliedToId
                )
            },
            isOnline: { NetworkMonitor.shared.isOnline },
            draft: { conversationId in
                await ChatDraftStore.shared.draft(for: conversationId)
            },
            setDraft: { text, conversationId in
                await ChatDraftStore.shared.setDraft(text, for: conversationId)
            },
            clearDraft: { conversationId in
                await ChatDraftStore.shared.clear(conversationId)
            }
        )
    }

    /// Prese mute: non chiedono nulla a nessuno. Base per i test.
    static var empty: ChatDataSource {
        ChatDataSource(
            fetchMessages: { _, _ in [] },
            sendMessage: { _, _, _ in },
            editMessage: { _, _ in },
            deleteMessage: { _ in },
            sendImage: { _, _, _ in },
            markBombViewed: { _ in },
            markMessagesAsRead: { _ in },
            setMarkedUnread: { _, _ in },
            softDeleteConversation: { _ in },
            isBlockingOrBlocked: { _ in false },
            block: { _ in },
            unblock: { _ in },
            ongoingProposals: { [] },
            enqueueMessage: { _, _, _ in },
            isOnline: { true },
            draft: { _ in "" },
            setDraft: { _, _ in },
            clearDraft: { _ in }
        )
    }
}
