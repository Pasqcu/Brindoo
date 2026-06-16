//
//  ChatListView.swift
//
//  Lista chat. Usa `List` per supportare le swipe-action:
//   - Swipe ← (trailing): Elimina conversazione
//   - Swipe → (leading) : Fissa in alto / Sblocca + Segna come da leggere / letta
//

import SwiftUI

struct ChatListView: View {

    @Environment(SessionStore.self) private var session

    @State private var conversations: [Conversation] = []
    @State private var otherProfiles: [UUID: Profile] = [:]
    @State private var unreadCounts: [UUID: Int] = [:]
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?

    @State private var conversationToDelete: Conversation?
    @State private var conversationToBlock: (conversation: Conversation, otherUserId: UUID)?
    @State private var profileToView: Profile?
    @State private var navigateToProfile: Profile?

    private var currentUserId: UUID? { session.userID }

    var body: some View {
        NavigationStack {
            content
                .background(Color.brindooBackground)
                .navigationTitle("Chat")
                .navigationBarTitleDisplayMode(.large)
                .task {
                    await loadInitial()
                    await ConversationService.shared.startListening {
                        Task { await self.refresh() }
                    }
                }
                .onDisappear {
                    Task { await ConversationService.shared.stopListening() }
                }
                .refreshable { await refresh() }
                .navigationDestination(item: $navigateToProfile) { profile in
                    OrganizerDetailView(organizer: profile)
                }
                .alert("Eliminare la conversazione?", isPresented: .constant(conversationToDelete != nil)) {
                    Button("Annulla", role: .cancel) { conversationToDelete = nil }
                    Button("Elimina", role: .destructive) {
                        if let conv = conversationToDelete {
                            Task { await deleteConversation(conv) }
                        }
                        conversationToDelete = nil
                    }
                } message: {
                    Text("La conversazione verrà rimossa solo per te. L'altro utente continuerà a vederla.")
                }
                .alert("Bloccare il profilo?", isPresented: .constant(conversationToBlock != nil)) {
                    Button("Annulla", role: .cancel) { conversationToBlock = nil }
                    Button("Blocca", role: .destructive) {
                        if let item = conversationToBlock {
                            Task { await blockUser(item.otherUserId) }
                        }
                        conversationToBlock = nil
                    }
                } message: {
                    Text("Non riceverai più messaggi né vedrai questo profilo nelle ricerche.")
                }
                .coachMark(.chatList, content: CoachMarkContent(
                    icon: "hand.draw",
                    title: "Suggerimento",
                    message: "Scorri a destra una chat per fissarla in alto o segnarla come da leggere. Scorri a sinistra per eliminarla."
                ))
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && conversations.isEmpty {
            ScrollView {
                LazyVStack(spacing: BrindooSpacing.sm) {
                    ForEach(0..<7, id: \.self) { _ in BrindooSkeletonCard() }
                }
                .padding(BrindooSpacing.md)
            }
            .disabled(true)
        } else if let errorMessage, conversations.isEmpty {
            VStack(spacing: BrindooSpacing.md) {
                Spacer()
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.brindooWarning)
                Text(errorMessage)
                    .font(BrindooFont.bodyMedium)
                    .foregroundStyle(Color.brindooTextSecondary)
                BrindooButton("Riprova", style: .secondary) {
                    Task { await refresh() }
                }
                .frame(maxWidth: 200)
                Spacer()
            }
        } else if conversations.isEmpty {
            emptyView
        } else {
            list
        }
    }

