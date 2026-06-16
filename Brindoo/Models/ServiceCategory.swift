//
//  ServiceCategory.swift
//  Brindoo
//
//  Modello che rappresenta una categoria di servizio
//  (es. Animazione, Foto e Video, Catering, ecc.)
//

import Foundation
import SwiftUI

struct ServiceCategory: Codable, Identifiable, Hashable {
    
    let id: UUID
    let slug: String
    let name: String
    let icon: String
    let description: String?
    let sortOrder: Int
    let isActive: Bool
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case slug
        case name
        case icon
        case description
        case sortOrder = "sort_order"
        case isActive = "is_active"
        case createdAt = "created_at"
    }
}

// MARK: - Helper

extension ServiceCategory {
    /// Colore distintivo della categoria, derivato dallo slug.
    var tint: Color { Color.brindooCategory(slug) }

    /// Categoria placeholder per anteprime SwiftUI
    static var preview: ServiceCategory {
        ServiceCategory(
            id: UUID(),
            slug: "animation",
            name: "Animazione",
            icon: "sparkles",
            description: "Animatori, intrattenitori, mascotte",
            sortOrder: 1,
            isActive: true,
            createdAt: Date()
        )
    }
    
    static var previewList: [ServiceCategory] {
        [
            ServiceCategory(id: UUID(), slug: "animation", name: "Animazione", icon: "sparkles", description: nil, sortOrder: 1, isActive: true, createdAt: Date()),
            ServiceCategory(id: UUID(), slug: "photo", name: "Foto e Video", icon: "camera.fill", description: nil, sortOrder: 2, isActive: true, createdAt: Date()),
            ServiceCategory(id: UUID(), slug: "catering", name: "Catering", icon: "fork.knife", description: nil, sortOrder: 3, isActive: true, createdAt: Date()),
            ServiceCategory(id: UUID(), slug: "music", name: "Musica e DJ", icon: "music.note", description: nil, sortOrder: 4, isActive: true, createdAt: Date()),
            ServiceCategory(id: UUID(), slug: "location", name: "Location", icon: "building.2.fill", description: nil, sortOrder: 5, isActive: true, createdAt: Date())
        ]
    }
}
