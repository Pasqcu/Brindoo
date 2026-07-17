//
//  MessageService.swift
//

import Foundation
import Supabase
import Realtime
import UIKit

@MainActor
final class MessageService {
    
    static let shared = MessageService()
    private init() {}
    
    private var client: SupabaseClient {
        SupabaseManager.shared.client
    }
    
    // MARK: - Fetch
    
    /// Fetch messaggi della conversazione, applicando soft-delete date
    func fetchMessages(conversationId: UUID, visibleAfter: Date? = nil) async throws -> [Message] {
        var query = client
            .from("messages")
            .select()
            .eq("conversation_id", value: conversationId)
        
        if let visibleAfter {
            let iso = ISO8601DateFormatter().string(from: visibleAfter)
            query = query.gt("created_at", value: iso)
        }
        
        let result: [Message] = try await query
            .order("created_at", ascending: true)
            .execute()
            .value
        
        return result
    }
    
    // MARK: - Send messaggio testuale
    
    @discardableResult
    func sendMessage(
        conversationId: UUID,
        content: String,
        repliedToId: UUID? = nil
    ) async throws -> Message {
        guard let senderId = SupabaseManager.shared.currentUserID else {
            throw NSError(domain: "Msg", code: 401)
        }
        
        struct Payload: Encodable {
            let conversation_id: UUID
            let sender_id: UUID
            let content: String
            let message_type: String
            let replied_to_id: UUID?
        }
        
        let payload = Payload(
            conversation_id: conversationId,
            sender_id: senderId,
            content: content,
            message_type: "text",
            replied_to_id: repliedToId
        )
        
        let inserted: Message = try await client
            .from("messages")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
        
        await updateConversationLastMessage(conversationId: conversationId, preview: content)
        return inserted
    }
    
    // MARK: - Send messaggio di sistema

    /// Messaggio "di servizio" mostrato al centro della chat (es. data evento
    /// spostata). Viene inviato a nome dell'utente corrente ma reso come nota.
    @discardableResult
    func sendSystemMessage(
        conversationId: UUID,
        content: String
    ) async throws -> Message {
        guard let senderId = SupabaseManager.shared.currentUserID else {
            throw NSError(domain: "Msg", code: 401)
        }

        struct Payload: Encodable {
            let conversation_id: UUID
            let sender_id: UUID
            let content: String
            let message_type: String
        }

        let payload = Payload(
            conversation_id: conversationId,
            sender_id: senderId,
            content: content,
            message_type: "system"
        )

        let inserted: Message = try await client
            .from("messages")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        await updateConversationLastMessage(conversationId: conversationId, preview: content)
        return inserted
    }

    // MARK: - Send foto

    @discardableResult
    func sendImage(
        conversationId: UUID,
        image: UIImage,
        isBomb: Bool = false
    ) async throws -> Message {
        guard let senderId = SupabaseManager.shared.currentUserID else {
            throw NSError(domain: "Msg", code: 401)
        }
        
        // Upload immagine su storage temporaneo
        let imageUrl = try await uploadChatImage(image: image, senderId: senderId)
        
        struct Payload: Encodable {
            let conversation_id: UUID
            let sender_id: UUID
            let content: String
            let message_type: String
            let image_url: String
            let is_bomb: Bool
        }
        
        let payload = Payload(
            conversation_id: conversationId,
            sender_id: senderId,
            content: "",
            message_type: isBomb ? "bomb_image" : "image",
            image_url: imageUrl,
            is_bomb: isBomb
        )
        
        let inserted: Message = try await client
            .from("messages")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
        
        await updateConversationLastMessage(
            conversationId: conversationId,
            preview: isBomb ? "💣 Foto bomba" : "📷 Foto"
        )
        return inserted
    }
    
