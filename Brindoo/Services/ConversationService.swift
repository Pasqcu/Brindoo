//
//  ConversationService.swift
//

import Foundation
import Supabase
import Realtime

@MainActor
@Observable
final class ConversationService {
    
    static let shared = ConversationService()
    private init() {}
    
    private var client: SupabaseClient {
        SupabaseManager.shared.client
    }
    
    private(set) var conversations: [Conversation] = []
    private var realtimeChannel: RealtimeChannelV2?
    
    @discardableResult
    func fetchMyConversations() async throws -> [Conversation] {
        guard let userId = SupabaseManager.shared.currentUserID else { return [] }

        let result: [Conversation] = try await client
            .from("conversations")
            .select()
            .or("client_id.eq.\(userId.uuidString),organizer_id.eq.\(userId.uuidString)")
            .order("last_message_at", ascending: false)
            .execute()
            .value

        let visible = result.filter { !$0.isDeleted(by: userId) }
        // Pinned first, poi per data ultimo messaggio (già ordinato lato DB).
        let sorted = visible.sorted { a, b in
            let aPinned = a.isPinned(by: userId)
            let bPinned = b.isPinned(by: userId)
            if aPinned != bPinned { return aPinned }
            return a.lastMessageAt > b.lastMessageAt
        }
        self.conversations = sorted
        return sorted
    }
    
    func fetchUnreadCounts() async throws -> [UUID: Int] {
        guard let userId = SupabaseManager.shared.currentUserID else { return [:] }
        
        struct Row: Decodable {
            let conversation_id: UUID
        }
        
        let rows: [Row] = try await client
            .from("messages")
            .select("conversation_id")
            .neq("sender_id", value: userId)
            .eq("is_read", value: false)
            .execute()
            .value
        
        var counts: [UUID: Int] = [:]
        for row in rows {
            counts[row.conversation_id, default: 0] += 1
        }
        return counts
    }
    
    func startListening(onChange: @escaping () -> Void) async {
        guard let userId = SupabaseManager.shared.currentUserID else { return }

        await stopListening()

        let channel = client.realtimeV2.channel("conv-list-\(userId.uuidString)")

        // IMPORTANTE: registrare i callback PRIMA di chiamare subscribe(),
        // altrimenti il Realtime stampa un warning e li ignora.
        let conversationsStream = channel.postgresChange(AnyAction.self, table: "conversations")
        let messagesStream = channel.postgresChange(InsertAction.self, table: "messages")

        Task {
            for await _ in conversationsStream {
                onChange()
            }
        }

        Task {
            for await _ in messagesStream {
                onChange()
            }
        }

        try? await channel.subscribeWithError()
        self.realtimeChannel = channel
    }
    
    func stopListening() async {
        if let channel = realtimeChannel {
            await channel.unsubscribe()
            realtimeChannel = nil
        }
    }
    
    func findOrCreateConversationAsClient(organizerId: UUID) async throws -> Conversation {
        guard let clientId = SupabaseManager.shared.currentUserID else {
            throw NSError(domain: "Conv", code: 401)
        }
        
        let existing: [Conversation] = try await client
            .from("conversations")
            .select()
            .eq("client_id", value: clientId)
            .eq("organizer_id", value: organizerId)
            .execute()
            .value
        
        if let existing = existing.first {
            if existing.deletedByClientAt != nil {
                try await client
                    .from("conversations")
                    .update(NullableColumnUpdate(column: "deleted_by_client_at", value: nil))
                    .eq("id", value: existing.id)
                    .execute()
            }
            return existing
        }

        struct NewConv: Encodable {
            let client_id: UUID
            let organizer_id: UUID
        }

        let created: Conversation = try await client
            .from("conversations")
            .insert(NewConv(client_id: clientId, organizer_id: organizerId))
            .select()
            .single()
            .execute()
            .value

        return created
    }

    func findOrCreateConversationAsOrganizer(clientId: UUID) async throws -> Conversation {
        guard let organizerId = SupabaseManager.shared.currentUserID else {
            throw NSError(domain: "Conv", code: 401)
        }

        let existing: [Conversation] = try await client
            .from("conversations")
            .select()
            .eq("client_id", value: clientId)
            .eq("organizer_id", value: organizerId)
            .execute()
            .value

        if let existing = existing.first {
            if existing.deletedByOrganizerAt != nil {
                try await client
                    .from("conversations")
                    .update(NullableColumnUpdate(column: "deleted_by_organizer_at", value: nil))
                    .eq("id", value: existing.id)
                    .execute()
            }
            return existing
        }
        
        struct NewConv: Encodable {
            let client_id: UUID
            let organizer_id: UUID
        }
        
        let created: Conversation = try await client
            .from("conversations")
            .insert(NewConv(client_id: clientId, organizer_id: organizerId))
            .select()
            .single()
            .execute()
            .value
        
        return created
    }
    
    func softDelete(conversation: Conversation) async throws {
        guard let userId = SupabaseManager.shared.currentUserID else { return }

        let now = ISO8601DateFormatter().string(from: Date())

        if conversation.clientId == userId {
            struct U: Encodable { let deleted_by_client_at: String }
            try await client
                .from("conversations")
                .update(U(deleted_by_client_at: now))
                .eq("id", value: conversation.id)
                .execute()
        } else if conversation.organizerId == userId {
            struct U: Encodable { let deleted_by_organizer_at: String }
            try await client
                .from("conversations")
                .update(U(deleted_by_organizer_at: now))
                .eq("id", value: conversation.id)
                .execute()
        }
    }

    // MARK: - Pin / Unpin

    /// Fissa in alto la conversazione per l'utente corrente.
    func setPinned(conversation: Conversation, pinned: Bool) async throws {
        guard let userId = SupabaseManager.shared.currentUserID else { return }
        let nowString: String? = pinned ? ISO8601DateFormatter().string(from: Date()) : nil

        let column: String
        if conversation.clientId == userId {
            column = "pinned_by_client_at"
        } else if conversation.organizerId == userId {
            column = "pinned_by_organizer_at"
        } else {
            return
        }

        try await client
            .from("conversations")
            .update(NullableColumnUpdate(column: column, value: nowString))
            .eq("id", value: conversation.id)
            .execute()
    }

    // MARK: - Mark as unread

    /// Marca manualmente la conversazione come "da leggere" per l'utente corrente.
    func setMarkedUnread(conversation: Conversation, unread: Bool) async throws {
        guard let userId = SupabaseManager.shared.currentUserID else { return }
        let nowString: String? = unread ? ISO8601DateFormatter().string(from: Date()) : nil

        let column: String
        if conversation.clientId == userId {
            column = "marked_unread_by_client_at"
        } else if conversation.organizerId == userId {
            column = "marked_unread_by_organizer_at"
        } else {
            return
        }

        try await client
            .from("conversations")
            .update(NullableColumnUpdate(column: column, value: nowString))
            .eq("id", value: conversation.id)
            .execute()
    }
}

