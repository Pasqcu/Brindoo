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

    /// Una pagina di organizzatori visibili in bacheca al cliente.
    /// `hasMore` è true quando esiste (probabilmente) una pagina successiva.
    struct OrganizersPage {
        let profiles: [Profile]
        let hasMore: Bool
    }

    /// Restituisce gli organizzatori visibili in bacheca al cliente, a pagine.
    /// Filtra per categorie (OR logico se più selezionate), testo di ricerca e città.
    /// Esclude l'utente corrente e gli utenti bloccati.
    func fetchOrganizers(
        categoryIds: Set<UUID> = [],
        areaFilters: Set<String> = [],
        searchText: String? = nil,
        city: String? = nil,
        includeCurrentUser: Bool = false,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> OrganizersPage {
        let currentUserId = SupabaseManager.shared.currentUserID

        // Filtro multi-categoria (OR) applicato a monte, così la paginazione
        // lavora su pagine "vere" e non su pagine svuotate a valle.
        var allowedIds: Set<UUID>? = nil
        if !categoryIds.isEmpty {
            allowedIds = try await fetchOrganizersInCategories(categoryIds: categoryIds)
            if allowedIds?.isEmpty == true {
                return OrganizersPage(profiles: [], hasMore: false)
            }
        }

        var query = client
            .from("profiles")
            .select()
            .eq("role", value: UserRole.organizer.rawValue)
            .not("full_name", operator: .is, value: "null")

        if let currentUserId, !includeCurrentUser {
            query = query.neq("id", value: currentUserId)
        }

        // Con troppe corrispondenze il filtro `in` renderebbe l'URL enorme:
        // in quel caso si torna al filtro a valle (caso raro).
        var filterCategoriesLocally = false
        if let allowedIds {
            if allowedIds.count <= 150 {
                query = query.in("id", values: allowedIds.map { $0.uuidString })
            } else {
                filterCategoriesLocally = true
            }
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
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value

        // La pagina è "piena" se il DB ha restituito esattamente `limit` righe,
        // valutato prima dei filtri applicati in locale.
        let hasMore = profiles.count == limit

        if filterCategoriesLocally, let allowedIds {
            profiles = profiles.filter { allowedIds.contains($0.id) }
        }

        // Escludi utenti bloccati o che mi hanno bloccato
        let blocked = BlockService.shared.blockedIds.union(BlockService.shared.blockedByIds)
        profiles = profiles.filter { !blocked.contains($0.id) }

        return OrganizersPage(profiles: profiles, hasMore: hasMore)
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

    /// Categorie di più organizzatori in un'unica richiesta (una sola query
    /// invece di una per professionista — la bacheca ringrazia).
    func fetchOrganizerCategoriesMap(organizerIds: [UUID]) async throws -> [UUID: [ServiceCategory]] {
        guard !organizerIds.isEmpty else { return [:] }
        struct Row: Decodable {
            let organizer_id: UUID
            let service_categories: ServiceCategory
        }
        let rows: [Row] = try await client
            .from("organizer_categories")
            .select("organizer_id, service_categories(*)")
            .in("organizer_id", values: organizerIds.map { $0.uuidString })
            .execute()
            .value
        return Dictionary(grouping: rows, by: { $0.organizer_id })
            .mapValues { $0.map(\.service_categories) }
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
