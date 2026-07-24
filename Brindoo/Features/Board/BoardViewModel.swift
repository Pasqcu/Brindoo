//
//  BoardViewModel.swift
//  Brindoo
//
//  Parte "dati" della bacheca: caricamenti a pagine, filtri, cache
//  per l'apertura istantanea. BoardView resta solo interfaccia.
//

import Foundation
import Observation

enum BoardSortMode: String, CaseIterable, Identifiable {
    case recommended, recent, nameAsc
    var id: String { rawValue }
    var label: String {
        switch self {
        case .recommended: return "Consigliati"
        case .recent:      return "Più recenti"
        case .nameAsc:     return "Nome (A-Z)"
        }
    }
}

/// Ultima lista mostrata in bacheca, salvata su disco per l'apertura istantanea.
struct BoardSnapshot: Codable {
    let organizers: [Profile]
    let offers: [UUID: [ServiceOffer]]
    let categories: [UUID: [ServiceCategory]]
    let ratings: [UUID: OrganizerRating]
    let areaSlugs: Set<String>
    let savedAt: Date
}

@MainActor
@Observable
final class BoardViewModel {

    /// Da dove arrivano i dati. In app le prese vere, nei test finte.
    private let data: BoardDataSource

    /// Senza argomenti usa le prese vere; i test passano le loro.
    init(data: BoardDataSource? = nil) {
        self.data = data ?? .live
    }

    // Contesto (impostato dalla vista prima del primo caricamento)
    private(set) var isClient: Bool = false
    private(set) var clientPreview: Bool = false
    private var userID: UUID?
    private var province: LazioProvince?
    private var onToast: ((BrindooToast) -> Void)?

    // Stato condiviso
    var categories: [ServiceCategory] = []
    var selectedCategoryIds: Set<UUID> = []
    var selectedAreaSlugs: Set<String> = []
    var searchText: String = ""
    private(set) var lastSearchedText: String = ""
    private(set) var isLoading: Bool = true
    private(set) var errorMessage: String?

    // Cliente: professionisti con offerte annidate, caricati a pagine
    private(set) var organizers: [Profile] = []
    private(set) var organizerCategoriesMap: [UUID: [ServiceCategory]] = [:]
    private(set) var organizerOffersMap: [UUID: [ServiceOffer]] = [:]
    private(set) var canLoadMore: Bool = false
    private var isLoadingMore: Bool = false
    private(set) var pageOffset: Int = 0
    private let pageSize = 20

    // Organizer: proprie offerte
    private(set) var myOffers: [ServiceOffer] = []
    private(set) var myOfferCategoriesMap: [UUID: [ServiceCategory]] = [:]
    private(set) var hasOrganizerCategories: Bool = true

    // Ordinamento e filtri extra
    var sortMode: BoardSortMode = .recommended
    private(set) var organizerRatings: [UUID: OrganizerRating] = [:]
    var minRating: Int = 0      // 0 = qualsiasi
    var maxPrice: Double = 0    // 0 = nessun limite
    var eventDate: Date? = nil  // nil = qualsiasi giorno

    // MARK: - Stato derivato

    var hasExtraFilters: Bool { minRating > 0 || maxPrice > 0 || eventDate != nil }

    var hasActiveFilters: Bool {
        !selectedCategoryIds.isEmpty || !selectedAreaSlugs.isEmpty || !searchText.isEmpty || eventDate != nil
    }

    /// Filtri "di contenuto" (categoria/ricerca): l'area provincia non conta,
    /// così la vetrina e l'intestazione restano visibili anche con una provincia scelta.
    var hasContentFilters: Bool {
        !selectedCategoryIds.isEmpty || !searchText.isEmpty
    }

    var boostedOrganizers: [Profile] {
        organizers.filter { $0.isBoosted }
    }

    private func minOfferPrice(for id: UUID) -> Double? {
        organizerOffersMap[id]?.map(\.price).min()
    }

    var sortedOrganizers: [Profile] {
        var list = organizers

        if minRating > 0 {
            list = list.filter { (organizerRatings[$0.id]?.avgRating ?? 0) >= Double(minRating) }
        }
        if maxPrice > 0 {
            list = list.filter {
                if let p = minOfferPrice(for: $0.id) { return p <= maxPrice }
                return false
            }
        }

        switch sortMode {
        case .recommended: return list
        case .recent:      return list.sorted { $0.createdAt > $1.createdAt }
        case .nameAsc:     return list.sorted { ($0.fullName ?? "").localizedCaseInsensitiveCompare($1.fullName ?? "") == .orderedAscending }
        }
    }

