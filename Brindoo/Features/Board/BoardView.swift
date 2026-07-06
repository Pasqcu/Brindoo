//
//  BoardView.swift
//  Brindoo
//
//  Bacheca: vista principale dell'app.
//  - Cliente: sfoglia i professionisti con le loro offerte (filtri + ricerca),
//    caricati a pagine man mano che si scorre.
//  - Professionista: gestisce le proprie offerte pubblicate (CRUD + duplica).
//
//  Le card sono in BoardCards.swift, i pannelli modali in BoardSheets.swift.
//

import SwiftUI

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

struct BoardView: View {

    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var toastCenter: BrindooToastCenter

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

    // Cliente: professionisti con offerte annidate, caricati a pagine
    @State private var organizers: [Profile] = []
    @State private var organizerCategoriesMap: [UUID: [ServiceCategory]] = [:]
    @State private var organizerOffersMap: [UUID: [ServiceOffer]] = [:]
    @State private var canLoadMore: Bool = false
    @State private var isLoadingMore: Bool = false
    @State private var pageOffset: Int = 0
    private let pageSize = 20

    // Organizer: proprie offerte
    @State private var myOffers: [ServiceOffer] = []
    @State private var myOfferCategoriesMap: [UUID: [ServiceCategory]] = [:]
    @State private var showCreateOffer: Bool = false
    @State private var duplicateTemplate: OfferTemplate?
    @State private var showCompleteProfile: Bool = false
    @State private var hasOrganizerCategories: Bool = true

    @AppStorage("brindoo.client.welcomeSeen") private var welcomeSeen: Bool = false
    @State private var showWelcome: Bool = false
    @State private var sortMode: BoardSortMode = .recommended
    @State private var organizerRatings: [UUID: OrganizerRating] = [:]
    @State private var minRating: Int = 0      // 0 = qualsiasi
    @State private var maxPrice: Double = 0     // 0 = nessun limite
    @State private var eventDate: Date? = nil   // nil = qualsiasi giorno
    @State private var showFilters: Bool = false

    private var hasExtraFilters: Bool { minRating > 0 || maxPrice > 0 || eventDate != nil }

    private func minOfferPrice(for id: UUID) -> Double? {
        organizerOffersMap[id]?.map(\.price).min()
    }

