//
//  SavedSearchService.swift
//  Brindoo
//
//  Ricerche salvate ("DJ a Latina sotto 500€") con avviso opzionale.
//
//  Tutto resta sul telefono: nessun dato in più sul server. Quando l'app
//  torna in primo piano, le ricerche con l'avviso attivo vengono rifatte
//  in silenzio; se sono comparsi profili nuovi arriva una notifica locale.
//

import Foundation

/// Una ricerca messa da parte dal cliente.
struct SavedSearch: Codable, Identifiable, Hashable, Equatable {
    let id: UUID
    var name: String
    var categoryIds: [UUID]
    var areaSlugs: [String]
    var searchText: String
    var minRating: Int
    var maxPrice: Double
    /// Se acceso, l'app avvisa quando compaiono professionisti nuovi.
    var alertEnabled: Bool
    /// Professionisti già visti: serve a segnalare solo le novità.
    var knownOrganizerIds: [UUID]
    var lastCheckedAt: Date?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        categoryIds: [UUID],
        areaSlugs: [String],
        searchText: String,
        minRating: Int,
        maxPrice: Double,
        alertEnabled: Bool = true,
        knownOrganizerIds: [UUID] = [],
        lastCheckedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.categoryIds = categoryIds
        self.areaSlugs = areaSlugs
        self.searchText = searchText
        self.minRating = minRating
        self.maxPrice = maxPrice
        self.alertEnabled = alertEnabled
        self.knownOrganizerIds = knownOrganizerIds
        self.lastCheckedAt = lastCheckedAt
        self.createdAt = createdAt
    }

    /// Riassunto leggibile dei filtri, per la riga della lista.
    func summary(categories: [ServiceCategory]) -> String {
        var parts: [String] = []
        let names = categories.filter { categoryIds.contains($0.id) }.map(\.name)
        if !names.isEmpty { parts.append(names.joined(separator: ", ")) }
        if areaSlugs.isEmpty {
            parts.append("tutto il Lazio")
        } else {
            parts.append(LazioArea.displayLabel(forSlugs: areaSlugs))
        }
        if !searchText.isEmpty { parts.append("«\(searchText)»") }
        if minRating > 0 { parts.append("da \(minRating) stelle") }
        if maxPrice > 0 { parts.append("max \(BrindooFormat.euro(maxPrice))") }
        return parts.joined(separator: " · ")
    }
}

@MainActor
@Observable
final class SavedSearchService {

    static let shared = SavedSearchService()
    private init() {}

    private(set) var searches: [SavedSearch] = []
    private var loaded = false

    // MARK: - Lettura e scrittura su disco

    func loadIfNeeded() async {
        guard !loaded else { return }
        searches = await LocalCacheStore.shared.load([SavedSearch].self, for: BrindooCacheKey.savedSearches) ?? []
        loaded = true
    }

    private func persist() async {
        await LocalCacheStore.shared.save(searches, for: BrindooCacheKey.savedSearches)
    }

    func add(_ search: SavedSearch) async {
        await loadIfNeeded()
        searches.append(search)
        await persist()
    }

    func remove(id: UUID) async {
        await loadIfNeeded()
        searches.removeAll { $0.id == id }
        await persist()
    }

    func setAlert(id: UUID, enabled: Bool) async {
        await loadIfNeeded()
        guard let index = searches.firstIndex(where: { $0.id == id }) else { return }
        searches[index].alertEnabled = enabled
        await persist()
    }

    func rename(id: UUID, to name: String) async {
        await loadIfNeeded()
        guard let index = searches.firstIndex(where: { $0.id == id }) else { return }
        searches[index].name = name
        await persist()
    }

    // MARK: - Controllo novità

    /// Rifà le ricerche con avviso attivo e notifica i profili nuovi.
    /// Chiamata quando l'app torna in primo piano; non più di una volta l'ora.
    func checkForNewResults(minimumInterval: TimeInterval = 3600) async {
        await loadIfNeeded()
        guard !searches.isEmpty else { return }

        for index in searches.indices {
            let search = searches[index]
            guard search.alertEnabled else { continue }
            if let last = search.lastCheckedAt,
               Date().timeIntervalSince(last) < minimumInterval { continue }

            guard let page = try? await OrganizerService.shared.fetchOrganizers(
                categoryIds: Set(search.categoryIds),
                areaFilters: Set(search.areaSlugs),
                searchText: search.searchText.isEmpty ? nil : search.searchText,
                includeCurrentUser: false,
                limit: 20,
                offset: 0
            ) else { continue }

            let found = page.profiles.map(\.id)
            let known = Set(search.knownOrganizerIds)
            let fresh = found.filter { !known.contains($0) }

            searches[index].lastCheckedAt = Date()
            searches[index].knownOrganizerIds = Array(known.union(found)).suffix(200)

            // Alla prima esecuzione registriamo soltanto: niente notifica
            // per profili che c'erano già prima di salvare la ricerca.
            if !known.isEmpty && !fresh.isEmpty {
                await notify(search: search, newCount: fresh.count)
            }
        }
        await persist()
    }

    private func notify(search: SavedSearch, newCount: Int) async {
        let title = newCount == 1
            ? "Un nuovo profilo per «\(search.name)»"
            : "\(newCount) nuovi profili per «\(search.name)»"
        await NotificationService.shared.showLocal(
            title: title,
            body: "Apri Brindoo per vederli.",
            identifier: "saved-search-\(search.id.uuidString)"
        )
    }
}
