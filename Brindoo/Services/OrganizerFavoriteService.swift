//
//  OrganizerFavoriteService.swift
//  Brindoo
//
//  Preferiti degli organizer lato cliente. Tabella `organizer_favorites`.
//

import Foundation
import Supabase

@MainActor
final class OrganizerFavoriteService {

    static let shared = OrganizerFavoriteService()
    private init() {}

    private var client: SupabaseClient { SupabaseManager.shared.client }

    func fetchMyFavoriteOrganizerIds() async throws -> Set<UUID> {
        guard let userId = SupabaseManager.shared.currentUserID else { return [] }
        struct Row: Decodable { let organizer_id: UUID }
        let rows: [Row] = try await client
            .from("organizer_favorites")
            .select("organizer_id")
            .eq("client_id", value: userId)
            .execute()
            .value
        return Set(rows.map { $0.organizer_id })
    }

    func fetchMyFavoriteOrganizers() async throws -> [Profile] {
        guard let userId = SupabaseManager.shared.currentUserID else { return [] }
        struct FavRow: Decodable {
            let organizer_id: UUID
            let created_at: Date
        }
        let favs: [FavRow] = try await client
            .from("organizer_favorites")
            .select("organizer_id, created_at")
            .eq("client_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
        guard !favs.isEmpty else { return [] }

        let ids = favs.map { $0.organizer_id.uuidString }
        let profiles: [Profile] = try await client
            .from("profiles")
            .select()
            .in("id", values: ids)
            .execute()
            .value
        let order = Dictionary(uniqueKeysWithValues: favs.enumerated().map { ($0.element.organizer_id, $0.offset) })
        return profiles.sorted { (order[$0.id] ?? Int.max) < (order[$1.id] ?? Int.max) }
    }

    func add(organizerId: UUID) async throws {
        guard let userId = SupabaseManager.shared.currentUserID else { return }
        struct Row: Encodable {
            let client_id: UUID
            let organizer_id: UUID
        }
        try await client
            .from("organizer_favorites")
            .upsert(Row(client_id: userId, organizer_id: organizerId))
            .execute()
    }

    func remove(organizerId: UUID) async throws {
        guard let userId = SupabaseManager.shared.currentUserID else { return }
        try await client
            .from("organizer_favorites")
            .delete()
            .eq("client_id", value: userId)
            .eq("organizer_id", value: organizerId)
            .execute()
    }

    func isFavorite(organizerId: UUID) async throws -> Bool {
        guard let userId = SupabaseManager.shared.currentUserID else { return false }
        struct Row: Decodable { let organizer_id: UUID }
        let rows: [Row] = try await client
            .from("organizer_favorites")
            .select("organizer_id")
            .eq("client_id", value: userId)
            .eq("organizer_id", value: organizerId)
            .limit(1)
            .execute()
            .value
        return !rows.isEmpty
    }
}