    private var sortedOrganizers: [Profile] {
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

    private var isClient: Bool {
        clientPreview || session.currentProfile?.role == .client
    }

    private var hasActiveFilters: Bool {
        !selectedCategoryIds.isEmpty || !selectedAreaSlugs.isEmpty || !searchText.isEmpty || eventDate != nil
    }

    /// Filtri "di contenuto" (categoria/ricerca): l'area provincia non conta,
    /// così la vetrina e l'intestazione restano visibili anche con una provincia scelta.
    private var hasContentFilters: Bool {
        !selectedCategoryIds.isEmpty || !searchText.isEmpty
    }

    private var boostedOrganizers: [Profile] {
        organizers.filter { $0.isBoosted }
    }

    private let lazioProvinces = LazioProvince.allCases

    private func provinceSlug(_ p: LazioProvince) -> String { "prov_\(p.rawValue.lowercased())" }

    private var areaFilterTitle: String {
        if selectedAreaSlugs.isEmpty { return "Area" }
        return LazioArea.displayLabel(forSlugs: Array(selectedAreaSlugs))
    }

    /// Offerta usata come base per "Duplica offerta".
    struct OfferTemplate: Identifiable {
        let id = UUID()
        let offer: ServiceOffer
        let categoryIds: [UUID]
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
                    .accessibilityLabel("Crea offerta")
                }
            }
            if isClient {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFilters = true
                    } label: {
                        Image(systemName: hasExtraFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.brindooCoral)
                    }
                    .accessibilityLabel("Filtri")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Ordina", selection: $sortMode) {
                            ForEach(BoardSortMode.allCases) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.brindooCoral)
                    }
                    .accessibilityLabel("Ordina")
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
            .sheet(item: $duplicateTemplate, onDismiss: {
                Task { await loadMyOffers() }
            }) { template in
                CreateOfferView(template: template.offer, templateCategoryIds: template.categoryIds)
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
            .sheet(isPresented: $showFilters) {
                BoardFiltersSheet(minRating: $minRating, maxPrice: $maxPrice, eventDate: $eventDate)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showWelcome) {
                ClientWelcomeSheet(categories: categories) { chosen in
                    welcomeSeen = true
                    if !chosen.isEmpty {
                        selectedCategoryIds = chosen
                        Task { await loadOrganizers() }
                    }
                } onSkip: {
                    welcomeSeen = true
                }
                .presentationDetents([.medium, .large])
            }
            .task { await loadInitial() }
            .refreshable { await reload() }
            .onChange(of: eventDate) { _, _ in
                Task { await loadOrganizers() }
            }
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

            provinceChipsBar

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

            if !selectedCategoryIds.isEmpty || !selectedAreaSlugs.isEmpty || eventDate != nil {
                HStack {
                    Text(activeFiltersSummary)
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextSecondary)
                    Spacer()
                    Button {
                        selectedCategoryIds.removeAll()
                        selectedAreaSlugs.removeAll()
                        eventDate = nil
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

    @ViewBuilder
    private var provinceChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BrindooSpacing.xs) {
                provinceChip(title: "Tutto il Lazio", isOn: selectedAreaSlugs.isEmpty) {
                    selectedAreaSlugs.removeAll()
                    Task { await loadOrganizers() }
                }
                ForEach(lazioProvinces) { p in
                    let slug = provinceSlug(p)
                    provinceChip(title: p.displayName, isOn: selectedAreaSlugs == [slug]) {
                        selectedAreaSlugs = [slug]
                        Task { await loadOrganizers() }
                    }
                }
            }
            .padding(.horizontal, BrindooSpacing.md)
        }
    }

    @ViewBuilder
    private func provinceChip(title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(BrindooFont.bodySmall.weight(.semibold))
                .foregroundStyle(isOn ? .white : Color.brindooTextSecondary)
                .padding(.horizontal, BrindooSpacing.md)
                .padding(.vertical, BrindooSpacing.xs)
                .background(isOn ? Color.brindooCoral : Color.brindooSurface)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color.brindooBorder, lineWidth: isOn ? 0 : 1))
        }
        .buttonStyle(.plain)
    }

    private var activeFiltersSummary: String {
        var parts: [String] = []
        if !selectedCategoryIds.isEmpty {
            parts.append("\(selectedCategoryIds.count) categorie")
        }
        if !selectedAreaSlugs.isEmpty {
            parts.append("\(selectedAreaSlugs.count) aree")
        }
        if let eventDate {
            let f = DateFormatter()
            f.locale = Locale(identifier: "it_IT")
            f.dateFormat = "d MMM"
            parts.append("liberi il \(f.string(from: eventDate))")
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
                    featuredCarousel

                    discoveryHeader

                    ForEach(sortedOrganizers) { organizer in
                        NavigationLink {
                            OrganizerDetailView(organizer: organizer)
                        } label: {
                            OrganizerWithOffersCard(
                                organizer: organizer,
                                categories: organizerCategoriesMap[organizer.id] ?? [],
                                offers: organizerOffersMap[organizer.id] ?? [],
                                rating: organizerRatings[organizer.id]
                            )
                        }
                        .buttonStyle(BrindooPressStyle())
                    }

                    if canLoadMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, BrindooSpacing.md)
                            .task(id: pageOffset) { await loadMoreOrganizers() }
                    }

                    inviteCard
                }
                .padding(.horizontal, BrindooSpacing.md)
                .padding(.bottom, BrindooSpacing.lg)
                .brindooReadableWidth()
            }
        }
    }

    /// Vetrina "In evidenza": professionisti con Boost attivo.
    @ViewBuilder
    private var featuredCarousel: some View {
        if !hasContentFilters && !boostedOrganizers.isEmpty {
            VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 13))
                    Text("In evidenza")
                        .font(BrindooFont.titleSmall)
                }
                .foregroundStyle(Color.brindooCoral)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: BrindooSpacing.md) {
                        ForEach(boostedOrganizers) { org in
                            NavigationLink {
                                OrganizerDetailView(organizer: org)
                            } label: {
                                FeaturedOrganizerCard(
                                    organizer: org,
                                    rating: organizerRatings[org.id],
                                    coverImageUrl: organizerOffersMap[org.id]?.first(where: { $0.imageUrl?.isEmpty == false })?.imageUrl
                                )
                            }
                            .buttonStyle(BrindooPressStyle())
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(.top, BrindooSpacing.xs)
        }
    }

    /// Intestazione di scoperta mostrata in cima alla bacheca quando non ci sono filtri di contenuto.
    @ViewBuilder
    private var discoveryHeader: some View {
        if !hasContentFilters {
            HStack(spacing: BrindooSpacing.xs) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.brindooCoral)
                Text("\(organizers.count)\(canLoadMore ? "+" : "") professionisti consigliati per te")
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
                        .buttonStyle(BrindooPressStyle())
                        .contextMenu {
                            Button {
                                duplicateTemplate = OfferTemplate(
                                    offer: offer,
                                    categoryIds: (myOfferCategoriesMap[offer.id] ?? []).map(\.id)
                                )
                            } label: {
                                Label("Duplica offerta", systemImage: "plus.square.on.square")
                            }
                        }
                    }

                    Text("Tieni premuta un'offerta per duplicarla")
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, BrindooSpacing.xs)
                }
                .padding(.horizontal, BrindooSpacing.md)
                .padding(.vertical, BrindooSpacing.md)
                .brindooReadableWidth()
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
                    .fill(BrindooGradient.coralSoft.opacity(0.18))
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
                    selectedAreaSlugs.removeAll()
                    searchText = ""
                    eventDate = nil
                    Task { await loadOrganizers() }
                }
                .frame(maxWidth: 200)
            }

            Text("Brindoo sta arrivando in tutto il Lazio. Aiutaci a crescere!")
                .font(BrindooFont.caption)
                .foregroundStyle(Color.brindooTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, BrindooSpacing.xl)
                .padding(.top, BrindooSpacing.xs)

            ShareLink(item: Self.inviteMessage) {
                Label("Invita un professionista", systemImage: "person.badge.plus")
                    .font(BrindooFont.button)
                    .foregroundStyle(.white)
                    .frame(maxWidth: 260)
                    .padding(.vertical, BrindooSpacing.sm)
                    .background(Color.brindooCoral)
                    .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
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
        do {
            categories = try await CategoryService.shared.fetchCategories()
        } catch { print("❌ \(error)") }
        await BlockService.shared.loadBlocks()
        await checkOrganizerCategoriesIfNeeded()

        // Parti già "vicino a casa": filtra sulla provincia dell'utente.
        if isClient && !clientPreview, selectedAreaSlugs.isEmpty,
           let prov = session.currentProfile?.province {
            selectedAreaSlugs = [provinceSlug(prov)]
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

        // Primo passo guidato per il cliente (una sola volta).
        if isClient && !clientPreview && !welcomeSeen && !categories.isEmpty {
            showWelcome = true
        }
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

    /// Una pagina di professionisti già filtrata per data evento (se attiva).
    private func fetchPage(offset: Int, busyIds: Set<UUID>) async throws -> (profiles: [Profile], hasMore: Bool) {
        let page = try await OrganizerService.shared.fetchOrganizers(
            categoryIds: selectedCategoryIds,
            areaFilters: selectedAreaSlugs,
            searchText: searchText.isEmpty ? nil : searchText,
            includeCurrentUser: clientPreview,
            limit: pageSize,
            offset: offset
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
        return (try? await AvailabilityService.shared.fetchBusyOrganizerIds(on: eventDate)) ?? []
    }

    /// Ricarica da zero la prima pagina (e continua finché non trova almeno
    /// un risultato visibile o le pagine finiscono, per non mostrare un
    /// "nessun risultato" ingannevole con il filtro data attivo).
    private func loadOrganizers() async {
        do {
            let busyIds = await fetchBusyIdsIfNeeded()
            var collected: [Profile] = []
            var offset = 0
            var hasMore = true

            repeat {
                let page = try await fetchPage(offset: offset, busyIds: busyIds)
                offset += pageSize
                hasMore = page.hasMore
                collected.append(contentsOf: page.profiles)
            } while collected.isEmpty && hasMore && offset < pageSize * 5

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
            print("❌ \(error)")
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
    private func loadMoreOrganizers() async {
        guard canLoadMore, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let busyIds = await fetchBusyIdsIfNeeded()
            var appended: [Profile] = []
            var offset = pageOffset
            var hasMore = true

            repeat {
                let page = try await fetchPage(offset: offset, busyIds: busyIds)
                offset += pageSize
                hasMore = page.hasMore
                appended.append(contentsOf: page.profiles)
            } while appended.isEmpty && hasMore && offset < pageOffset + pageSize * 5

            let known = Set(organizers.map(\.id))
            let fresh = appended.filter { !known.contains($0.id) }
            await loadRelated(for: fresh)
            organizers.append(contentsOf: fresh)
            pageOffset = offset
            canLoadMore = hasMore
        } catch {
            canLoadMore = false
            toastCenter.show(BrindooToast("Impossibile caricare altri profili", message: "Trascina in basso per riprovare.", style: .error))
            print("❌ \(error)")
        }
    }

    /// Carica offerte, categorie e valutazioni dei professionisti indicati.
    private func loadRelated(for profiles: [Profile]) async {
        await loadOffersForOrganizers(profiles)
        await loadCategoriesForOrganizers(profiles)
        if !profiles.isEmpty,
           let ratings = try? await ReviewService.shared.fetchRatings(organizerIds: profiles.map { $0.id }) {
            organizerRatings.merge(ratings) { _, new in new }
        }
    }

    private func loadCategoriesForOrganizers(_ profiles: [Profile]) async {
        // Una sola richiesta per tutta la pagina (non una per professionista).
        let missing = profiles.map(\.id).filter { organizerCategoriesMap[$0] == nil }
        guard !missing.isEmpty else { return }
        let map = (try? await OrganizerService.shared.fetchOrganizerCategoriesMap(organizerIds: missing)) ?? [:]
        for id in missing {
            organizerCategoriesMap[id] = map[id] ?? []
        }
    }

    private func loadOffersForOrganizers(_ profiles: [Profile]) async {
        let ids = profiles.map { $0.id }
        guard !ids.isEmpty else { return }
        do {
            let grouped = try await ServiceOfferService.shared.fetchActiveOffers(forOrganizers: ids)
            organizerOffersMap.merge(grouped) { _, new in new }
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
        // Una sola richiesta per tutte le offerte.
        let missing = offers.map(\.id).filter { myOfferCategoriesMap[$0] == nil }
        guard !missing.isEmpty else { return }
        let map = (try? await ServiceOfferService.shared.fetchOfferCategoriesMap(offerIds: missing)) ?? [:]
        for id in missing {
            myOfferCategoriesMap[id] = map[id] ?? []
        }
    }
}
