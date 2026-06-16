//
//  BoardView.swift
//  Brindoo
//
//  Bacheca: vista principale dell'app.
//  - Cliente: sfoglia i professionisti con le loro offerte (filtro per categoria + ricerca).
//  - Professionista: gestisce le proprie offerte pubblicate (CRUD).
//

import SwiftUI

struct BoardView: View {

    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    /// Quando `true`, la vista viene forzata in modalità cliente per permettere
    /// a un organizzatore di vedere l'anteprima della bacheca pubblica.
    var clientPreview: Bool = false

    // Stato condiviso
    @State private var categories: [ServiceCategory] = []
    @State private var selectedCategoryIds: Set<UUID> = []
    @State private var selectedAreaSlugs: Set<String> = []
    @State private var searchText: String = ""
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var showAreaPicker: Bool = false

    // Cliente: professionisti con offerte annidate
    @State private var organizers: [Profile] = []
    @State private var organizerCategoriesMap: [UUID: [ServiceCategory]] = [:]
    @State private var organizerOffersMap: [UUID: [ServiceOffer]] = [:]

    // Organizer: proprie offerte
    @State private var myOffers: [ServiceOffer] = []
    @State private var myOfferCategoriesMap: [UUID: [ServiceCategory]] = [:]
    @State private var showCreateOffer: Bool = false
    @State private var showCompleteProfile: Bool = false
    @State private var hasOrganizerCategories: Bool = true

    private var isClient: Bool {
        clientPreview || session.currentProfile?.role == .client
    }

    private var hasActiveFilters: Bool {
        !selectedCategoryIds.isEmpty || !selectedAreaSlugs.isEmpty || !searchText.isEmpty
    }

    private var areaFilterTitle: String {
        if selectedAreaSlugs.isEmpty { return "Area" }
        return LazioArea.displayLabel(forSlugs: Array(selectedAreaSlugs))
    }