    // MARK: - Configurazione

    func configure(
        isClient: Bool,
        clientPreview: Bool,
        userID: UUID?,
        province: LazioProvince?,
        onToast: @escaping (BrindooToast) -> Void
    ) {
        self.isClient = isClient
        self.clientPreview = clientPreview
        self.userID = userID
        self.province = province
        self.onToast = onToast
    }

    // MARK: - Ricerche salvate

    /// I filtri di adesso confezionati come ricerca salvabile.
    /// `nil` quando non c'è nulla di specifico da mettere da parte.
    var currentFiltersAsSavedSearch: SavedSearch? {
        guard hasActiveFilters || minRating > 0 || maxPrice > 0 else { return nil }
        return SavedSearch(
            name: "",
            categoryIds: Array(selectedCategoryIds),
            areaSlugs: Array(selectedAreaSlugs),
            searchText: searchText,
            minRating: minRating,
            maxPrice: maxPrice
        )
    }

    /// Riapre una ricerca salvata in bacheca.
    func applySavedSearch(_ search: SavedSearch) async {
        selectedCategoryIds = Set(search.categoryIds)
        selectedAreaSlugs = Set(search.areaSlugs)
        searchText = search.searchText
        minRating = search.minRating
        maxPrice = search.maxPrice
        eventDate = nil
        await loadOrganizers()
    }

    // MARK: - Vie d'uscita quando non esce nulla

    /// Suggerimento in un colpo solo per allargare una ricerca a vuoto.
    struct Suggestion: Identifiable, Equatable {
        enum Kind: String { case wholeLazio, clearDate, clearCategories, clearRating, clearPrice, clearSearch }
        let kind: Kind
        let label: String
        let icon: String
        var id: String { kind.rawValue }
    }

    /// Cosa proporre, in ordine di "quanto allarga", in base ai filtri attivi.
    /// Vuoto = non c'è più niente da allentare.
    var noResultSuggestions: [Suggestion] {
        var out: [Suggestion] = []
        if !selectedAreaSlugs.isEmpty {
            out.append(.init(kind: .wholeLazio, label: "Cerca in tutto il Lazio", icon: "map"))
        }
        if eventDate != nil {
            out.append(.init(kind: .clearDate, label: "Togli il filtro data", icon: "calendar.badge.minus"))
        }
        if minRating > 0 {
            out.append(.init(kind: .clearRating, label: "Accetta anche meno stelle", icon: "star"))
        }
        if maxPrice > 0 {
            out.append(.init(kind: .clearPrice, label: "Togli il tetto di prezzo", icon: "eurosign.circle"))
        }
        if !selectedCategoryIds.isEmpty {
            out.append(.init(kind: .clearCategories, label: "Togli le categorie scelte", icon: "square.grid.2x2"))
        }
        if !searchText.isEmpty {
            out.append(.init(kind: .clearSearch, label: "Svuota la ricerca «\(searchText)»", icon: "magnifyingglass"))
        }
        return out
    }

    /// Applica un suggerimento e ricarica.
    func apply(_ suggestion: Suggestion) async {
        switch suggestion.kind {
        case .wholeLazio:      selectedAreaSlugs.removeAll()
        case .clearDate:       eventDate = nil
        case .clearCategories: selectedCategoryIds.removeAll()
        case .clearRating:     minRating = 0
        case .clearPrice:      maxPrice = 0
        case .clearSearch:     searchText = ""
        }
        await loadOrganizers()
    }

    /// Azzeramento completo di tutti i filtri (contenuto + extra).
    func clearAllFilters() {
        selectedCategoryIds.removeAll()
        selectedAreaSlugs.removeAll()
        searchText = ""
        eventDate = nil
        minRating = 0
        maxPrice = 0
        Task { await loadOrganizers() }
    }

    private func provinceSlug(_ p: LazioProvince) -> String { "prov_\(p.rawValue.lowercased())" }

    // MARK: - Caricamento

