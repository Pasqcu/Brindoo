//
//  Conversation.swift
//

import Foundation

struct Conversation: Identifiable, Codable, Hashable, Equatable {
    let id: UUID
    let clientId: UUID
    let organizerId: UUID
    let createdAt: Date
    let lastMessageAt: Date
    let lastMessagePreview: String?
    let deletedByClientAt: Date?
    let deletedByOrganizerAt: Date?
    let pinnedByClientAt: Date?
    let pinnedByOrganizerAt: Date?
    let markedUnreadByClientAt: Date?
    let markedUnreadByOrganizerAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case clientId = "client_id"
        case organizerId = "organizer_id"
        case createdAt = "created_at"
        case lastMessageAt = "last_message_at"
        case lastMessagePreview = "last_message_preview"
        case deletedByClientAt = "deleted_by_client_at"
        case deletedByOrganizerAt = "deleted_by_organizer_at"
        case pinnedByClientAt = "pinned_by_client_at"
        case pinnedByOrganizerAt = "pinned_by_organizer_at"
        case markedUnreadByClientAt = "marked_unread_by_client_at"
        case markedUnreadByOrganizerAt = "marked_unread_by_organizer_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        clientId = try c.decode(UUID.self, forKey: .clientId)
        organizerId = try c.decode(UUID.self, forKey: .organizerId)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        lastMessageAt = try c.decode(Date.self, forKey: .lastMessageAt)
        lastMessagePreview = try c.decodeIfPresent(String.self, forKey: .lastMessagePreview)
        deletedByClientAt = try c.decodeIfPresent(Date.self, forKey: .deletedByClientAt)
        deletedByOrganizerAt = try c.decodeIfPresent(Date.self, forKey: .deletedByOrganizerAt)
        pinnedByClientAt = try c.decodeIfPresent(Date.self, forKey: .pinnedByClientAt)
        pinnedByOrganizerAt = try c.decodeIfPresent(Date.self, forKey: .pinnedByOrganizerAt)
        markedUnreadByClientAt = try c.decodeIfPresent(Date.self, forKey: .markedUnreadByClientAt)
        markedUnreadByOrganizerAt = try c.decodeIfPresent(Date.self, forKey: .markedUnreadByOrganizerAt)
    }

    func isDeleted(by userId: UUID) -> Bool {
        if clientId == userId { return deletedByClientAt != nil }
        if organizerId == userId { return deletedByOrganizerAt != nil }
        return false
    }

    func visibleAfterDate(for userId: UUID) -> Date? {
        if clientId == userId { return deletedByClientAt }
        if organizerId == userId { return deletedByOrganizerAt }
        return nil
    }

    /// True se l'utente ha fissato la conversazione in alto.
    func isPinned(by userId: UUID) -> Bool {
        if clientId == userId { return pinnedByClientAt != nil }
        if organizerId == userId { return pinnedByOrganizerAt != nil }
        return false
    }

    /// True se l'utente ha marcato manualmente la conversazione come "da leggere".
    func isMarkedUnread(by userId: UUID) -> Bool {
        if clientId == userId { return markedUnreadByClientAt != nil }
        if organizerId == userId { return markedUnreadByOrganizerAt != nil }
        return false
    }
}
