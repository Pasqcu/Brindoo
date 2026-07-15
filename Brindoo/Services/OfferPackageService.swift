//
//  OfferPackageService.swift
//  Brindoo
//
//  Lettura e scrittura dei pacchetti prezzo delle offerte.
//

import Foundation
import Supabase

@MainActor
final class OfferPackageService {

    static let shared = OfferPackageService()
    private init() {}

    private var client: SupabaseClient {
        SupabaseManager.shared.client
    }

    /// Pacchetti di un'offerta, in ordine di prezzo crescente (sort_order).
    func fetchPackages(offerId: UUID) async throws -> [OfferPackage] {
        try await client
            .from("service_offer_packages")
            .select()
            .eq("offer_id", value: offerId)
            .order("sort_order", ascending: true)
            .execute()
            .value
    }

    /// Salva i pacchetti di un'offerta appena creata.
    func savePackages(
        offerId: UUID,
        packages: [(name: String, description: String?, price: Double)]
    ) async throws {
        guard !packages.isEmpty else { return }

        struct Insert: Encodable {
            let offer_id: UUID
            let name: String
            let description: String?
            let price: Double
            let sort_order: Int
        }

        let rows = packages.enumerated().map { index, p in
            Insert(
                offer_id: offerId,
                name: p.name,
                description: p.description,
                price: p.price,
                sort_order: index
            )
        }

        try await client
            .from("service_offer_packages")
            .insert(rows)
            .execute()
    }
}