    @ViewBuilder
    private var emptyView: some View {
        VStack(spacing: BrindooSpacing.md) {
            Spacer()
            ZStack {
                Circle().fill(Color.brindooCoral.opacity(0.1)).frame(width: 100, height: 100)
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.brindooCoral)
            }
            Text("Nessuna conversazione")
                .font(BrindooFont.titleMedium)
            Text("Le tue chat appariranno qui")
                .font(BrindooFont.bodyMedium)
                .foregroundStyle(Color.brindooTextSecondary)
            Spacer()
        }
    }

    @ViewBuilder
    private var list: some View {
        List {
            ForEach(conversations) { conv in
                if let otherProfile = otherProfile(for: conv) {
                    row(conv: conv, otherProfile: otherProfile)
                        .listRowInsets(EdgeInsets(
                            top: BrindooSpacing.xxs,
                            leading: BrindooSpacing.md,
                            bottom: BrindooSpacing.xxs,
                            trailing: BrindooSpacing.md
                        ))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.brindooBackground)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                conversationToDelete = conv
                            } label: {
                                Label("Elimina", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            // Fissa in alto / Sblocca
                            Button {
                                Task { await togglePin(conv) }
                            } label: {
                                let pinned = currentUserId.map { conv.isPinned(by: $0) } ?? false
                                Label(
                                    pinned ? "Sblocca" : "Fissa",
                                    systemImage: pinned ? "pin.slash.fill" : "pin.fill"
                                )
                            }
                            .tint(Color.brindooCoral)

                            // Segna come da leggere / letta
                            Button {
                                Task { await toggleUnread(conv) }
                            } label: {
                                let manualUnread = currentUserId.map { conv.isMarkedUnread(by: $0) } ?? false
                                let hasUnread = (unreadCounts[conv.id] ?? 0) > 0
                                let showAsUnread = manualUnread || hasUnread
                                Label(
                                    showAsUnread ? "Segna letta" : "Da leggere",
                                    systemImage: showAsUnread ? "envelope.open.fill" : "envelope.badge.fill"
                                )
                            }
                            .tint(Color.brindooSuccess)
                        }
                }
            }
        }
        .listStyle(.plain)
        .background(Color.brindooBackground)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func row(conv: Conversation, otherProfile: Profile) -> some View {
        let pinned = currentUserId.map { conv.isPinned(by: $0) } ?? false
        let manualUnread = currentUserId.map { conv.isMarkedUnread(by: $0) } ?? false
        let effectiveUnread = max(unreadCounts[conv.id] ?? 0, manualUnread ? 1 : 0)

        ZStack {
            NavigationLink {
                ChatView(conversation: conv, otherUser: otherProfile)
            } label: {
                EmptyView()
            }
            .opacity(0)

            ChatListRow(
                conversation: conv,
                otherUser: otherProfile,
                unreadCount: effectiveUnread,
                isPinned: pinned
            )
        }
        .contextMenu {
            Button {
                navigateToProfile = otherProfile
            } label: {
                Label("Visualizza profilo", systemImage: "person.circle")
            }

            Button {
                Task { await togglePin(conv) }
            } label: {
                Label(
                    pinned ? "Sblocca dall'alto" : "Fissa in alto",
                    systemImage: pinned ? "pin.slash" : "pin"
                )
            }

            Button {
                Task { await toggleUnread(conv) }
            } label: {
                let showAsUnread = effectiveUnread > 0
                Label(
                    showAsUnread ? "Segna come letta" : "Segna come da leggere",
                    systemImage: showAsUnread ? "envelope.open" : "envelope.badge"
                )
            }

            Button(role: .destructive) {
                conversationToDelete = conv
            } label: {
                Label("Elimina conversazione", systemImage: "trash")
            }

            Button(role: .destructive) {
                conversationToBlock = (conv, otherProfile.id)
            } label: {
                Label("Blocca profilo", systemImage: "hand.raised.slash")
            }
        }
    }

    private func otherProfile(for conversation: Conversation) -> Profile? {
        guard let userId = currentUserId else { return nil }
        let otherId = (conversation.clientId == userId) ? conversation.organizerId : conversation.clientId
        return otherProfiles[otherId]
    }

    private func loadInitial() async {
        isLoading = true
        await refresh()
        isLoading = false
    }

    private func refresh() async {
        errorMessage = nil
        do {
            let convs = try await ConversationService.shared.fetchMyConversations()
            unreadCounts = try await ConversationService.shared.fetchUnreadCounts()
            await loadOtherProfiles(for: convs)
            conversations = convs
        } catch {
            errorMessage = "Impossibile caricare le chat"
            print("❌ \(error)")
        }
    }

    private func loadOtherProfiles(for conversations: [Conversation]) async {
        guard let userId = currentUserId else { return }

        let otherIds = Set(conversations.map { $0.clientId == userId ? $0.organizerId : $0.clientId })
        let missing = otherIds.filter { otherProfiles[$0] == nil }
        guard !missing.isEmpty else { return }

        await withTaskGroup(of: (UUID, Profile?).self) { group in
            for id in missing {
                group.addTask {
                    let p = try? await ProfileService.shared.fetchProfile(userID: id)
                    return (id, p)
                }
            }
            for await (id, profile) in group {
                if let profile { otherProfiles[id] = profile }
            }
        }
    }

    private func deleteConversation(_ conversation: Conversation) async {
        do {
            try await ConversationService.shared.softDelete(conversation: conversation)
            conversations.removeAll { $0.id == conversation.id }
        } catch {
            print("❌ \(error)")
        }
    }

    private func blockUser(_ userId: UUID) async {
        do {
            try await BlockService.shared.block(userId: userId)
            if let conv = conversations.first(where: { $0.clientId == userId || $0.organizerId == userId }) {
                try await ConversationService.shared.softDelete(conversation: conv)
                conversations.removeAll { $0.id == conv.id }
            }
        } catch {
            print("❌ \(error)")
        }
    }

    private func togglePin(_ conversation: Conversation) async {
        guard let userId = currentUserId else { return }
        let newPinned = !conversation.isPinned(by: userId)
        do {
            try await ConversationService.shared.setPinned(conversation: conversation, pinned: newPinned)
            await refresh()
        } catch {
            print("❌ \(error)")
        }
    }

    private func toggleUnread(_ conversation: Conversation) async {
        guard let userId = currentUserId else { return }
        let manualUnread = conversation.isMarkedUnread(by: userId)
        let hasUnread = (unreadCounts[conversation.id] ?? 0) > 0
        let isUnreadNow = manualUnread || hasUnread

        do {
            if isUnreadNow {
                // Diventa "letta": clear flag manuale + segna messaggi letti.
                try await ConversationService.shared.setMarkedUnread(conversation: conversation, unread: false)
                if hasUnread {
                    try await MessageService.shared.markMessagesAsRead(conversationId: conversation.id)
                }
            } else {
                // Diventa "da leggere": setta flag manuale.
                try await ConversationService.shared.setMarkedUnread(conversation: conversation, unread: true)
            }
            await refresh()
        } catch {
            print("❌ \(error)")
        }
    }
}

