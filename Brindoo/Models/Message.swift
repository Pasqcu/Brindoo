//
//  Message.swift
//

import Foundation

enum MessageType: String, Codable {
    case text
    case image
    case bombImage = "bomb_image"
    case system
}

struct Message: Identifiable, Codable, Hashable, Equatable {
    let id: UUID
    let conversationId: UUID
    let senderId: UUID
    var content: String
    let createdAt: Date
    var isRead: Bool
    let messageType: MessageType
    let imageUrl: String?
    let repliedToId: UUID?
    let editedAt: Date?
    let deletedAt: Date?
    let isBomb: Bool
    let bombViewedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case senderId = "sender_id"
        case content
        case createdAt = "created_at"
        case isRead = "is_read"
        case messageType = "message_type"
        case imageUrl = "image_url"
        case repliedToId = "replied_to_id"
        case editedAt = "edited_at"
        case deletedAt = "deleted_at"
        case isBomb = "is_bomb"
        case bombViewedAt = "bomb_viewed_at"
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        conversationId = try c.decode(UUID.self, forKey: .conversationId)
        senderId = try c.decode(UUID.self, forKey: .senderId)
        content = try c.decodeIfPresent(String.self, forKey: .content) ?? ""
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        isRead = try c.decodeIfPresent(Bool.self, forKey: .isRead) ?? false
        messageType = try c.decodeIfPresent(MessageType.self, forKey: .messageType) ?? .text
        imageUrl = try c.decodeIfPresent(String.self, forKey: .imageUrl)
        repliedToId = try c.decodeIfPresent(UUID.self, forKey: .repliedToId)
        editedAt = try c.decodeIfPresent(Date.self, forKey: .editedAt)
        deletedAt = try c.decodeIfPresent(Date.self, forKey: .deletedAt)
        isBomb = try c.decodeIfPresent(Bool.self, forKey: .isBomb) ?? false
        bombViewedAt = try c.decodeIfPresent(Date.self, forKey: .bombViewedAt)
    }
    
    var isEdited: Bool { editedAt != nil }
    var isDeleted: Bool { deletedAt != nil }
    
    var isEditable: Bool {
        guard messageType == .text, !isDeleted else { return false }
        return editableSecondsRemaining > 10
    }

    var editableSecondsRemaining: TimeInterval {
        max(0, 300 - Date().timeIntervalSince(createdAt))
    }
}
