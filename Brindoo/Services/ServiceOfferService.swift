//
//  ServiceOfferService.swift
//  Brindoo
//
//  Service per leggere/scrivere le offerte di servizio pubblicate dagli organizzatori.
//

import Foundation
import Supabase

@MainActor
final class ServiceOfferService {

    static let shared = ServiceOfferService()
    private init() {}

    private var client: SupabaseClient {
        SupabaseManager.shared.client
    }

    // MARK: - Fetch lista (Esplora pubblica, lato cliente)

    /// Offerte attive di tutti gli organizzatori.
    /// Quando `categoryFilters` è non vuoto, restituisce solo le offerte che hanno
    /// almeno una delle categorie selezionate (OR logico).
    /// Se `excludeDismissed` è true (default), nasconde le offerte che l'utente ha
    /// scartato manualmente dalla lista.
    func fetchActiveOffers(
        categoryFilters: Set<UUID> = [],
        searchText: String? = nil,
        excludeDismissed: Bool = true
    ) async throws -> [ServiceOffer] {
        var query = client
            .from("service_offers")
            .select()
            .eq("status", value: "active")

        if let searchText, !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            query = query.ilike("title", pattern: "%\(searchText)%")
        }

        var offers: [ServiceOffer] = try await query
            .order("created_at", ascending: false)
            .limit(100)
            .execute()
            .value

        if !categoryFilters.isEmpty {
            let ids = try await fetchOfferIds(forCategories: categoryFilters)
            offers = offers.filter { ids.contains($0.id) }
        }

        if excludeDismissed {
            let dismissed = (try? await OfferDismissalService.shared.fetchMyDismissedIds()) ?? []
            if !dismissed.isEmpty {
                offers = offers.filter { !dismissed.contains($0.id) }
            }
        }

        // Escludi gli organizzatori attualmente in vacanza.
        if !offers.isEmpty {
            let organizerIds = Set(offers.map { $0.organizerId })
            let vacationing = try await fetchVacationingOrganizers(in: organizerIds)
            if !vacationing.isEmpty {
                offers = offers.filter { !vacationing.contains($0.organizerId) }
            }
        }

        // Ordina ereditando boost/pro dell'organizzatore.
        if !offers.isEmpty {
            let organizerIds = Set(offers.map { $0.organizerId })
            let rank = try await fetchOrganizerRanking(in: organizerIds)
            offers.sort { a, b in
                let ra = rank[a.organizerId] ?? .default
                let rb = rank[b.organizerId] ?? .default
                if ra.isBoosted != rb.isBoosted { return ra.isBoosted }
                if ra.isPro != rb.isPro { return ra.isPro }
                return a.createdAt > b.createdAt
            }
        }