    func loadInitial() async {
        isLoading = true
        do {
            categories = try await data.fetchCategories()
        } catch {
            // Senza categorie i filtri restano vuoti: meglio dirlo che tacere.
            onToast?(BrindooToast("Impossibile caricare le categorie", message: "Trascina in basso per riprovare.", style: .error))
            BrindooLog.error("Errore caricamento categorie: \(error)")
        }
        await data.loadBlocks()
        await checkOrganizerCategoriesIfNeeded()

        // Parti già "vicino a casa": filtra sulla provincia dell'utente.
        if isClient && !clientPreview, selectedAreaSlugs.isEmpty, let province {
            selectedAreaSlugs = [provinceSlug(province)]
        }

        // Bacheca istantanea: mostra subito l'ultima lista salvata (se combacia
        // con i filtri iniziali), poi aggiorna comunque dalla rete.
        if isClient && !clientPreview,
           let snapshot = await LocalCacheStore.shared.load(BoardSnapshot.self, for: BrindooCacheKey.boardSnapshot),
           snapshot.areaSlugs == selectedAreaSlugs,
           !snapshot.organizers.isEmpty {
            organizers = snapshot.organizers
            organizerOffersMap = snapshot.offers
            organizerCategoriesMap = snapshot.categories
            organizerRatings = snapshot.ratings
            isLoading = false
        }

        await reload()
        isLoading = false
    }

    /// Verifica se l'organizer ha almeno una categoria. Se l'utente non è
    /// organizer o non ha mai cliccato "Diventa Professionista" non fa nulla.
    func checkOrganizerCategoriesIfNeeded() async {
        guard !isClient,
              ProfessionalOnboardingHint.isPending,
              let userID else { return }
        let cats = (try? await data.fetchOrganizerCategories(userID)) ?? []
        hasOrganizerCategories = !cats.isEmpty
        if !cats.isEmpty {
            ProfessionalOnboardingHint.clear()
        }
    }

    func reload() async {
        errorMessage = nil
        if isClient {
            await loadOrganizers()
        } else {
            await loadMyOffers()
        }
    }

    /// Una pagina di professionisti già filtrata per data evento (se attiva).
    private func fetchPage(offset: Int, busyIds: Set<UUID>) async throws -> (profiles: [Profile], hasMore: Bool) {
        let page = try await data.fetchOrganizers(
            selectedCategoryIds,
            selectedAreaSlugs,
            searchText.isEmpty ? nil : searchText,
            clientPreview,
            pageSize,
            offset
        )
        return (applyDateFilter(page.profiles, busyIds: busyIds), page.hasMore)
    }

    /// Esclude chi è occupato o in vacanza nella data evento selezionata.
    private func applyDateFilter(_ profiles: [Profile], busyIds: Set<UUID>) -> [Profile] {
        guard let eventDate else { return profiles }
        let day = Calendar.current.startOfDay(for: eventDate)
        return profiles.filter { p in
            if busyIds.contains(p.id) { return false }
            if let vacation = p.vacationUntil,
               day <= Calendar.current.startOfDay(for: vacation) {
                return false
            }
            return true
        }
    }

    private func fetchBusyIdsIfNeeded() async -> Set<UUID> {
        guard let eventDate else { return [] }
        return (try? await data.fetchBusyOrganizerIds(eventDate)) ?? []
    }

    /// Accumula pagine a partire da `startOffset` finché non trova almeno un
    /// risultato visibile o le pagine finiscono (max 5 tentativi), per non
    /// mostrare un "nessun risultato" ingannevole con il filtro data attivo.
    private func collectPages(
        from startOffset: Int,
        busyIds: Set<UUID>
    ) async throws -> (profiles: [Profile], nextOffset: Int, hasMore: Bool) {
        var collected: [Profile] = []
        var offset = startOffset
        var hasMore = true

        repeat {
            let page = try await fetchPage(offset: offset, busyIds: busyIds)
            offset += pageSize
            hasMore = page.hasMore
            collected.append(contentsOf: page.profiles)
        } while collected.isEmpty && hasMore && offset < startOffset + pageSize * 5

        return (collected, offset, hasMore)
    }