// MARK: - Row

struct ChatListRow: View {
    let conversation: Conversation
    let otherUser: Profile
    let unreadCount: Int
    let isPinned: Bool

    init(
        conversation: Conversation,
        otherUser: Profile,
        unreadCount: Int,
        isPinned: Bool = false
    ) {
        self.conversation = conversation
        self.otherUser = otherUser
        self.unreadCount = unreadCount
        self.isPinned = isPinned
    }

    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")

        if Calendar.current.isDateInToday(conversation.lastMessageAt) {
            formatter.dateFormat = "HH:mm"
        } else if Calendar.current.isDateInYesterday(conversation.lastMessageAt) {
            return "Ieri"
        } else {
            formatter.dateFormat = "dd/MM"
        }
        return formatter.string(from: conversation.lastMessageAt)
    }

    var body: some View {
        HStack(spacing: BrindooSpacing.sm) {
            AvatarView(url: otherUser.avatarUrl, name: otherUser.fullName, size: 52)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    if isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.brindooCoral)
                    }
                    Text(otherUser.fullName ?? "Utente")
                        .font(BrindooFont.bodyLarge.weight(.semibold))
                        .foregroundStyle(Color.brindooTextPrimary)
                        .lineLimit(1)

                    if otherUser.isPro {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.brindooCoral)
                    }

                    Spacer()
                }

                Text(conversation.lastMessagePreview ?? "Nessun messaggio")
                    .font(BrindooFont.bodyMedium)
                    .foregroundStyle(unreadCount > 0 ? Color.brindooTextPrimary : Color.brindooTextSecondary)
                    .fontWeight(unreadCount > 0 ? .medium : .regular)
                    .lineLimit(1)
            }

            VStack(alignment: .trailing, spacing: 4) {
                Text(dateLabel)
                    .font(BrindooFont.caption)
                    .foregroundStyle(unreadCount > 0 ? Color.brindooCoral : Color.brindooTextSecondary)
                    .fontWeight(unreadCount > 0 ? .semibold : .regular)

                if unreadCount > 0 {
                    ZStack {
                        Circle()
                            .fill(Color.brindooCoral)
                            .frame(width: 20, height: 20)
                        Text("\(min(unreadCount, 99))")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                } else {
                    Spacer().frame(height: 20)
                }
            }
        }
        .padding(.horizontal, BrindooSpacing.md)
        .padding(.vertical, BrindooSpacing.sm)
        .background(Color.brindooSurface)
        .overlay(
            RoundedRectangle(cornerRadius: BrindooRadius.md)
                .strokeBorder(Color.brindooBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
        .contentShape(Rectangle())
    }
}
