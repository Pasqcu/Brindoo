//
//  ChatView.swift
//

import SwiftUI
import PhotosUI
import Realtime

struct ChatView: View {
    
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    
    let conversation: Conversation
    let otherUser: Profile
    
    @State private var messages: [Message] = []
    @State private var inputText: String = ""
    @State private var isSending: Bool = false
    @State private var isLoading: Bool = true
    @State private var realtimeChannel: RealtimeChannelV2?
    
    @State private var replyingTo: Message?
    @State private var editingMessage: Message?
    
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var pendingImage: PendingImage?

    @State private var fullScreenImage: (url: String, message: Message)?
    @State private var bombViewerMessage: Message?

    @State private var sendErrorMessage: String?

    @State private var showOptionsMenu: Bool = false
    @State private var showBlockConfirm: Bool = false
    @State private var showDeleteConvConfirm: Bool = false
    @State private var isBlocked: Bool = false
    @State private var navigateToProfile: Bool = false

    @State private var messageToDelete: Message?

    // Segnalazioni
    @State private var showReportUser: Bool = false
    @State private var messageToReport: Message?

    // Typing indicator
    @State private var otherIsTyping: Bool = false
    @State private var typingHideTask: Task<Void, Never>?

    // Trattativa attiva con questo utente (collegamento Chat ↔ Trattative)
    @State private var linkedProposal: OfferProposal?