    /// Ricarica da zero la prima pagina.
    func loadOrganizers() async {
        lastSearchedText = searchText
        do {
            let busyIds = await fetchBusyIdsIfNeeded()
            let (collected, offset, hasMore) = try await collectPages(from: 0, busyIds: busyIds)

            await loadRelated(for: collected)
            organizers = collected
            pageOffset = offset
            canLoadMore = hasMore

            await saveSnapshotIfEligible()
        } catch {
            // Se abbiamo la lista dalla cache, non coprirla con la schermata d'errore.
            if organizers.isEmpty {
                errorMessage = "Impossibile caricare i professionisti"
            }
            BrindooLog.error("Errore caricamento professionisti: \(error)")
        }
    }

    /// Salva la lista corrente per l'apertura istantanea (solo la vista
    /// "di default": niente ricerca, categorie o filtri extra).
    private func saveSnapshotIfEligible() async {
        guard isClient, !clientPreview,
              searchText.isEmpty, selectedCategoryIds.isEmpty,
              minRating == 0, maxPrice == 0, eventDate == nil,
              !organizers.isEmpty else { return }

        let ids = Set(organizers.map(\.id))
        let snapshot = BoardSnapshot(
            organizers: organizers,
            offers: organizerOffersMap.filter { ids.contains($0.key) },
            categories: organizerCategoriesMap.filter { ids.contains($0.key) },
            ratings: organizerRatings.filter { ids.contains($0.key) },
            areaSlugs: selectedAreaSlugs,
            savedAt: Date()
        )
        await LocalCacheStore.shared.save(snapshot, for: BrindooCacheKey.boardSnapshot)
    }

    /// Aggiunge la pagina successiva in fondo alla lista.
    func loadMoreOrganizers() async {
        guard canLoadMore, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let busyIds = await fetchBusyIdsIfNeeded()
            let (appended, offset, hasMore) = try await collectPages(from: pageOffset, busyIds: busyIds)

            let known = Set(organizers.map(\.id))
            let fresh = appended.filter { !known.contains($0.id) }
            await loadRelated(for: fresh)
            organizers.append(contentsOf: fresh)
            pageOffset = offset
            canLoadMore = hasMore
        } catch {
            canLoadMore = false
            onToast?(BrindooToast("Impossibile caricare altri profili", message: "Trascina in basso per riprovare.", style: .error))
            BrindooLog.error("Errore caricamento pagina successiva: \(error)")
        }
    }

    /// Carica offerte, categorie e valutazioni dei professionisti indicati.
    private func loadRelated(for profiles: [Profile]) async {
        await loadOffersForOrganizers(profiles)
        await loadCategoriesForOrganizers(profiles)
        if !profiles.isEmpty,
           let ratings = try? await data.fetchRatings(profiles.map { $0.id }) {
            organizerRatings.merge(ratings) { _, new in new }
        }
    }

    private func loadCategoriesForOrganizers(_ profiles: [Profile]) async {
        // Una sola richiesta per tutta la pagina (non una per professionista).
        let missing = profiles.map(\.id).filter { organizerCategoriesMap[$0] == nil }
        guard !missing.isEmpty else { return }
        let map = (try? await data.fetchOrganizerCategoriesMap(missing)) ?? [:]
        for id in missing {
            organizerCategoriesMap[id] = map[id] ?? []
        }
    }

    private func loadOffersForOrganizers(_ profiles: [Profile]) async {
        let ids = profiles.map { $0.id }
        guard !ids.isEmpty else { return }
        do {
            let grouped = try await data.fetchActiveOffers(ids)
            organizerOffersMap.merge(grouped) { _, new in new }
        } catch {
            BrindooLog.error("Errore caricamento offerte: \(error)")
        }
    }

    func loadMyOffers() async {
        do {
            let result = try await data.fetchMyOffers()
            myOffers = result
            await loadCategoriesForMyOffers(result)
        } catch {
            errorMessage = "Impossibile caricare le offerte"
            BrindooLog.error("Errore caricamento offerte: \(error)")
        }
    }

    private func loadCategoriesForMyOffers(_ offers: [ServiceOffer]) async {
        // Una sola richiesta per tutte le offerte.
        let missing = offers.map(\.id).filter { myOfferCategoriesMap[$0] == nil }
        guard !missing.isEmpty else { return }
        let map = (try? await data.fetchOfferCategoriesMap(missing)) ?? [:]
        for id in missing {
            myOfferCategoriesMap[id] = map[id] ?? []
        }
    }
}
