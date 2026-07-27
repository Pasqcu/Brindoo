//
//  ChatView.swift
//
//  Solo interfaccia: cosa si vede e cosa si tocca. Messaggi, invio, blocco
//  e trattativa collegata stanno in ChatViewModel.
//

import SwiftUI
import PhotosUI

struct ChatView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session

    let conversation: Conversation
    let otherUser: Profile

    @State private var vm: ChatViewModel

    // Stato puramente visivo: fogli, avvisi, anteprime.
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var pendingImage: PendingImage?
    @State private var fullScreenImage: (url: String, message: Message)?
    @State private var bombViewerMessage: Message?
    @State private var showBlockConfirm = false
    @State private var showDeleteConvConfirm = false
    @State private var navigateToProfile = false
    @State private var messageToDelete: Message?
    @State private var showReportUser = false
    @State private var messageToReport: Message?

    /// Coda dei messaggi in attesa di rete.
    @State private var outbox = OfflineOutboxService.shared

    init(conversation: Conversation, otherUser: Profile) {
        self.conversation = conversation
        self.otherUser = otherUser
        // L'utente corrente arriva dall'ambiente, che qui non è ancora
        // leggibile: viene passato al modello appena la vista compare.
        _vm = State(wrappedValue: ChatViewModel(
            conversation: conversation,
            otherUser: otherUser,
            currentUserId: nil
        ))
    }

    var body: some View {
        @Bindable var vm = vm

        VStack(spacing: 0) {
            if let proposal = vm.linkedProposal {
                ChatNegotiationBanner(proposal: proposal)
            }

            messagesScroll

            // Messaggi scritti senza linea: restano visibili qui finché
            // non partono da soli.
            let pendingCount = outbox.pendingMessages(for: conversation.id).count
            if pendingCount > 0 {
                ChatPendingBanner(count: pendingCount)
            }

            let failedCount = outbox.failedMessages(for: conversation.id).count
            if failedCount > 0 {
                ChatFailedBanner(
                    count: failedCount,
                    onRetry: { Task { await outbox.retryFailed(for: conversation.id) } },
                    onDiscard: { Task { await outbox.discardFailed(for: conversation.id) } }
                )
            }

            if vm.isBlocked {
                ChatBlockedBanner { Task { await vm.unblock() } }
            } else {
                // Una striscia sola per volta sopra la barra di scrittura:
                // stanno tutte fra i messaggi e la tastiera, e sommate
                // riducevano la conversazione a una fessura. Vince quella
                // che riguarda il gesto in corso.
                if vm.isEditing {
                    ChatEditBanner { vm.cancelEditing() }
                } else if let replyingTo = vm.replyingTo {
                    ChatReplyBanner(
                        message: replyingTo,
                        replyToName: replyingTo.senderId == session.userID ? "te stesso" : otherUser.displayName,
                        onClose: { vm.cancelReply() }
                    )
                } else if vm.otherIsTyping {
                    ChatTypingIndicator(
                        userName: otherUser.displayName,
                        isAnimating: vm.otherIsTyping
                    )
                }
                composer
            }
        }
        .background(Color.brindooBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                ChatHeaderView(user: otherUser) {
                    navigateToProfile = true
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                ChatOptionsMenu(
                    isBlocked: vm.isBlocked,
                    onViewProfile: { navigateToProfile = true },
                    onDeleteConversation: { showDeleteConvConfirm = true },
                    onBlock: { showBlockConfirm = true },
                    onUnblock: { Task { await vm.unblock() } },
                    onReport: { showReportUser = true }
                )
            }
        }
        .task {
            vm.updateCurrentUser(session.userID)
            await vm.load()
            vm.subscribeRealtime()
            await vm.subscribeTyping()
            await vm.markRead()
            vm.checkBlocked()
            await vm.loadLinkedProposal()
        }
        .onDisappear { vm.unsubscribe() }
        .onChange(of: photoPickerItem) { _, item in
            guard let item else { return }
            Task { await loadPickedImage(item) }
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
                    await vm.markBombViewed(message)
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
                    Task { await vm.sendImage(imageToSend, isBomb: asBomb) }
                }
            )
        }
        .alert("Errore invio foto", isPresented: Binding(
            get: { vm.sendErrorMessage != nil },
            set: { if !$0 { vm.sendErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { vm.sendErrorMessage = nil }
        } message: {
            Text(vm.sendErrorMessage ?? "")
        }
        .alert("Bloccare \(otherUser.displayName)?", isPresented: $showBlockConfirm) {
            Button("Annulla", role: .cancel) {}
            Button("Blocca", role: .destructive) {
                Task { if await vm.blockUser() { dismiss() } }
            }
        } message: {
            // Bloccare chi ha un evento in programma con te lascia un
            // impegno preso senza più un modo per parlarsi: va detto prima,
            // non scoperto la settimana della festa.
            if let pending = vm.pendingEventWarning {
                Text("Attenzione: \(pending)\n\nBloccando non riuscirete più a scrivervi, ma l'accordo resta. Se non vuoi più farlo, annullalo prima dall'agenda.")
            } else {
                Text("Non riceverete più messaggi e i vostri profili saranno nascosti reciprocamente.")
            }
        }
        .alert("Eliminare la conversazione?", isPresented: $showDeleteConvConfirm) {
            Button("Annulla", role: .cancel) {}
            Button("Elimina", role: .destructive) {
                Task { if await vm.deleteConversation() { dismiss() } }
            }
        } message: {
            Text("Solo per te. L'altro utente continuerà a vederla.")
        }
        .alert("Eliminare il messaggio?", isPresented: .constant(messageToDelete != nil)) {
            Button("Annulla", role: .cancel) { messageToDelete = nil }
            Button("Elimina", role: .destructive) {
                if let msg = messageToDelete {
                    Task { await vm.deleteMessage(msg) }
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

    // MARK: - Elenco messaggi

    private var messagesScroll: some View {
        ChatMessagesList(
            messages: vm.messages,
            currentUserId: session.userID,
            otherUser: otherUser,
            myReadReceiptsEnabled: session.currentProfile?.readReceiptsEnabled ?? true,
            onTapImage: { url, message in fullScreenImage = (url, message) },
            onTapBomb: { message in bombViewerMessage = message },
            onReply: { message in vm.startReply(to: message) },
            onEdit: { message in vm.startEditing(message) },
            onDelete: { message in messageToDelete = message },
            onReport: { message in messageToReport = message },
            onRefresh: { await vm.load() }
        )
    }

    // MARK: - Barra di scrittura

    private var composer: some View {
        @Bindable var vm = vm

        return ChatComposerView(
            inputText: $vm.inputText,
            photoPickerItem: $photoPickerItem,
            isSending: vm.isSending,
            isEditing: vm.isEditing,
            isAttachDisabled: vm.isSending || vm.isEditing,
            onSend: { Task { await vm.send() } },
            // Risposte rapide: solo per il professionista.
            onQuickReply: session.currentProfile?.role == .organizer
                ? { phrase in vm.appendQuickReply(phrase) }
                : nil
        )
        .onChange(of: vm.inputText) { _, newValue in
            Task {
                await vm.saveDraft(newValue)
                // "Sta scrivendo" solo se c'è davvero qualcosa di scritto.
                guard !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                await TypingService.shared.sendTyping(conversationId: conversation.id)
            }
        }
        .task {
            await vm.restoreDraftIfNeeded()
        }
    }

    // MARK: - Foto scelta dalla libreria

    private func loadPickedImage(_ item: PhotosPickerItem) async {
        defer { photoPickerItem = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else {
                vm.reportImageLoadFailure(nil)
                return
            }
            pendingImage = PendingImage(image: uiImage)
        } catch {
            vm.reportImageLoadFailure(error)
        }
    }
}
