//
//  ChatMessagesList.swift
//  Brindoo
//
//  Lista scorrevole dei messaggi (estratta da ChatView) e menu opzioni
//  della conversazione. ChatView resta il "regista": stato e azioni.
//

import SwiftUI

// MARK: - Lista messaggi con auto-scroll

struct ChatMessagesList: View {
    let messages: [Message]
    let currentUserId: UUID?
    let otherUser: Profile
    let myReadReceiptsEnabled: Bool

    let onTapImage: (String, Message) -> Void
    let onTapBomb: (Message) -> Void
    let onReply: (Message) -> Void
    let onEdit: (Message) -> Void
    let onDelete: (Message) -> Void
    let onReport: (Message) -> Void
    let onRefresh: () async -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: BrindooSpacing.xs) {
                    ForEach(messages) { message in
                        let isOwn = message.senderId == currentUserId
                        if message.messageType == .system {
                            ChatSystemNote(text: message.content)
                                .id(message.id)
                        } else {
                            MessageBubble(
                                message: message,
                                isOwn: isOwn,
                                repliedTo: repliedToMessage(for: message),
                                otherUserReadReceiptsEnabled: otherUser.readReceiptsEnabled,
                                myReadReceiptsEnabled: myReadReceiptsEnabled,
                                onTapImage: { url in onTapImage(url, message) },
                                onTapBomb: { onTapBomb(message) },
                                onReply: { onReply(message) },
                                onEdit: { onEdit(message) },
                                onDelete: { onDelete(message) },
                                onReport: { onReport(message) }
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
            .refreshable { await onRefresh() }
        }
    }

    private func repliedToMessage(for message: Message) -> Message? {
        guard let id = message.repliedToId else { return nil }
        return messages.first { $0.id == id }
    }
}

// MARK: - Menu opzioni conversazione

struct ChatOptionsMenu: View {
    let isBlocked: Bool
    let onViewProfile: () -> Void
    let onDeleteConversation: () -> Void
    let onBlock: () -> Void
    let onUnblock: () -> Void
    let onReport: () -> Void

    var body: some View {
        Menu {
            Button(action: onViewProfile) {
                Label("Visualizza profilo", systemImage: "person.circle")
            }

            Button(role: .destructive, action: onDeleteConversation) {
                Label("Elimina conversazione", systemImage: "trash")
            }

            if !isBlocked {
                Button(role: .destructive, action: onBlock) {
                    Label("Blocca utente", systemImage: "hand.raised.slash")
                }
            } else {
                Button(action: onUnblock) {
                    Label("Sblocca utente", systemImage: "hand.raised")
                }
            }

            Divider()

            Button(role: .destructive, action: onReport) {
                Label("Segnala utente", systemImage: "exclamationmark.bubble")
            }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundStyle(Color.brindooTextPrimary)
        }
        .accessibilityLabel("Opzioni conversazione")
    }
}
