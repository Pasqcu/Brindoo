//
//  BoardViewModelTests.swift
//  BrindooTests
//
//  Prove sul flusso vero della bacheca (caricamento a pagine, filtri,
//  vie d'uscita, ricerche salvate), possibili ora che i servizi entrano
//  dall'esterno e si possono sostituire con finti.
//

import XCTest
@testable import Brindoo

@MainActor
final class BoardViewModelTests: XCTestCase {

    // MARK: - Aiutanti

    private func makeProfile(
        id: UUID = UUID(),
        name: String = "Mario",
        createdAt: String = "2026-01-01T10:00:00Z"
    ) throws -> Profile {
        let json: [String: Any] = [
            "id": id.uuidString,
            "role": "organizer",
            "full_name": name,
            "created_at": createdAt,
            "updated_at": createdAt
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Profile.self, from: data)
    }

    private func makeCategory(name: String = "Musica", slug: String = "music") -> ServiceCategory {
        ServiceCategory(
            id: UUID(),
            slug: slug,
            name: name,
            icon: "music.note",
            description: nil,
            sortOrder: 1,
            isActive: true,
            createdAt: Date()
        )
    }

    // MARK: - Caricamento a pagine

    func test_loadOrganizers_riempieLaPrimaPagina() async throws {
        let profiles = try (0..<3).map { try makeProfile(name: "Prof \($0)") }
        var data = BoardDataSource.empty
        data.fetchOrganizers = { _, _, _, _, _, _ in
            .init(profiles: profiles, hasMore: false)
        }

        let vm = BoardViewModel(data: data)
        vm.configure(isClient: true, clientPreview: true, userID: nil, province: nil, onToast: { _ in })
        await vm.loadOrganizers()

        XCTAssertEqual(vm.organizers.count, 3)
        XCTAssertFalse(vm.canLoadMore)
        XCTAssertNil(vm.errorMessage)
    }

    func test_loadMore_nonDuplicaProfiliGiaPresenti() async throws {
        let shared = try makeProfile(name: "Ripetuto")
        let fresh = try makeProfile(name: "Nuovo")

        var callCount = 0
        var data = BoardDataSource.empty
        data.fetchOrganizers = { _, _, _, _, _, _ in
            callCount += 1
            // La seconda pagina rimanda anche un profilo già visto.
            return callCount == 1
                ? .init(profiles: [shared], hasMore: true)
                : .init(profiles: [shared, fresh], hasMore: false)
        }

        let vm = BoardViewModel(data: data)
        vm.configure(isClient: true, clientPreview: true, userID: nil, province: nil, onToast: { _ in })
        await vm.loadOrganizers()
        await vm.loadMoreOrganizers()

        XCTAssertEqual(vm.organizers.count, 2)
        XCTAssertEqual(vm.organizers.filter { $0.id == shared.id }.count, 1)
    }

    func test_erroreDiRete_mostraMessaggioSoloSeListaVuota() async throws {
        struct Boom: Error {}
        var data = BoardDataSource.empty
        data.fetchOrganizers = { _, _, _, _, _, _ in throw Boom() }

        let vm = BoardViewModel(data: data)
        vm.configure(isClient: true, clientPreview: true, userID: nil, province: nil, onToast: { _ in })
        await vm.loadOrganizers()

        XCTAssertEqual(vm.errorMessage, "Impossibile caricare i professionisti")
    }

    // MARK: - Filtro data

    func test_filtroData_escludeChiEOccupato() async throws {
        let libero = try makeProfile(name: "Libero")
        let occupato = try makeProfile(name: "Occupato")

        var data = BoardDataSource.empty
        data.fetchOrganizers = { _, _, _, _, _, _ in
            .init(profiles: [libero, occupato], hasMore: false)
        }
        data.fetchBusyOrganizerIds = { _ in [occupato.id] }

        let vm = BoardViewModel(data: data)
        vm.configure(isClient: true, clientPreview: true, userID: nil, province: nil, onToast: { _ in })
        vm.eventDate = Date()
        await vm.loadOrganizers()

        XCTAssertEqual(vm.organizers.map(\.id), [libero.id])
    }