    var body: some View {
        Group {
            if clientPreview {
                rootContent
            } else {
                NavigationStack { rootContent }
            }
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        VStack(spacing: 0) {
            if clientPreview {
                previewBanner
            }

            if !isClient && shouldShowCompleteHint {
                completeProfileHint
            }

            if isClient {
                clientFiltersBar
            }

            content
        }
        .background(Color.brindooBackground)
        .navigationTitle(clientPreview ? "Anteprima bacheca" : "Bacheca")
        .navigationBarTitleDisplayMode(clientPreview ? .inline : .large)
        .toolbar {
            if !isClient {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateOffer = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.brindooCoral)
                    }
                }
            }
            if clientPreview {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chiudi") { dismiss() }
                        .font(BrindooFont.bodyMedium.weight(.medium))
                        .foregroundStyle(Color.brindooCoral)
                }
            }
        }
            .sheet(isPresented: $showCreateOffer, onDismiss: {
                Task { await loadMyOffers() }
            }) {
                CreateOfferView()
            }
            .sheet(isPresented: $showAreaPicker) {
                AreaPickerSheet(selected: $selectedAreaSlugs) {
                    Task { await loadOrganizers() }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showCompleteProfile, onDismiss: {
                Task { await checkOrganizerCategoriesIfNeeded() }
            }) {
                EditProfileView()
            }
            .task { await loadInitial() }
            .refreshable { await reload() }
            .coachMark(
                isClient ? .boardClient : .boardOrganizer,
                content: isClient
                    ? CoachMarkContent(
                        icon: "person.2.fill",
                        title: "Bacheca professionisti",
                        message: "Sfoglia i professionisti e le loro offerte. Filtra per servizio e scegli quello giusto per te."
                    )
                    : CoachMarkContent(
                        icon: "tag",
                        title: "Le tue offerte",
                        message: "Pubblica i servizi che offri ai clienti. Tocca il + per crearne una nuova."
                    )
            )
    }

    // MARK: - Complete profile hint (organizer appena upgradato)

    private var shouldShowCompleteHint: Bool {
        ProfessionalOnboardingHint.isPending && !hasOrganizerCategories
    }

    @ViewBuilder
    private var completeProfileHint: some View {
        Button {
            showCompleteProfile = true
        } label: {
            HStack(spacing: BrindooSpacing.sm) {
                Image(systemName: "exclamationmark.bubble.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.brindooCoral)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Completa il tuo profilo Professionista")
                        .font(BrindooFont.bodyMedium.weight(.semibold))
                        .foregroundStyle(Color.brindooTextPrimary)
                    Text("Aggiungi le categorie di servizio per essere trovato dai clienti.")
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextSecondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.brindooTextSecondary)
            }
            .padding(BrindooSpacing.md)
            .background(Color.brindooCoral.opacity(0.08))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Preview banner

    @ViewBuilder
    private var previewBanner: some View {
        HStack(spacing: BrindooSpacing.xs) {
            Image(systemName: "eye")
            Text("Stai vedendo la bacheca come la vedono i clienti.")
                .font(BrindooFont.caption)
            Spacer()
        }
        .foregroundStyle(Color.brindooCoral)
        .padding(.horizontal, BrindooSpacing.md)
        .padding(.vertical, BrindooSpacing.xs)
        .background(Color.brindooCoral.opacity(0.08))
    }

    // MARK: - Content router

    @ViewBuilder
    private var content: some View {
        if isLoading {
            loadingSkeleton
        } else if let errorMessage {
            errorView(errorMessage)
        } else if isClient {
            clientList
        } else {
            organizerList
        }
    }

    @ViewBuilder
    private var loadingSkeleton: some View {
        ScrollView {
            LazyVStack(spacing: BrindooSpacing.md) {
                ForEach(0..<6, id: \.self) { _ in
                    BrindooSkeletonCard()
                }
            }
            .padding(BrindooSpacing.md)
        }
        .disabled(true)
    }

    // MARK: - Filtri cliente

    @ViewBuilder
    private var clientFiltersBar: some View {
        VStack(spacing: BrindooSpacing.xs) {
            searchBar
                .padding(.horizontal, BrindooSpacing.md)
                .padding(.top, BrindooSpacing.xs)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: BrindooSpacing.xs) {
                    areaFilterButton
                    Divider().frame(height: 22)
                    ForEach(categories) { category in
                        let isSelected = selectedCategoryIds.contains(category.id)
                        let tint = category.tint
                        Button {
                            if isSelected {
                                selectedCategoryIds.remove(category.id)
                            } else {
                                selectedCategoryIds.insert(category.id)
                            }
                            Task { await loadOrganizers() }
                        } label: {
                            HStack(spacing: BrindooSpacing.xxs) {
                                Image(systemName: category.icon)
                                    .font(.system(size: 13, weight: .medium))
                                Text(category.name)
                                    .font(BrindooFont.bodySmall.weight(.medium))
                            }
                            .foregroundStyle(isSelected ? .white : tint)
                            .padding(.horizontal, BrindooSpacing.md)
                            .padding(.vertical, BrindooSpacing.xs)
                            .background(isSelected ? tint : tint.opacity(0.12))
                            .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, BrindooSpacing.md)
            }

            if !selectedCategoryIds.isEmpty || !selectedAreaSlugs.isEmpty {
                HStack {
                    Text(activeFiltersSummary)
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextSecondary)
                    Spacer()
                    Button {
                        selectedCategoryIds.removeAll()
                        selectedAreaSlugs.removeAll()
                        Task { await loadOrganizers() }
                    } label: {
                        Text("Pulisci")
                            .font(BrindooFont.caption.weight(.medium))
                            .foregroundStyle(Color.brindooCoral)
                    }
                }
                .padding(.horizontal, BrindooSpacing.md)
            }
        }
        .padding(.bottom, BrindooSpacing.sm)
    }

    private var activeFiltersSummary: String {
        var parts: [String] = []
        if !selectedCategoryIds.isEmpty {
            parts.append("\(selectedCategoryIds.count) categorie")
        }
        if !selectedAreaSlugs.isEmpty {
            parts.append("\(selectedAreaSlugs.count) aree")
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var areaFilterButton: some View {
        let isActive = !selectedAreaSlugs.isEmpty
        Button {
            showAreaPicker = true
        } label: {
            HStack(spacing: BrindooSpacing.xxs) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 13, weight: .medium))
                Text(areaFilterTitle)
                    .font(BrindooFont.bodySmall.weight(.medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isActive ? .white : Color.brindooCoral)
            .padding(.horizontal, BrindooSpacing.md)
            .padding(.vertical, BrindooSpacing.xs)
            .background(isActive ? Color.brindooCoral : Color.brindooCoral.opacity(0.1))
            .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private var searchBar: some View {
        HStack(spacing: BrindooSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.brindooTextSecondary)

            TextField("Cerca professionista", text: $searchText)
                .font(BrindooFont.bodyLarge)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .onSubmit { Task { await loadOrganizers() } }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    Task { await loadOrganizers() }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.brindooTextSecondary)
                }
            }
        }
        .padding(.horizontal, BrindooSpacing.md)
        .frame(height: 44)
        .background(Color.brindooSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
    }

    // MARK: - Lista cliente

    @ViewBuilder
    private var clientList: some View {
        if organizers.isEmpty {
            emptyView(
                icon: hasActiveFilters ? "magnifyingglass" : "person.2",
                title: hasActiveFilters ? "Nessun risultato" : "Nessun professionista",
                subtitle: hasActiveFilters
                    ? "Prova a rimuovere qualche filtro"
                    : "Non ci sono ancora professionisti disponibili",
                showClear: hasActiveFilters
            )
        } else {
            ScrollView {
                LazyVStack(spacing: BrindooSpacing.md) {
                    discoveryHeader

                    ForEach(organizers) { organizer in
                        NavigationLink {
                            OrganizerDetailView(organizer: organizer)
                        } label: {
                            OrganizerWithOffersCard(
                                organizer: organizer,
                                categories: organizerCategoriesMap[organizer.id] ?? [],
                                offers: organizerOffersMap[organizer.id] ?? []
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    inviteCard
                }
                .padding(.horizontal, BrindooSpacing.md)
                .padding(.bottom, BrindooSpacing.lg)
            }
        }
    }

    /// Intestazione di scoperta mostrata in cima alla bacheca quando non ci sono filtri.
    @ViewBuilder
    private var discoveryHeader: some View {
        if !hasActiveFilters {
            HStack(spacing: BrindooSpacing.xs) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.brindooCoral)
                Text("\(organizers.count) professionisti consigliati per te")
                    .font(BrindooFont.bodySmall.weight(.medium))
                    .foregroundStyle(Color.brindooTextSecondary)
                Spacer()
            }
            .padding(.top, BrindooSpacing.xs)
        }
    }

    /// Invito a portare nuovi professionisti (utile per popolare la bacheca).
    @ViewBuilder
    private var inviteCard: some View {
        ShareLink(item: Self.inviteMessage) {
            HStack(spacing: BrindooSpacing.sm) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.brindooCoral)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Conosci un professionista?")
                        .font(BrindooFont.bodyMedium.weight(.semibold))
                        .foregroundStyle(Color.brindooTextPrimary)
                    Text("Invitalo su Brindoo e aiutalo a farsi trovare")
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextSecondary)
                }
                Spacer()
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.brindooCoral)
            }
            .padding(BrindooSpacing.md)
            .frame(maxWidth: .infinity)
            .background(Color.brindooCoral.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
        }
        .buttonStyle(.plain)
        .padding(.top, BrindooSpacing.xs)
    }

    static let inviteMessage = "Ti ho trovato su Brindoo? 🎉 È l'app per organizzare feste ed eventi: crea il tuo profilo da professionista e fatti scegliere dai clienti del Lazio!"

    // MARK: - Lista organizer (mie offerte)

    @ViewBuilder
    private var organizerList: some View {
        if myOffers.isEmpty {
            VStack(spacing: BrindooSpacing.md) {
                Spacer()
                ZStack {
                    Circle()
                        .fill(Color.brindooCoral.opacity(0.1))
                        .frame(width: 100, height: 100)
                    Image(systemName: "tag")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.brindooCoral)
                }
                Text("Nessuna offerta")
                    .font(BrindooFont.titleMedium)
                Text("Pubblica la tua prima offerta per farti trovare dai clienti")
                    .font(BrindooFont.bodyMedium)
                    .foregroundStyle(Color.brindooTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, BrindooSpacing.xl)
                BrindooButton("Crea offerta", style: .primary) {
                    showCreateOffer = true
                }
                .frame(maxWidth: 240)
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: BrindooSpacing.md) {
                    ForEach(myOffers) { offer in
                        NavigationLink {
                            OfferDetailView(offer: offer) {
                                Task { await loadMyOffers() }
                            }
                        } label: {
                            OfferCard(
                                offer: offer,
                                categories: myOfferCategoriesMap[offer.id] ?? [],
                                organizer: nil,
                                showOrganizer: false
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, BrindooSpacing.md)
                .padding(.vertical, BrindooSpacing.md)
            }
        }
    }

    // MARK: - Empty / error

    @ViewBuilder
    private func emptyView(icon: String, title: String, subtitle: String, showClear: Bool) -> some View {
        VStack(spacing: BrindooSpacing.md) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.brindooCoral.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: icon)
                    .font(.system(size: 44))
                    .foregroundStyle(Color.brindooCoral)
            }
            Text(title).font(BrindooFont.titleMedium)
            Text(subtitle)
                .font(BrindooFont.bodyMedium)
                .foregroundStyle(Color.brindooTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, BrindooSpacing.xl)

            if showClear {
                BrindooButton("Rimuovi filtri", style: .secondary) {
                    selectedCategoryIds.removeAll()
                    searchText = ""
                    Task { await loadOrganizers() }
                }
                .frame(maxWidth: 200)
            } else {
                ShareLink(item: Self.inviteMessage) {
                    Label("Invita un professionista", systemImage: "person.badge.plus")
                        .font(BrindooFont.button)
                        .foregroundStyle(.white)
                        .frame(maxWidth: 260)
                        .padding(.vertical, BrindooSpacing.sm)
                        .background(Color.brindooCoral)
                        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
                }
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        VStack(spacing: BrindooSpacing.md) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.brindooWarning)
            Text(message)
                .font(BrindooFont.bodyMedium)
                .foregroundStyle(Color.brindooTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, BrindooSpacing.xl)
            BrindooButton("Riprova", style: .secondary) {
                Task { await reload() }
            }
            .frame(maxWidth: 200)
            Spacer()
        }
    }

    // MARK: - Loading

    private func loadInitial() async {
        isLoading = true
        defer { isLoading = false }
        do {
            categories = try await CategoryService.shared.fetchCategories()
        } catch { print("❌ \(error)") }
        await BlockService.shared.loadBlocks()
        await checkOrganizerCategoriesIfNeeded()
        await reload()
    }

    /// Verifica se l'organizer ha almeno una categoria. Se l'utente non è
    /// organizer o non ha mai cliccato "Diventa Professionista" non fa nulla.
    private func checkOrganizerCategoriesIfNeeded() async {
        guard !isClient,
              ProfessionalOnboardingHint.isPending,
              let userId = session.userID else { return }
        let cats = (try? await OrganizerService.shared.fetchOrganizerCategories(organizerID: userId)) ?? []
        hasOrganizerCategories = !cats.isEmpty
        if !cats.isEmpty {
            ProfessionalOnboardingHint.clear()
        }
    }

    private func reload() async {
        errorMessage = nil
        if isClient {
            await loadOrganizers()
        } else {
            await loadMyOffers()
        }
    }

    private func loadOrganizers() async {
        do {
            let profiles = try await OrganizerService.shared.fetchOrganizers(
                categoryIds: selectedCategoryIds,
                areaFilters: selectedAreaSlugs,
                searchText: searchText.isEmpty ? nil : searchText,
                includeCurrentUser: clientPreview
            )
            await loadOffersForOrganizers(profiles)
            await loadCategoriesForOrganizers(profiles)
            organizers = profiles
        } catch {
            errorMessage = "Impossibile caricare i professionisti"
            print("❌ \(error)")
        }
    }

    private func loadCategoriesForOrganizers(_ profiles: [Profile]) async {
        await withTaskGroup(of: (UUID, [ServiceCategory]).self) { group in
            for profile in profiles {
                if organizerCategoriesMap[profile.id] != nil { continue }
                group.addTask {
                    let cats = (try? await OrganizerService.shared.fetchOrganizerCategories(organizerID: profile.id)) ?? []
                    return (profile.id, cats)
                }
            }
            for await (id, cats) in group {
                organizerCategoriesMap[id] = cats
            }
        }
    }

    private func loadOffersForOrganizers(_ profiles: [Profile]) async {
        let ids = profiles.map { $0.id }
        guard !ids.isEmpty else {
            organizerOffersMap = [:]
            return
        }
        do {
            let grouped = try await ServiceOfferService.shared.fetchActiveOffers(forOrganizers: ids)
            organizerOffersMap = grouped
        } catch {
            print("❌ \(error)")
        }
    }

    private func loadMyOffers() async {
        do {
            let result = try await ServiceOfferService.shared.fetchMyOffers()
            myOffers = result
            await loadCategoriesForMyOffers(result)
        } catch {
            errorMessage = "Impossibile caricare le offerte"
            print("❌ \(error)")
        }
    }

    private func loadCategoriesForMyOffers(_ offers: [ServiceOffer]) async {
        await withTaskGroup(of: (UUID, [ServiceCategory]).self) { group in
            for offer in offers {
                if myOfferCategoriesMap[offer.id] != nil { continue }
                group.addTask {
                    let cats = (try? await ServiceOfferService.shared.fetchOfferCategories(offerId: offer.id)) ?? []
                    return (offer.id, cats)
                }
            }
            for await (id, cats) in group {
                myOfferCategoriesMap[id] = cats
            }
        }
    }
}

