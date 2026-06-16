//
//  TypingService.swift
//  Brindoo
//
//  Indicatore "sta scrivendo…" tramite Realtime broadcast.
//  Non persiste stato: gli eventi viaggiano in tempo reale tramite il canale
//  `typing-{conversationId}`.
//

import Foundation
import Supabase
import Realtime

@MainActor
final class TypingService {

    static let shared = TypingService()
    private init() {}

    private var client: SupabaseClient { SupabaseManager.shared.client }

    private struct ChannelState {
        let channel: RealtimeChannelV2
        var lastSentAt: Date?
    }

    private var channels: [UUID: ChannelState] = [:]

    /// Avvia ascolto delle digitazioni dell'altro utente sulla conversazione.
    /// `onTyping` viene invocato ogni volta che l'altro utente sta scrivendo.
    func subscribe(
        conversationId: UUID,
        currentUserId: UUID,
        onTyping: @escaping () -> Void
    ) async -> RealtimeChannelV2 {
        // Se già iscritti su questa conv, riusa il canale.
        if let existing = channels[conversationId]?.channel {
            return existing
        }

        let channel = client.realtimeV2.channel("typing-\(conversationId.uuidString)")

        let stream = channel.broadcastStream(event: "typing")

        Task {
            for await message in stream {
                // payload atteso: { "user_id": "<uuid>" }
                if let userIdString = message["user_id"]?.stringValue,
                   let userId = UUID(uuidString: userIdString),
                   userId != currentUserId {
                    onTyping()
                }
            }
        }

        Task {
            try? await channel.subscribeWithError()
        }

        channels[conversationId] = ChannelState(channel: channel, lastSentAt: nil)
        return channel
    }

    /// Invia un evento "sto scrivendo" sul canale. Throttle interno a 1.5s
    /// per evitare di intasare il broadcast.
    func sendTyping(conversationId: UUID) async {
        guard let userId = SupabaseManager.shared.currentUserID else { return }
        guard var state = channels[conversationId] else { return }

        let now = Date()
        if let last = state.lastSentAt, now.timeIntervalSince(last) < 1.5 {
            return
        }
        state.lastSentAt = now
        channels[conversationId] = state

        await state.channel.broadcast(
            event: "typing",
            message: ["user_id": .string(userId.uuidString)]
        )
    }

    func unsubscribe(conversationId: UUID) async {
        if let state = channels.removeValue(forKey: conversationId) {
            await state.channel.unsubscribe()
        }
    }
}