    // MARK: - Vie d'uscita a ricerca vuota

    func test_suggerimenti_seguonoIFiltriAttivi() {
        let vm = BoardViewModel(data: .empty)
        XCTAssertTrue(vm.noResultSuggestions.isEmpty)

        vm.selectedAreaSlugs = ["prov_rm"]
        vm.searchText = "dj"
        vm.minRating = 4

        let kinds = vm.noResultSuggestions.map(\.kind)
        XCTAssertEqual(kinds, [.wholeLazio, .clearRating, .clearSearch])
    }

    func test_applicaSuggerimento_allentaIlFiltroGiusto() async {
        var data = BoardDataSource.empty
        data.fetchOrganizers = { _, _, _, _, _, _ in .init(profiles: [], hasMore: false) }

        let vm = BoardViewModel(data: data)
        vm.selectedAreaSlugs = ["prov_lt"]
        vm.minRating = 3

        await vm.apply(.init(kind: .wholeLazio, label: "", icon: ""))

        XCTAssertTrue(vm.selectedAreaSlugs.isEmpty)
        XCTAssertEqual(vm.minRating, 3, "Gli altri filtri non vanno toccati")
    }

    // MARK: - Ordinamento e filtri extra

    func test_ordinamentoPerNome() async throws {
        let zeta = try makeProfile(name: "Zeta")
        let alfa = try makeProfile(name: "Alfa")

        var data = BoardDataSource.empty
        data.fetchOrganizers = { _, _, _, _, _, _ in .init(profiles: [zeta, alfa], hasMore: false) }

        let vm = BoardViewModel(data: data)
        vm.configure(isClient: true, clientPreview: true, userID: nil, province: nil, onToast: { _ in })
        await vm.loadOrganizers()
        vm.sortMode = .nameAsc

        XCTAssertEqual(vm.sortedOrganizers.map(\.fullName), ["Alfa", "Zeta"])
    }

    // MARK: - Ricerche salvate

    func test_filtriDiAdesso_diventanoRicercaSalvabile() {
        let vm = BoardViewModel(data: .empty)
        XCTAssertNil(vm.currentFiltersAsSavedSearch, "Senza filtri non c'è niente da salvare")

        vm.searchText = "fotografo"
        vm.maxPrice = 500

        let search = vm.currentFiltersAsSavedSearch
        XCTAssertEqual(search?.searchText, "fotografo")
        XCTAssertEqual(search?.maxPrice, 500)
    }

    func test_riapreRicercaSalvata() async {
        var data = BoardDataSource.empty
        data.fetchOrganizers = { _, _, _, _, _, _ in .init(profiles: [], hasMore: false) }

        let vm = BoardViewModel(data: data)
        vm.eventDate = Date()

        let categoryId = UUID()
        await vm.applySavedSearch(SavedSearch(
            name: "DJ a Latina",
            categoryIds: [categoryId],
            areaSlugs: ["prov_lt"],
            searchText: "dj",
            minRating: 4,
            maxPrice: 800
        ))

        XCTAssertEqual(vm.selectedCategoryIds, [categoryId])
        XCTAssertEqual(vm.selectedAreaSlugs, ["prov_lt"])
        XCTAssertEqual(vm.searchText, "dj")
        XCTAssertEqual(vm.minRating, 4)
        XCTAssertNil(vm.eventDate, "Riaprire una ricerca salvata azzera la data evento")
    }

    // MARK: - Categorie

    func test_categorieCaricateAlPrimoAvvio() async {
        var data = BoardDataSource.empty
        let categories = [makeCategory(name: "Musica"), makeCategory(name: "Catering", slug: "catering")]
        data.fetchCategories = { categories }

        let vm = BoardViewModel(data: data)
        vm.configure(isClient: true, clientPreview: true, userID: nil, province: nil, onToast: { _ in })
        await vm.loadInitial()

        XCTAssertEqual(vm.categories.map(\.name), ["Musica", "Catering"])
        XCTAssertFalse(vm.isLoading)
    }
}
