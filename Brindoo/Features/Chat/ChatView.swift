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
                negotiationBanner(proposal)
            }

            messagesScroll
            
            if isBlocked {
                blockedBanner
            } else {
                if otherIsTyping {
                    typingIndicator
                }
                if let editingMessage {
                    editBanner(editingMessage)
                }
                if let replyingTo {
                    replyBanner(replyingTo)
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
    
    // MARK: - Banners
    
    @ViewBuilder
    private var blockedBanner: some View {
        VStack(spacing: BrindooSpacing.xs) {
            HStack(spacing: BrindooSpacing.xs) {
                Image(systemName: "hand.raised.slash.fill")
                Text("Utente bloccato")
                    .font(BrindooFont.bodyMedium.weight(.medium))
            }
            .foregroundStyle(Color.brindooError)
            
            Button {
                Task { await unblock() }
            } label: {
                Text("Sblocca")
                    .font(BrindooFont.bodySmall.weight(.semibold))
                    .foregroundStyle(Color.brindooCoral)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(BrindooSpacing.md)
        .background(Color.brindooError.opacity(0.08))
    }
    
    @ViewBuilder
    private func replyBanner(_ message: Message) -> some View {
        HStack(spacing: BrindooSpacing.sm) {
            Rectangle().fill(Color.brindooCoral).frame(width: 3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Rispondi a \(message.senderId == session.userID ? "te stesso" : otherUser.fullName ?? "utente")")
                    .font(BrindooFont.caption.weight(.semibold))
                    .foregroundStyle(Color.brindooCoral)
                Text(message.messageType == .image ? "📷 Foto" : message.content)
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooTextSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Button { replyingTo = nil } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.brindooTextSecondary)
            }
        }
        .padding(.horizontal, BrindooSpacing.md)
        .padding(.vertical, BrindooSpacing.xs)
        .background(Color.brindooSurface)
    }
    
    @ViewBuilder
    private func editBanner(_ message: Message) -> some View {
        HStack(spacing: BrindooSpacing.sm) {
            Image(systemName: "pencil")
                .foregroundStyle(Color.brindooCoral)
            Text("Modifica messaggio")
                .font(BrindooFont.caption.weight(.semibold))
                .foregroundStyle(Color.brindooCoral)
            Spacer()
            Button {
                editingMessage = nil
                inputText = ""
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.brindooTextSecondary)
            }
        }
        .padding(.horizontal, BrindooSpacing.md)
        .padding(.vertical, BrindooSpacing.xs)
        .background(Color.brindooSurface)
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
            }
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
            print("❌ \(error)")
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

    @ViewBuilder
    private var typingIndicator: some View {
        HStack(spacing: BrindooSpacing.xs) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.brindooTextSecondary)
                    .frame(width: 6, height: 6)
                    .opacity(0.6)
                    .scaleEffect(otherIsTyping ? 1.0 : 0.4)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.18),
                        value: otherIsTyping
                    )
            }
            Text("\(otherUser.fullName ?? "Utente") sta scrivendo…")
                .font(BrindooFont.caption)
                .foregroundStyle(Color.brindooTextSecondary)
            Spacer()
        }
        .padding(.horizontal, BrindooSpacing.md)
        .padding(.vertical, BrindooSpacing.xs)
        .transition(.opacity)
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

    @ViewBuilder
    private func negotiationBanner(_ proposal: OfferProposal) -> some View {
        Button {
            DeepLinkRouter.shared.selectedTab = 1 // Trattative
        } label: {
            HStack(spacing: BrindooSpacing.xs) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                VStack(alignment: .leading, spacing: 0) {
                    Text(proposal.status == .accepted ? "Trattativa conclusa" : "Trattativa in corso")
                        .font(BrindooFont.caption.weight(.semibold))
                    Text(proposal.currentPriceDisplay)
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextSecondary)
                }
                Spacer()
                Text("Apri")
                    .font(BrindooFont.caption.weight(.semibold))
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(Color.brindooCoral)
            .padding(.horizontal, BrindooSpacing.md)
            .padding(.vertical, BrindooSpacing.xs)
            .background(Color.brindooCoral.opacity(0.08))
        }
        .buttonStyle(.plain)
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
            print("❌ \(error)")
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
            print("❌ \(error)")
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
            print("❌ loadPickedImage: \(error)")
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
            print("❌ sendImage: \(error)")
            sendErrorMessage = "Invio foto fallito: \(error.localizedDescription)"
        }
    }
    
    private func deleteMessage(_ message: Message) async {
        do {
            try await MessageService.shared.deleteMessage(messageId: message.id)
        } catch {
            print("❌ \(error)")
        }
    }
    
    private func deleteConversation() async {
        do {
            try await ConversationService.shared.softDelete(conversation: conversation)
            dismiss()
        } catch {
            print("❌ \(error)")
        }
    }
    
    private func blockUser() async {
        do {
            try await BlockService.shared.block(userId: otherUser.id)
            try await ConversationService.shared.softDelete(conversation: conversation)
            dismiss()
        } catch {
            print("❌ \(error)")
        }
    }
    
    private func unblock() async {
        do {
            try await BlockService.shared.unblock(userId: otherUser.id)
            isBlocked = false
        } catch {
            print("❌ \(error)")
        }
    }
}

