//
//  OfferDismissalService.swift
//  Brindoo
//
//  Gestisce le offerte "nascoste" dalla lista da un cliente.
//

import Foundation
import Supabase

@MainActor
final class OfferDismissalService {

    static let shared = OfferDismissalService()
    private init() {}

    private var client: SupabaseClient {
        SupabaseManager.shared.client
    }

    /// ID di tutte le offerte che il cliente corrente ha scartato.
    func fetchMyDismissedIds() async throws -> Set<UUID> {
        guard let userId = SupabaseManager.shared.currentUserID else { return [] }

        struct Row: Decodable { let offer_id: UUID }
        let rows: [Row] = try await client
            .from("offer_dismissals")
            .select("offer_id")
            .eq("client_id", value: userId)
            .execute()
            .value
        return Set(rows.map { $0.offer_id })
    }

    func dismiss(offerId: UUID) async throws {
        guard let userId = SupabaseManager.shared.currentUserID else { return }
        struct Row: Encodable {
            let client_id: UUID
            let offer_id: UUID
        }
        try await client
            .from("offer_dismissals")
            .upsert(Row(client_id: userId, offer_id: offerId))
            .execute()
    }

    func undismiss(offerId: UUID) async throws {
        guard let userId = SupabaseManager.shared.currentUserID else { return }
        try await client
            .from("offer_dismissals")
            .delete()
            .eq("client_id", value: userId)
            .eq("offer_id", value: offerId)
            .execute()
    }
}