// MARK: - Card professionista con offerte annidate (cliente)

struct OrganizerWithOffersCard: View {

    let organizer: Profile
    let categories: [ServiceCategory]
    let offers: [ServiceOffer]

    private let previewCount = 2

    var body: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
            HStack(spacing: BrindooSpacing.sm) {
                AvatarView(url: organizer.avatarUrl, name: organizer.fullName, size: 56)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(organizer.fullName ?? "Senza nome")
                            .font(BrindooFont.titleSmall)
                            .lineLimit(1)
                        if organizer.isPro {
                            ProBadge()
                        }
                    }

                    if let city = organizer.city, !city.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 11))
                            Text(city)
                                .font(BrindooFont.caption)
                                .lineLimit(1)
                        }
                        .foregroundStyle(Color.brindooTextSecondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.brindooTextSecondary)
            }

            if !categories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(categories.prefix(4)) { cat in
                            HStack(spacing: 3) {
                                Image(systemName: cat.icon)
                                    .font(.system(size: 10, weight: .medium))
                                Text(cat.name)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(cat.tint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(cat.tint.opacity(0.12))
                            .clipShape(Capsule())
                        }
                        if categories.count > 4 {
                            Text("+\(categories.count - 4)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.brindooTextSecondary)
                        }
                    }
                }
            }

            if !offers.isEmpty {
                Divider()
                    .padding(.vertical, 2)

                VStack(spacing: BrindooSpacing.xs) {
                    ForEach(offers.prefix(previewCount)) { offer in
                        offerRow(offer)
                    }
                }

                if offers.count > previewCount {
                    Text("+\(offers.count - previewCount) altre offerte")
                        .font(BrindooFont.caption.weight(.medium))
                        .foregroundStyle(Color.brindooCoral)
                        .padding(.top, 2)
                }
            }
        }
        .padding(BrindooSpacing.md)
        .background(Color.brindooSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: BrindooRadius.lg)
                .strokeBorder(Color.brindooBorder, lineWidth: 1)
        )
        .brindooCardShadow()
    }

    @ViewBuilder
    private func offerRow(_ offer: ServiceOffer) -> some View {
        HStack(alignment: .top, spacing: BrindooSpacing.sm) {
            Image(systemName: "tag.fill")
                .font(.system(size: 12))
                .foregroundStyle(Color.brindooCoral)
                .frame(width: 24, height: 24)
                .background(Color.brindooCoral.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(offer.title)
                    .font(BrindooFont.bodySmall.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(Color.brindooTextPrimary)
                Text(offer.coverageArea)
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooTextSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(offer.priceDisplay)
                .font(BrindooFont.bodySmall.weight(.semibold))
                .foregroundStyle(Color.brindooCoral)
        }
    }
}

// MARK: - Area picker sheet (per cliente: filtro bacheca)

struct AreaPickerSheet: View {

    @Binding var selected: Set<String>
    let onApply: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var working: Set<String> = []
    @State private var searchQuery: String = ""

    private var filteredAreas: [LazioArea] {
        let q = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return LazioArea.allCases }
        return LazioArea.allCases.filter { $0.name.lowercased().contains(q) }
    }

    private var areasByProvince: [(LazioProvince, [LazioArea])] {
        let grouped = Dictionary(grouping: filteredAreas, by: { $0.province })
        return LazioProvince.allCases.compactMap { p in
            guard let list = grouped[p], !list.isEmpty else { return nil }
            return (p, list)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BrindooSpacing.md) {

                    BrindooTextField(
                        title: "Cerca",
                        placeholder: "Es. EUR, Tivoli, Latina…",
                        text: $searchQuery,
                        icon: "magnifyingglass",
                        autocapitalization: .never
                    )

                    ForEach(areasByProvince, id: \.0) { province, areas in
                        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
                            Text(province.displayName)
                                .font(BrindooFont.bodySmall.weight(.semibold))
                                .foregroundStyle(Color.brindooTextSecondary)
                                .textCase(.uppercase)
                                .padding(.top, BrindooSpacing.xs)

                            VStack(spacing: BrindooSpacing.xxs) {
                                ForEach(areas) { area in
                                    row(area)
                                }
                            }
                        }
                    }
                }
                .padding(BrindooSpacing.md)
            }
            .background(Color.brindooBackground)
            .navigationTitle("Filtra per area")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Pulisci") { working.removeAll() }
                        .disabled(working.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Applica") {
                        selected = working
                        onApply()
                        dismiss()
                    }
                    .font(BrindooFont.bodyMedium.weight(.semibold))
                }
            }
            .onAppear { working = selected }
        }
    }

    @ViewBuilder
    private func row(_ area: LazioArea) -> some View {
        let isOn = working.contains(area.slug)
        Button {
            if isOn { working.remove(area.slug) }
            else { working.insert(area.slug) }
        } label: {
            HStack(spacing: BrindooSpacing.sm) {
                Image(systemName: area.isWholeProvince ? "map.fill" : "mappin.and.ellipse")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isOn ? .white : Color.brindooCoral)
                    .frame(width: 28, height: 28)
                    .background(isOn ? Color.brindooCoral : Color.brindooCoral.opacity(0.1))
                    .clipShape(Circle())

                Text(area.name)
                    .font(BrindooFont.bodyMedium.weight(.medium))
                    .foregroundStyle(Color.brindooTextPrimary)

                Spacer()

                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isOn ? Color.brindooCoral : Color.brindooTextSecondary)
            }
            .padding(.horizontal, BrindooSpacing.sm)
            .padding(.vertical, BrindooSpacing.xs)
            .background(isOn ? Color.brindooCoral.opacity(0.05) : Color.brindooSurface)
            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
        }
        .buttonStyle(.plain)
    }
}
