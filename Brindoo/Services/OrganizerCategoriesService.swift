//
//  OrganizerCategoriesService.swift
//

import Foundation
import Supabase

struct OrganizerCategoryDetail: Identifiable, Hashable, Equatable {
    let category: ServiceCategory
    let description: String?
    
    var id: UUID { category.id }
}

@MainActor
final class OrganizerCategoriesService {
    
    static let shared = OrganizerCategoriesService()
    private init() {}
    
    private var client: SupabaseClient {
        SupabaseManager.shared.client
    }
    
    func fetchDetailed(organizerId: UUID) async throws -> [OrganizerCategoryDetail] {
        struct Row: Decodable {
            let category_id: UUID
            let description: String?
            let service_categories: ServiceCategory
        }
        
        let rows: [Row] = try await client
            .from("organizer_categories")
            .select("category_id, description, service_categories(*)")
            .eq("organizer_id", value: organizerId)
            .execute()
            .value
        
        return rows.map { OrganizerCategoryDetail(category: $0.service_categories, description: $0.description) }
    }
    
    func updateCategoriesWithDescriptions(
        organizerId: UUID,
        items: [(categoryId: UUID, description: String?)]
    ) async throws {
        try await client
            .from("organizer_categories")
            .delete()
            .eq("organizer_id", value: organizerId)
            .execute()
        
        guard !items.isEmpty else { return }
        
        struct Payload: Encodable {
            let organizer_id: UUID
            let category_id: UUID
            let description: String?
        }
        
        let payloads = items.map {
            Payload(organizer_id: organizerId, category_id: $0.categoryId, description: $0.description)
        }
        
        try await client
            .from("organizer_categories")
            .insert(payloads)
            .execute()
    }
    
    func updateCategories(organizerId: UUID, add: [UUID], remove: [UUID]) async throws {
        if !remove.isEmpty {
            for catId in remove {
                try await client
                    .from("organizer_categories")
                    .delete()
                    .eq("organizer_id", value: organizerId)
                    .eq("category_id", value: catId)
                    .execute()
            }
        }
        
        if !add.isEmpty {
            struct Payload: Encodable {
                let organizer_id: UUID
                let category_id: UUID
            }
            
            let payloads = add.map { Payload(organizer_id: organizerId, category_id: $0) }
            try await client
                .from("organizer_categories")
                .insert(payloads)
                .execute()
        }
    }
}
