//
//  BoardDataSource.swift
//  Brindoo
//
//  Le "prese" da cui la bacheca prende i dati.
//
//  Perché: prima il ViewModel chiamava direttamente i servizi (istanze
//  uniche fisse), quindi nei test non si poteva provare un flusso vero —
//  ogni prova avrebbe chiamato il server. Qui i servizi entrano dall'esterno:
//  in app quelli veri, nei test finti che restituiscono dati inventati.
//

import Foundation

/// Tutto ciò che la bacheca deve chiedere all'esterno, in un posto solo.
struct BoardDataSource {

    var fetchCategories: () async throws -> [ServiceCategory]

    var fetchOrganizers: (
        _ categoryIds: Set<UUID>,
        _ areaFilters: Set<String>,
        _ searchText: String?,
        _ includeCurrentUser: Bool,
        _ limit: Int,
        _ offset: Int
    ) async throws -> OrganizerService.OrganizersPage

    var fetchOrganizerCategoriesMap: (_ organizerIds: [UUID]) async throws -> [UUID: [ServiceCategory]]
    var fetchOrganizerCategories: (_ organizerID: UUID) async throws -> [ServiceCategory]

    var fetchActiveOffers: (_ organizerIds: [UUID]) async throws -> [UUID: [ServiceOffer]]
    var fetchMyOffers: () async throws -> [ServiceOffer]
    var fetchOfferCategoriesMap: (_ offerIds: [UUID]) async throws -> [UUID: [ServiceCategory]]

    var fetchRatings: (_ organizerIds: [UUID]) async throws -> [UUID: OrganizerRating]
    var fetchBusyOrganizerIds: (_ day: Date) async throws -> Set<UUID>

    var loadBlocks: () async -> Void
}

extension BoardDataSource {

    /// Le prese vere, collegate ai servizi dell'app.
    @MainActor
    static var live: BoardDataSource {
        BoardDataSource(
            fetchCategories: {
                try await CategoryService.shared.fetchCategories()
            },
            fetchOrganizers: { categoryIds, areaFilters, searchText, includeCurrentUser, limit, offset in
                try await OrganizerService.shared.fetchOrganizers(
                    categoryIds: categoryIds,
                    areaFilters: areaFilters,
                    searchText: searchText,
                    includeCurrentUser: includeCurrentUser,
                    limit: limit,
                    offset: offset
                )
            },
            fetchOrganizerCategoriesMap: { ids in
                try await OrganizerService.shared.fetchOrganizerCategoriesMap(organizerIds: ids)
            },
            fetchOrganizerCategories: { id in
                try await OrganizerService.shared.fetchOrganizerCategories(organizerID: id)
            },
            fetchActiveOffers: { ids in
                try await ServiceOfferService.shared.fetchActiveOffers(forOrganizers: ids)
            },
            fetchMyOffers: {
                try await ServiceOfferService.shared.fetchMyOffers()
            },
            fetchOfferCategoriesMap: { ids in
                try await ServiceOfferService.shared.fetchOfferCategoriesMap(offerIds: ids)
            },
            fetchRatings: { ids in
                try await ReviewService.shared.fetchRatings(organizerIds: ids)
            },
            fetchBusyOrganizerIds: { day in
                try await AvailabilityService.shared.fetchBusyOrganizerIds(on: day)
            },
            loadBlocks: {
                await BlockService.shared.loadBlocks()
            }
        )
    }

    /// Prese "vuote": non chiamano nulla. Base comoda per i test, che
    /// sostituiscono solo le due o tre che gli servono davvero.
    static var empty: BoardDataSource {
        BoardDataSource(
            fetchCategories: { [] },
            fetchOrganizers: { _, _, _, _, _, _ in .init(profiles: [], hasMore: false) },
            fetchOrganizerCategoriesMap: { _ in [:] },
            fetchOrganizerCategories: { _ in [] },
            fetchActiveOffers: { _ in [:] },
            fetchMyOffers: { [] },
            fetchOfferCategoriesMap: { _ in [:] },
            fetchRatings: { _ in [:] },
            fetchBusyOrganizerIds: { _ in [] },
            loadBlocks: {}
        )
    }
}
