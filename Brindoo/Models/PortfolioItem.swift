//
//  PortfolioItem.swift
//  Brindoo
//
//  Modello per le foto del portfolio degli organizzatori.
//

import Foundation

struct PortfolioItem: Codable, Identifiable, Equatable, Hashable {
    
    let id: UUID
    let organizerId: UUID
    let imageUrl: String
    let storagePath: String
    var caption: String?
    var sortOrder: Int
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case organizerId = "organizer_id"
        case imageUrl = "image_url"
        case storagePath = "storage_path"
        case caption
        case sortOrder = "sort_order"
        case createdAt = "created_at"
    }
}

extension PortfolioItem {

    /// I video del portfolio sono file .mp4 nello stesso bucket delle foto:
    /// nessuna colonna nuova, decide l'estensione.
    var isVideo: Bool { imageUrl.hasSuffix(".mp4") }

    /// Per i video le griglie mostrano il fotogramma di copertina caricato
    /// accanto al file (stesso percorso + ".jpg").
    var thumbnailUrl: String { isVideo ? imageUrl + ".jpg" : imageUrl }
}

/// Payload per inserire un nuovo item nel portfolio
struct NewPortfolioItem: Encodable {
    let organizer_id: UUID
    let image_url: String
    let storage_path: String
    let caption: String?
    let sort_order: Int
}