    private func uploadChatImage(image: UIImage, senderId: UUID) async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.7) else {
            throw NSError(domain: "Storage", code: 500)
        }
        
        let fileName = "\(senderId.uuidString.lowercased())/\(UUID().uuidString.lowercased()).jpg"
        
        try await client.storage
            .from("chat-images")
            .upload(
                fileName,
                data: data,
                options: FileOptions(contentType: "image/jpeg", upsert: false)
            )
        
        let publicUrl = try client.storage
            .from("chat-images")
            .getPublicURL(path: fileName)
        
        return publicUrl.absoluteString
    }
    
    // MARK: - Edit messaggio
    
    func editMessage(messageId: UUID, newContent: String) async throws {
        struct Payload: Encodable {
            let content: String
            let edited_at: String
        }
        
        let payload = Payload(
            content: newContent,
            edited_at: ISO8601DateFormatter().string(from: Date())
        )
        
        try await client
            .from("messages")
            .update(payload)
            .eq("id", value: messageId)
            .execute()
    }
    
    // MARK: - Mark bomb as viewed
    
    /// Marca una foto bomba come visualizzata ed elimina l'immagine dallo storage
    func markBombViewed(message: Message) async throws {
        guard message.isBomb else { return }
        
        // 1. Cancella file da storage
        if let urlString = message.imageUrl,
           let url = URL(string: urlString) {
            // Estrai path: chat-images/UUID/filename.jpg
            let path = url.pathComponents.suffix(2).joined(separator: "/")
            _ = try? await client.storage
                .from("chat-images")
                .remove(paths: [path])
        }
        
        // 2. Aggiorna messaggio: marca come visto e svuota URL
        struct Payload: Encodable {
            let bomb_viewed_at: String
            let image_url: String?
        }
        
        try await client
            .from("messages")
            .update(Payload(
                bomb_viewed_at: ISO8601DateFormatter().string(from: Date()),
                image_url: nil
            ))
            .eq("id", value: message.id)
            .execute()
    }
    
    // MARK: - Delete messaggio
    
    func deleteMessage(messageId: UUID) async throws {
        struct Payload: Encodable {
            let deleted_at: String
            let content: String
            let image_url: String?
        }
        
        try await client
            .from("messages")
            .update(Payload(
                deleted_at: ISO8601DateFormatter().string(from: Date()),
                content: "",
                image_url: nil
            ))
            .eq("id", value: messageId)
            .execute()
    }
    
    // MARK: - Read receipts
    
    /// Marca i messaggi della conversazione come letti.
    /// Rispetta la preferenza read_receipts: se l'utente non vuole far sapere
    /// quando ha letto, NON aggiorna is_read.
    func markMessagesAsRead(conversationId: UUID) async throws {
        guard let userId = SupabaseManager.shared.currentUserID else { return }
        
        // Carica preferenza dell'utente
        let profile = try await ProfileService.shared.fetchProfile(userID: userId)
        guard profile?.readReceiptsEnabled == true else {
            BrindooLog.info("Read receipts disabilitati, non marco come letto")
            return
        }
        
        struct Update: Encodable {
            let is_read: Bool
        }
        
        try await client
            .from("messages")
            .update(Update(is_read: true))
            .eq("conversation_id", value: conversationId)
            .neq("sender_id", value: userId)
            .eq("is_read", value: false)
            .execute()
    }
    
    // MARK: - Last message preview
    
    private func updateConversationLastMessage(conversationId: UUID, preview: String) async {
        struct Payload: Encodable {
            let last_message_at: String
            let last_message_preview: String
        }
        
        let trimmed = String(preview.prefix(100))
        let payload = Payload(
            last_message_at: ISO8601DateFormatter().string(from: Date()),
            last_message_preview: trimmed
        )
        
        _ = try? await client
            .from("conversations")
            .update(payload)
            .eq("id", value: conversationId)
            .execute()
    }

    // MARK: - Realtime subscribe
    
    func subscribeToMessages(
        conversationId: UUID,
        onInsert: @escaping (Message) -> Void,
        onUpdate: @escaping (Message) -> Void
    ) -> RealtimeChannelV2 {
        let channel = client.realtimeV2.channel("conv-\(conversationId.uuidString)")

        // IMPORTANTE: registrare i callback PRIMA di subscribe(), altrimenti
        // il Realtime stampa un warning e li ignora.
        let insertStream = channel.postgresChange(
            InsertAction.self,
            table: "messages",
            filter: .eq("conversation_id", value: conversationId.uuidString)
        )
        let updateStream = channel.postgresChange(
            UpdateAction.self,
            table: "messages",
            filter: .eq("conversation_id", value: conversationId.uuidString)
        )

        Task {
            for await action in insertStream {
                if let message = try? action.decodeRecord(as: Message.self, decoder: JSONDecoder.brindooDecoder) {
                    onInsert(message)
                }
            }
        }

        Task {
            for await action in updateStream {
                if let message = try? action.decodeRecord(as: Message.self, decoder: JSONDecoder.brindooDecoder) {
                    onUpdate(message)
                }
            }
        }

        Task {
            try? await channel.subscribeWithError()
        }

        return channel
    }
}

extension JSONDecoder {
    static var brindooDecoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
