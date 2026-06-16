//
//  OrganizerService.swift
//

import Foundation
import Supabase

@MainActor
final class OrganizerService {

    static let shared = OrganizerService()
    private init() {}

    private var client: SupabaseClient {
        SupabaseManager.shared.client
    }

    /// Restituisce gli organizzatori visibili in bacheca al cliente.
    /// Filtra per categorie (OR logico se più selezionate), testo di ricerca e città.
    /// Esclude l'utente corrente e gli utenti bloccati.
    func fetchOrganizers(
        categoryIds: Set<UUID> = [],
        areaFilters: Set<String> = [],
        searchText: String? = nil,
        city: String? = nil,
        includeCurrentUser: Bool = false,
        limit: Int = 50
    ) async throws -> [Profile] {
        let currentUserId = SupabaseManager.shared.currentUserID

        var query = client
            .from("profiles")
            .select()
            .eq("role", value: UserRole.organizer.rawValue)
            .not("full_name", operator: .is, value: "null")

        if let currentUserId, !includeCurrentUser {
            query = query.neq("id", value: currentUserId)
        }

        // Filtro per aree di copertura: include sia i professionisti con almeno
        // un'area corrispondente, sia quelli senza aree dichiarate (= ovunque
        // nel Lazio). Implementato con `or` PostgREST: overlap OR empty array.
        if !areaFilters.isEmpty {
            query = query.or(
                "coverage_areas.ov.{\(areaFilters.joined(separator: ","))},coverage_areas.eq.{}"
            )
        }

        if let city, !city.trimmingCharacters(in: .whitespaces).isEmpty {
            query = query.ilike("city", pattern: "%\(city)%")
        }

        if let searchText, !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            query = query.ilike("full_name", pattern: "%\(searchText)%")
        }

        // Ordinamento: Boost > Pro > updated_at
        var profiles: [Profile] = try await query
            .order("boost_expires_at", ascending: false, nullsFirst: false)
            .order("is_pro", ascending: false)
            .order("updated_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        // Filtro multi-categoria (OR)
        if !categoryIds.isEmpty {
            let organizerIdsForCategories = try await fetchOrganizersInCategories(categoryIds: categoryIds)
            profiles = profiles.filter { organizerIdsForCategories.contains($0.id) }
        }

        // Escludi utenti bloccati o che mi hanno bloccato
        let blocked = BlockService.shared.blockedIds.union(BlockService.shared.blockedByIds)
        profiles = profiles.filter { !blocked.contains($0.id) }

        return profiles
    }

    /// Organizzatori che hanno ALMENO una delle categorie indicate.
    private func fetchOrganizersInCategories(categoryIds: Set<UUID>) async throws -> Set<UUID> {
        struct Row: Decodable { let organizer_id: UUID }

        let idStrings = categoryIds.map { $0.uuidString }

        let rows: [Row] = try await client
            .from("organizer_categories")
            .select("organizer_id")
            .in("category_id", values: idStrings)
            .execute()
            .value

        return Set(rows.map { $0.organizer_id })
    }

    func fetchOrganizerCategories(organizerID: UUID) async throws -> [ServiceCategory] {
        struct JoinRow: Decodable {
            let service_categories: ServiceCategory
        }

        let rows: [JoinRow] = try await client
            .from("organizer_categories")
            .select("service_categories(*)")
            .eq("organizer_id", value: organizerID)
            .execute()
            .value

        return rows.map { $0.service_categories }
    }
}
