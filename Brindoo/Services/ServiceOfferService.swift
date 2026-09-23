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
        // Ordine (Boost > Pro > recenti), vacanza e categoria li decide il
        // database PRIMA di tagliare la pagina a 100: prima si ordinava e si
        // filtrava a valle, e con più offerte quelle dei Pro più vecchie o
        // della categoria cercata restavano fuori.
        var query = client
            .from("service_offers_ranked")
            .select()
            .eq("status", value: "active")
            .eq("organizer_on_vacation", value: false)

        if let searchText, !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            query = query.ilike("title", pattern: "%\(searchText)%")
        }

        // Con troppe corrispondenze il filtro `in` renderebbe l'URL enorme:
        // in quel caso si torna al filtro a valle (caso raro).
        var localCategoryIds: Set<UUID>?
        if !categoryFilters.isEmpty {
            let ids = try await fetchOfferIds(forCategories: categoryFilters)
            if ids.isEmpty { return [] }
            if ids.count <= 150 {
                query = query.in("id", values: ids.map { $0.uuidString })
            } else {
                localCategoryIds = ids
            }
        }

        var offers: [ServiceOffer] = try await query
            .order("boost_active", ascending: false)
            .order("pro_active", ascending: false)
            .order("created_at", ascending: false)
            .limit(100)
            .execute()
            .value

        if let localCategoryIds {
            offers = offers.filter { localCategoryIds.contains($0.id) }
        }

        if excludeDismissed {
            let dismissed = (try? await OfferDismissalService.shared.fetchMyDismissedIds()) ?? []
            if !dismissed.isEmpty {
                offers = offers.filter { !dismissed.contains($0.id) }
            }
        }

        return offers
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

        // Chi è in vacanza tiene il profilo ma non mostra offerte, come
        // promette la modalità vacanza.
        let offers: [ServiceOffer] = try await client
            .from("service_offers_ranked")
            .select()
            .in("organizer_id", values: organizerIds.map { $0.uuidString })
            .eq("status", value: "active")
            .eq("organizer_on_vacation", value: false)
            .order("created_at", ascending: false)
            .execute()
            .value

        return Dictionary(grouping: offers, by: { $0.organizerId })
    }

    // MARK: - Offerte recenti dei preferiti

    /// Offerte attive pubblicate di recente dagli organizzatori indicati
    /// (sezione "Novità dai tuoi preferiti" in Attività).
    func fetchRecentOffers(
        fromOrganizers organizerIds: [UUID],
        since: Date,
        limit: Int = 10
    ) async throws -> [ServiceOffer] {
        guard !organizerIds.isEmpty else { return [] }
        let iso = BrindooFormat.iso(since)
        return try await client
            .from("service_offers")
            .select()
            .in("organizer_id", values: organizerIds.map { $0.uuidString })
            .eq("status", value: "active")
            .gte("created_at", value: iso)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
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

    /// Più offerte per id, in un'unica richiesta.
    func fetchOffers(ids: [UUID]) async throws -> [ServiceOffer] {
        guard !ids.isEmpty else { return [] }
        return try await client
            .from("service_offers")
            .select()
            .in("id", values: ids.map { $0.uuidString })
            .execute()
            .value
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

    /// Categorie di più offerte in un'unica richiesta (una sola query
    /// invece di una per offerta).
    func fetchOfferCategoriesMap(offerIds: [UUID]) async throws -> [UUID: [ServiceCategory]] {
        guard !offerIds.isEmpty else { return [:] }
        struct Row: Decodable {
            let offer_id: UUID
            let service_categories: ServiceCategory
        }
        let rows: [Row] = try await client
            .from("service_offer_categories")
            .select("offer_id, service_categories(*)")
            .in("offer_id", values: offerIds.map { $0.uuidString })
            .execute()
            .value
        return Dictionary(grouping: rows, by: { $0.offer_id })
            .mapValues { $0.map(\.service_categories) }
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
            throw BrindooServiceError.notLoggedIn
        }

        // Limite free: 1 offerta attiva. Se l'organizzatore non è Pro e ne ha già
        // almeno una "active", solleva l'errore tipizzato `BrindooLimitError.maxOffersReached`
        // così la UI può mostrare la paywall.
        // Prima si conta, poi semmai si guarda l'abbonamento: chi non ha ancora
        // un'offerta attiva pubblica senza il viaggio in piu' verso il profilo.
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
            let profile = try await ProfileService.shared.fetchProfile(userID: userId)
            if profile?.isPro != true {
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

        let created: ServiceOffer
        do {
            // Lo stesso tetto vive in un trigger del database: se a rifiutare e'
            // lui, la view deve vedere l'errore tipizzato, non uno generico.
            created = try await client
                .from("service_offers")
                .insert(payload)
                .select()
                .single()
                .execute()
                .value
        } catch {
            throw BrindooLimitError.mapping(error)
        }

        if !categoryIds.isEmpty {
            struct Join: Encodable {
                let offer_id: UUID
                let category_id: UUID
            }
            let joins = categoryIds.map { Join(offer_id: created.id, category_id: $0) }
            do {
                try await client
                    .from("service_offer_categories")
                    .insert(joins)
                    .execute()
            } catch {
                // Tutto o niente: un'offerta senza categorie non si trova in
                // bacheca e, per chi è al piano gratuito, occupava l'unico
                // posto facendo scattare la paywall al secondo tentativo.
                try? await deleteOffer(offerId: created.id)
                throw error
            }
        }

        return created
    }

    // MARK: - Update status (attiva / metti in pausa)

    func updateStatus(offerId: UUID, status: ServiceOfferStatus) async throws {
        struct U: Encodable { let status: String }
        do {
            // Riattivare e' pubblicare: il trigger del limite scatta anche qui.
            try await client
                .from("service_offers")
                .update(U(status: status.rawValue))
                .eq("id", value: offerId)
                .execute()
        } catch {
            throw BrindooLimitError.mapping(error)
        }
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
