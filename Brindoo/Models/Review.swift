//
//  Review.swift
//  Brindoo
//
//  Modelli per le recensioni e il rating aggregato.
//

import Foundation

// MARK: - Review

/// Recensione di un cliente verso un organizzatore
struct Review: Codable, Identifiable, Equatable, Hashable {

    let id: UUID
    let clientId: UUID
    let organizerId: UUID
    let applicationId: UUID?
    let rating: Int
    let comment: String?
    /// True se la recensione segue una trattativa realmente conclusa.
    let verified: Bool?
    /// Risposta dell'organizzatore alla recensione (facoltativa).
    let reply: String?
    let replyAt: Date?
    /// Foto dell'evento allegata dal cliente (facoltativa).
    let photoUrl: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case clientId = "client_id"
        case organizerId = "organizer_id"
        case applicationId = "application_id"
        case rating
        case comment
        case verified
        case reply
        case replyAt = "reply_at"
        case photoUrl = "photo_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Comodità: true quando la recensione è verificata.
    var isVerified: Bool { verified ?? false }

    /// "5 minuti fa", "2 giorni fa", ecc.
    var createdAtDisplay: String {
        BrindooFormat.timeAgo(createdAt)
    }
}

// MARK: - Rating aggregato

/// Rating aggregato di un organizzatore (dalla view `organizer_ratings`).
struct OrganizerRating: Codable, Equatable, Hashable {

    let organizerId: UUID
    let avgRating: Double
    let reviewCount: Int

    enum CodingKeys: String, CodingKey {
        case organizerId = "organizer_id"
        case avgRating = "avg_rating"
        case reviewCount = "review_count"
    }

    /// Stringa formattata: "4.7" oppure "—" se non ci sono recensioni
    var displayRating: String {
        guard reviewCount > 0 else { return "—" }
        return String(format: "%.1f", avgRating)
    }

    /// "12 recensioni" / "1 recensione" / "Nessuna recensione"
    var displayReviewCount: String {
        switch reviewCount {
        case 0: return "Nessuna recensione"
        case 1: return "1 recensione"
        default: return "\(reviewCount) recensioni"
        }
    }

    /// Alias per compatibilità con UI esistente
    var averageRating: Double { avgRating }
    var totalReviews: Int { reviewCount }
}

// Alias storico, alcune view lo usano ancora come "ReviewSummary".
typealias ReviewSummary = OrganizerRating

// MARK: - Payload creazione

/// Payload per creare una nuova recensione
struct NewReview: Encodable {
    let client_id: UUID
    let organizer_id: UUID
    let application_id: UUID?
    let rating: Int
    let comment: String?
    let verified: Bool
    let photo_url: String?
}