    var body: some View {
        VStack(spacing: 0) {
            if let proposal = linkedProposal {
                ChatNegotiationBanner(proposal: proposal)
            }

            messagesScroll

            if isBlocked {
                ChatBlockedBanner { Task { await unblock() } }
            } else {
                if otherIsTyping {
                    ChatTypingIndicator(
                        userName: otherUser.fullName ?? "Utente",
                        isAnimating: otherIsTyping
                    )
                }
                if editingMessage != nil {
                    ChatEditBanner {
                        editingMessage = nil
                        inputText = ""
                    }
                }
                if let replyingTo {
                    ChatReplyBanner(
                        message: replyingTo,
                        replyToName: replyingTo.senderId == session.userID ? "te stesso" : otherUser.fullName ?? "utente",
                        onClose: { self.replyingTo = nil }
                    )
                }
                composer
            }
        }
        .background(Color.brindooBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button {
                    navigateToProfile = true
                } label: {
                    HStack(spacing: BrindooSpacing.xs) {
                        AvatarView(url: otherUser.avatarUrl, name: otherUser.fullName, size: 32)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(otherUser.fullName ?? "Utente")
                                .font(BrindooFont.bodyMedium.weight(.semibold))
                                .foregroundStyle(Color.brindooTextPrimary)
                            if otherUser.isPro {
                                Text("Pro")
                                    .font(BrindooFont.caption)
                                    .foregroundStyle(Color.brindooCoral)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        navigateToProfile = true
                    } label: {
                        Label("Visualizza profilo", systemImage: "person.circle")
                    }

                    Button(role: .destructive) {
                        showDeleteConvConfirm = true
                    } label: {
                        Label("Elimina conversazione", systemImage: "trash")
                    }

                    if !isBlocked {
                        Button(role: .destructive) {
                            showBlockConfirm = true
                        } label: {
                            Label("Blocca utente", systemImage: "hand.raised.slash")
                        }
                    } else {
                        Button {
                            Task { await unblock() }
                        } label: {
                            Label("Sblocca utente", systemImage: "hand.raised")
                        }
                    }

                    Divider()

                    Button(role: .destructive) {
                        showReportUser = true
                    } label: {
                        Label("Segnala utente", systemImage: "exclamationmark.bubble")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(Color.brindooTextPrimary)
                }
                .accessibilityLabel("Opzioni conversazione")
            }
        }
        .task {
            await loadMessages()
            subscribeRealtime()
            await subscribeTyping()
            await markRead()
            checkBlocked()
            await loadLinkedProposal()
        }
        .onDisappear {
            Task {
                if let ch = realtimeChannel { await ch.unsubscribe() }
                await TypingService.shared.unsubscribe(conversationId: conversation.id)
            }
            typingHideTask?.cancel()
        }
        .onChange(of: photoPickerItem) { _, item in
            guard let item else { return }
            Task { await loadPickedImage(item) }
        }
        .onChange(of: inputText) { _, newValue in
            guard !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            Task { await TypingService.shared.sendTyping(conversationId: conversation.id) }
        }
        .fullScreenCover(item: Binding(
            get: { fullScreenImage.map { FullScreenWrapper(url: $0.url, message: $0.message) } },
            set: { _ in fullScreenImage = nil }
        )) { wrapper in
            FullScreenImageView(url: wrapper.url) {
                fullScreenImage = nil
            }
        }
        .fullScreenCover(item: $bombViewerMessage) { message in
            BombImageViewer(message: message) {
                Task {
                    try? await MessageService.shared.markBombViewed(message: message)
                    bombViewerMessage = nil
                }
            }
        }
        .fullScreenCover(item: $pendingImage) { pending in
            PhotoPreviewSendView(
                image: pending.image,
                onCancel: {
                    pendingImage = nil
                },
                onSend: { asBomb in
                    let imageToSend = pending.image
                    pendingImage = nil
                    Task { await sendImage(imageToSend, isBomb: asBomb) }
                }
            )
        }
        .alert("Errore invio foto", isPresented: Binding(
            get: { sendErrorMessage != nil },
            set: { if !$0 { sendErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { sendErrorMessage = nil }
        } message: {
            Text(sendErrorMessage ?? "")
        }
        .alert("Bloccare \(otherUser.fullName ?? "utente")?", isPresented: $showBlockConfirm) {
            Button("Annulla", role: .cancel) {}
            Button("Blocca", role: .destructive) {
                Task { await blockUser() }
            }
        } message: {
            Text("Non riceverete più messaggi e i vostri profili saranno nascosti reciprocamente.")
        }
        .alert("Eliminare la conversazione?", isPresented: $showDeleteConvConfirm) {
            Button("Annulla", role: .cancel) {}
            Button("Elimina", role: .destructive) {
                Task { await deleteConversation() }
            }
        } message: {
            Text("Solo per te. L'altro utente continuerà a vederla.")
        }
        .alert("Eliminare il messaggio?", isPresented: .constant(messageToDelete != nil)) {
            Button("Annulla", role: .cancel) { messageToDelete = nil }
            Button("Elimina", role: .destructive) {
                if let msg = messageToDelete {
                    Task { await deleteMessage(msg) }
                }
                messageToDelete = nil
            }
        }
        .navigationDestination(isPresented: $navigateToProfile) {
            OrganizerDetailView(organizer: otherUser)
        }
        .sheet(isPresented: $showReportUser) {
            ReportSheet(
                targetType: .user,
                targetId: otherUser.id,
                targetLabel: otherUser.fullName ?? "questo utente"
            )
        }
        .sheet(item: $messageToReport) { message in
            ReportSheet(
                targetType: .message,
                targetId: message.id,
                targetLabel: "questo messaggio"
            )
        }
    }
    
    // MARK: - Messages scroll
    
    @ViewBuilder
    private var messagesScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: BrindooSpacing.xs) {
                    ForEach(messages) { message in
                        let isOwn = message.senderId == session.userID
                        if message.messageType == .system {
                            ChatSystemNote(text: message.content)
                                .id(message.id)
                        } else {
                        MessageBubble(
                            message: message,
                            isOwn: isOwn,
                            repliedTo: repliedToMessage(for: message),
                            otherUserReadReceiptsEnabled: otherUser.readReceiptsEnabled,
                            myReadReceiptsEnabled: session.currentProfile?.readReceiptsEnabled ?? true,
                            onTapImage: { url in
                                fullScreenImage = (url, message)
                            },
                            onTapBomb: {
                                bombViewerMessage = message
                            },
                            onReply: {
                                replyingTo = message
                                editingMessage = nil
                            },
                            onEdit: {
                                guard isOwn, message.isEditable else { return }
                                editingMessage = message
                                inputText = message.content
                                replyingTo = nil
                            },
                            onDelete: {
                                messageToDelete = message
                            },
                            onReport: {
                                messageToReport = message
                            }
                        )
                        .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, BrindooSpacing.sm)
                .padding(.vertical, BrindooSpacing.sm)
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .onAppear {
                if let last = messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
            .refreshable { await loadMessages() }
        }
    }
    
    private func repliedToMessage(for message: Message) -> Message? {
        guard let id = message.repliedToId else { return nil }
        return messages.first { $0.id == id }
    }

    // MARK: - Composer
    
    @ViewBuilder
    private var composer: some View {
        ChatComposerView(
            inputText: $inputText,
            photoPickerItem: $photoPickerItem,
            isSending: isSending,
            isEditing: editingMessage != nil,
            isAttachDisabled: isSending || editingMessage != nil,
            onSend: {
                if editingMessage != nil {
                    Task { await commitEdit() }
                } else {
                    Task { await sendText() }
                }
            },
            // Risposte rapide: solo per il professionista.
            onQuickReply: session.currentProfile?.role == .organizer
                ? { phrase in
                    inputText = inputText.isEmpty ? phrase : inputText + " " + phrase
                }
                : nil
        )
        .onChange(of: inputText) { _, newValue in
            Task { await ChatDraftStore.shared.setDraft(newValue, for: conversation.id) }
        }
        .task {
            // Ripristina la bozza in cache (solo al primo ingresso, se input è vuoto)
            if inputText.isEmpty {
                let draft = await ChatDraftStore.shared.draft(for: conversation.id)
                if !draft.isEmpty { inputText = draft }
            }
        }
    }
    
    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Actions
    
    private func loadMessages() async {
        isLoading = true
        defer { isLoading = false }
        do {
            guard let userId = session.userID else { return }
            let visibleAfter = conversation.visibleAfterDate(for: userId)
            messages = try await MessageService.shared.fetchMessages(
                conversationId: conversation.id,
                visibleAfter: visibleAfter
            )
        } catch {
            BrindooLog.error("\(error)")
        }
    }
    
    private func subscribeRealtime() {
        realtimeChannel = MessageService.shared.subscribeToMessages(
            conversationId: conversation.id,
            onInsert: { newMessage in
                Task { @MainActor in
                    if !messages.contains(where: { $0.id == newMessage.id }) {
                        messages.append(newMessage)
                        if newMessage.senderId != session.userID {
                            await markRead()
                            // Nuovo messaggio in arrivo dall'altra parte → l'indicatore va spento.
                            otherIsTyping = false
                            typingHideTask?.cancel()
                        }
                    }
                }
            },
            onUpdate: { updated in
                Task { @MainActor in
                    if let idx = messages.firstIndex(where: { $0.id == updated.id }) {
                        messages[idx] = updated
                    }
                }
            }
        )
    }

    private func subscribeTyping() async {
        guard let userId = session.userID else { return }
        _ = await TypingService.shared.subscribe(
            conversationId: conversation.id,
            currentUserId: userId
        ) {
            Task { @MainActor in
                otherIsTyping = true
                typingHideTask?.cancel()
                typingHideTask = Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    if !Task.isCancelled {
                        otherIsTyping = false
                    }
                }
            }
        }
    }

    private func markRead() async {
        try? await MessageService.shared.markMessagesAsRead(conversationId: conversation.id)
        // Quando l'utente apre la chat azzera anche il flag manuale "da leggere"
        try? await ConversationService.shared.setMarkedUnread(conversation: conversation, unread: false)
    }
    
    private func checkBlocked() {
        isBlocked = BlockService.shared.isBlockingOrBlocked(otherUser.id)
    }

    // MARK: - Collegamento alla trattativa

    private func loadLinkedProposal() async {
        let all = (try? await OfferProposalService.shared.fetchMyOngoingProposals()) ?? []
        linkedProposal = all.first {
            $0.clientId == otherUser.id || $0.organizerId == otherUser.id
        }
    }

    private func sendText() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        isSending = true
        defer { isSending = false }
        
        do {
            _ = try await MessageService.shared.sendMessage(
                conversationId: conversation.id,
                content: text,
                repliedToId: replyingTo?.id
            )
            inputText = ""
            replyingTo = nil
            await ChatDraftStore.shared.clear(conversation.id)
        } catch {
            BrindooLog.error("\(error)")
        }
    }
    
    private func commitEdit() async {
        guard let editing = editingMessage else { return }
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        isSending = true
        defer { isSending = false }
        
        do {
            try await MessageService.shared.editMessage(messageId: editing.id, newContent: text)
            inputText = ""
            editingMessage = nil
            await ChatDraftStore.shared.clear(conversation.id)
        } catch {
            BrindooLog.error("\(error)")
        }
    }
    
    private func loadPickedImage(_ item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                await MainActor.run {
                    pendingImage = PendingImage(image: uiImage)
                    photoPickerItem = nil
                }
            } else {
                await MainActor.run {
                    photoPickerItem = nil
                    sendErrorMessage = "Impossibile caricare la foto selezionata. Riprova."
                }
            }
        } catch {
            BrindooLog.error("loadPickedImage: \(error)")
            await MainActor.run {
                photoPickerItem = nil
                sendErrorMessage = "Errore nel caricamento della foto: \(error.localizedDescription)"
            }
        }
    }

