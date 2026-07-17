//
//  ServiceOffer.swift
//  Brindoo
//
//  Offerta di servizio pubblicata da un organizzatore.
//  Visibile ai clienti nella bacheca.
//

import Foundation

/// Stato di un'offerta di servizio
enum ServiceOfferStatus: String, Codable, CaseIterable {
    case active
    case paused

    var displayName: String {
        switch self {
        case .active: return "Attiva"
        case .paused: return "In pausa"
        }
    }
}

struct ServiceOffer: Identifiable, Codable, Hashable, Equatable {
    let id: UUID
    let organizerId: UUID
    let title: String
    let description: String
    let coverageArea: String
    let price: Double
    let status: ServiceOfferStatus
    /// Foto di copertina dell'offerta (opzionale).
    let imageUrl: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case organizerId = "organizer_id"
        case title
        case description
        case coverageArea = "coverage_area"
        case price
        case status
        case imageUrl = "image_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// True se l'offerta è stata pubblicata da meno di 7 giorni ("Nuovo").
    func isNew(asOf now: Date = Date()) -> Bool {
        now.timeIntervalSince(createdAt) < 7 * 24 * 60 * 60
    }

    var isNew: Bool { isNew() }

    /// Stringa formattata del prezzo.
    var priceDisplay: String {
        BrindooFormat.euro(price)
    }

    /// "5 minuti fa", "2 giorni fa", ecc.
    var createdAtDisplay: String {
        BrindooFormat.timeAgo(createdAt)
    }
}

/// Struttura helper per raggruppare offerta + categorie collegate.
struct ServiceOfferWithCategories: Identifiable, Hashable, Equatable {
    let offer: ServiceOffer
    let categories: [ServiceCategory]

    var id: UUID { offer.id }
}
