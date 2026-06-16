//
//  OfferFavoriteService.swift
//  Brindoo
//
//  Preferiti delle offerte lato cliente. Tabella `offer_favorites`.
//

import Foundation
import Supabase

@MainActor
final class OfferFavoriteService {

    static let shared = OfferFavoriteService()
    private init() {}

    private var client: SupabaseClient { SupabaseManager.shared.client }

    /// ID di tutte le offerte salvate dal cliente corrente.
    func fetchMyFavoriteIds() async throws -> Set<UUID> {
        guard let userId = SupabaseManager.shared.currentUserID else { return [] }
        struct Row: Decodable { let offer_id: UUID }
        let rows: [Row] = try await client
            .from("offer_favorites")
            .select("offer_id")
            .eq("client_id", value: userId)
            .execute()
            .value
        return Set(rows.map { $0.offer_id })
    }

    /// Offerte salvate complete, ordinate per data di salvataggio decrescente.
    func fetchMyFavorites() async throws -> [ServiceOffer] {
        guard let userId = SupabaseManager.shared.currentUserID else { return [] }
        struct FavRow: Decodable {
            let offer_id: UUID
            let created_at: Date
        }
        let favs: [FavRow] = try await client
            .from("offer_favorites")
            .select("offer_id, created_at")
            .eq("client_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
        guard !favs.isEmpty else { return [] }

        let ids = favs.map { $0.offer_id.uuidString }
        let offers: [ServiceOffer] = try await client
            .from("service_offers")
            .select()
            .in("id", values: ids)
            .execute()
            .value
        // Mantieni l'ordine dei preferiti.
        let order = Dictionary(uniqueKeysWithValues: favs.enumerated().map { ($0.element.offer_id, $0.offset) })
        return offers.sorted { (order[$0.id] ?? Int.max) < (order[$1.id] ?? Int.max) }
    }

    func add(offerId: UUID) async throws {
        guard let userId = SupabaseManager.shared.currentUserID else { return }
        struct Row: Encodable {
            let client_id: UUID
            let offer_id: UUID
        }
        try await client
            .from("offer_favorites")
            .upsert(Row(client_id: userId, offer_id: offerId))
            .execute()
    }

    func remove(offerId: UUID) async throws {
        guard let userId = SupabaseManager.shared.currentUserID else { return }
        try await client
            .from("offer_favorites")
            .delete()
            .eq("client_id", value: userId)
            .eq("offer_id", value: offerId)
            .execute()
    }

    func isFavorite(offerId: UUID) async throws -> Bool {
        guard let userId = SupabaseManager.shared.currentUserID else { return false }
        struct Row: Decodable { let offer_id: UUID }
        let rows: [Row] = try await client
            .from("offer_favorites")
            .select("offer_id")
            .eq("client_id", value: userId)
            .eq("offer_id", value: offerId)
            .limit(1)
            .execute()
            .value
        return !rows.isEmpty
    }
}