    private func sendImage(_ image: UIImage, isBomb: Bool) async {
        isSending = true
        defer { isSending = false }

        do {
            _ = try await MessageService.shared.sendImage(
                conversationId: conversation.id,
                image: image,
                isBomb: isBomb
            )
        } catch {
            BrindooLog.error("sendImage: \(error)")
            sendErrorMessage = "Invio foto fallito: \(error.localizedDescription)"
        }
    }
    
    private func deleteMessage(_ message: Message) async {
        do {
            try await MessageService.shared.deleteMessage(messageId: message.id)
        } catch {
            BrindooLog.error("\(error)")
        }
    }
    
    private func deleteConversation() async {
        do {
            try await ConversationService.shared.softDelete(conversation: conversation)
            dismiss()
        } catch {
            BrindooLog.error("\(error)")
        }
    }
    
    private func blockUser() async {
        do {
            try await BlockService.shared.block(userId: otherUser.id)
            try await ConversationService.shared.softDelete(conversation: conversation)
            dismiss()
        } catch {
            BrindooLog.error("\(error)")
        }
    }
    
    private func unblock() async {
        do {
            try await BlockService.shared.unblock(userId: otherUser.id)
            isBlocked = false
        } catch {
            BrindooLog.error("\(error)")
        }
    }
}