// MARK: - Pending image wrapper

struct PendingImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

// MARK: - Full screen image

struct FullScreenWrapper: Identifiable {
    let id = UUID()
    let url: String
    let message: Message
}

struct FullScreenImageView: View {
    let url: String
    let onClose: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            
            AsyncImage(url: URL(string: url)) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                ProgressView().tint(.white)
            }
            
            Button { onClose() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
            }
            .padding()
        }
    }
}

// MARK: - Photo preview before send (stile WhatsApp)

struct PhotoPreviewSendView: View {
    let image: UIImage
    let onCancel: () -> Void
    let onSend: (_ asBomb: Bool) -> Void

    @State private var asBomb: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Top bar (rimane sotto la status bar grazie al safe area)
            HStack {
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Anteprima foto")
                    .font(BrindooFont.bodyMedium.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()

                // Spazio per bilanciare il bottone X
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, BrindooSpacing.md)
            .padding(.top, BrindooSpacing.sm)
            .padding(.bottom, BrindooSpacing.xs)

            // Image
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, BrindooSpacing.md)

            // Bottom bar
            HStack(spacing: BrindooSpacing.md) {
                // Toggle bomba
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        asBomb.toggle()
                    }
                } label: {
                    HStack(spacing: BrindooSpacing.xs) {
                        Image(systemName: asBomb ? "flame.fill" : "flame")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Bomba")
                            .font(BrindooFont.bodyMedium.weight(.semibold))
                    }
                    .foregroundStyle(asBomb ? .white : .white.opacity(0.85))
                    .padding(.horizontal, BrindooSpacing.md)
                    .padding(.vertical, BrindooSpacing.sm)
                    .background(asBomb ? Color.orange : Color.white.opacity(0.15))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer()

                // Send
                Button {
                    onSend(asBomb)
                } label: {
                    HStack(spacing: BrindooSpacing.xs) {
                        Text("Invia")
                            .font(BrindooFont.bodyMedium.weight(.bold))
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, BrindooSpacing.lg)
                    .padding(.vertical, BrindooSpacing.sm)
                    .background(Color.brindooCoral)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, BrindooSpacing.md)
            .padding(.bottom, BrindooSpacing.md)

            if asBomb {
                HStack(spacing: BrindooSpacing.xs) {
                    Image(systemName: "info.circle.fill")
                    Text("La foto sparirà dopo che il destinatario la apre")
                        .font(BrindooFont.caption)
                }
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, BrindooSpacing.md)
                .padding(.bottom, BrindooSpacing.md)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}

// MARK: - Bomb image viewer (foto che sparisce dopo close)

struct BombImageViewer: View {
    let message: Message
    let onClose: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: BrindooSpacing.lg) {
                HStack {
                    HStack(spacing: BrindooSpacing.xs) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        Text("Foto bomba")
                            .font(BrindooFont.bodyMedium.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Button { onClose() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                    }
                }
                .padding()
                
                if let urlString = message.imageUrl,
                   let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        ProgressView().tint(.white)
                    }
                } else {
                    Text("Foto non più disponibile")
                        .foregroundStyle(.white)
                }
                
                Text("Questa foto sparirà alla chiusura")
                    .font(BrindooFont.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.bottom)
            }
        }
    }
}