        return offers
    }

    /// Stato Boost / Pro degli organizzatori dati. Usato per ordinare.
    private struct OrganizerRank {
        let isBoosted: Bool
        let isPro: Bool
        static let `default` = OrganizerRank(isBoosted: false, isPro: false)
    }

    private func fetchOrganizerRanking(in ids: Set<UUID>) async throws -> [UUID: OrganizerRank] {
        guard !ids.isEmpty else { return [:] }
        struct Row: Decodable {
            let id: UUID
            let is_pro: Bool?
            let boost_expires_at: Date?
        }
        let rows: [Row] = try await client
            .from("profiles")
            .select("id, is_pro, boost_expires_at")
            .in("id", values: ids.map { $0.uuidString })
            .execute()
            .value

        let now = Date()
        var out: [UUID: OrganizerRank] = [:]
        for r in rows {
            let boosted = (r.boost_expires_at ?? .distantPast) > now
            out[r.id] = OrganizerRank(isBoosted: boosted, isPro: r.is_pro ?? false)
        }
        return out
    }

    /// ID degli organizzatori con `vacation_until >= oggi`.
    private func fetchVacationingOrganizers(in ids: Set<UUID>) async throws -> Set<UUID> {
        guard !ids.isEmpty else { return [] }
        struct Row: Decodable { let id: UUID }

        let todayStr: String = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.timeZone = TimeZone(identifier: "UTC")
            return f.string(from: Date())
        }()

        let rows: [Row] = try await client
            .from("profiles")
            .select("id")
            .in("id", values: ids.map { $0.uuidString })
            .gte("vacation_until", value: todayStr)
            .execute()
            .value
        return Set(rows.map { $0.id })
    }

    private func fetchOfferIds(forCategories categoryIds: Set<UUID>) async throws -> Set<UUID> {
        struct Row: Decodable { let offer_id: UUID }
        let idStrings = categoryIds.map { $0.uuidString }
        let rows: [Row] = try await client
            .from("service_offer_categories")
            .select("offer_id")
            .in("category_id", values: idStrings)
            .execute()
            .value
        return Set(rows.map { $0.offer_id })
    }

    /// Offerte attive raggruppate per organizzatore, per i professionisti nella lista bacheca.
    /// Restituisce `[organizerId: [ServiceOffer]]` ordinato per `created_at` desc.
    /// Le aree di copertura si filtrano a livello profilo (`profiles.coverage_areas`),
    /// non più sulla singola offerta.
    func fetchActiveOffers(forOrganizers organizerIds: [UUID]) async throws -> [UUID: [ServiceOffer]] {
        guard !organizerIds.isEmpty else { return [:] }

        let offers: [ServiceOffer] = try await client
            .from("service_offers")
            .select()
            .in("organizer_id", values: organizerIds.map { $0.uuidString })
            .eq("status", value: "active")
            .order("created_at", ascending: false)
            .execute()
            .value

        return Dictionary(grouping: offers, by: { $0.organizerId })
    }

    // MARK: - Singola offerta

    func fetchOffer(id: UUID) async throws -> ServiceOffer? {
        let result: [ServiceOffer] = try await client
            .from("service_offers")
            .select()
            .eq("id", value: id)
            .limit(1)
            .execute()
            .value
        return result.first
    }

    // MARK: - Categorie di un'offerta

    func fetchOfferCategories(offerId: UUID) async throws -> [ServiceCategory] {
        struct Row: Decodable {
            let service_categories: ServiceCategory
        }

        let rows: [Row] = try await client
            .from("service_offer_categories")
            .select("service_categories(*)")
            .eq("offer_id", value: offerId)
            .execute()
            .value

        return rows.map { $0.service_categories }
    }

    // MARK: - Le mie offerte (lato organizzatore)

    func fetchMyOffers() async throws -> [ServiceOffer] {
        guard let userId = SupabaseManager.shared.currentUserID else { return [] }

        return try await client
            .from("service_offers")
            .select()
            .eq("organizer_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    // MARK: - Creazione

    func createOffer(
        title: String,
        description: String,
        coverageArea: String,
        price: Double,
        categoryIds: [UUID],
        imageUrl: String? = nil
    ) async throws -> ServiceOffer {
        guard let userId = SupabaseManager.shared.currentUserID else {
            throw NSError(domain: "ServiceOffer", code: 401)
        }

        // Limite free: 1 offerta attiva. Se l'organizzatore non è Pro e ne ha già
        // almeno una "active", solleva l'errore tipizzato `BrindooLimitError.maxOffersReached`
        // così la UI può mostrare la paywall.
        let profile = try await ProfileService.shared.fetchProfile(userID: userId)
        let isPro = profile?.isPro ?? false
        if !isPro {
            struct C: Decodable { let id: UUID }
            let active: [C] = try await client
                .from("service_offers")
                .select("id")
                .eq("organizer_id", value: userId)
                .eq("status", value: "active")
                .limit(1)
                .execute()
                .value
            if !active.isEmpty {
                throw BrindooLimitError.maxOffersReached
            }
        }

        struct Payload: Encodable {
            let organizer_id: UUID
            let title: String
            let description: String
            let coverage_area: String
            let price: Double
            let status: String
            let image_url: String?
        }

        let payload = Payload(
            organizer_id: userId,
            title: title,
            description: description,
            coverage_area: coverageArea,
            price: price,
            status: "active",
            image_url: imageUrl
        )

        let created: ServiceOffer = try await client
            .from("service_offers")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        if !categoryIds.isEmpty {
            struct Join: Encodable {
                let offer_id: UUID
                let category_id: UUID
            }
            let joins = categoryIds.map { Join(offer_id: created.id, category_id: $0) }
            try await client
                .from("service_offer_categories")
                .insert(joins)
                .execute()
        }

        return created
    }

    // MARK: - Update status (attiva / metti in pausa)

    func updateStatus(offerId: UUID, status: ServiceOfferStatus) async throws {
        struct U: Encodable { let status: String }
        try await client
            .from("service_offers")
            .update(U(status: status.rawValue))
            .eq("id", value: offerId)
            .execute()
    }

    // MARK: - Delete

    func deleteOffer(offerId: UUID) async throws {
        try await client
            .from("service_offers")
            .delete()
            .eq("id", value: offerId)
            .execute()
    }
}
