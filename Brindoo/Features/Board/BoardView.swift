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

struct BoardView: View {

    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var toastCenter: BrindooToastCenter

    /// Quando `true`, la vista viene forzata in modalità cliente per permettere
    /// a un organizzatore di vedere l'anteprima della bacheca pubblica.
    var clientPreview: Bool = false

    /// Parte dati (caricamenti a pagine, filtri, cache): vive nel ViewModel.
    @State private var vm = BoardViewModel()

    // Stato di sola interfaccia (pannelli, primo avvio)
    @State private var showAreaPicker: Bool = false
    @State private var showCreateOffer: Bool = false
    @State private var duplicateTemplate: OfferTemplate?
    @State private var showCompleteProfile: Bool = false
    @AppStorage("brindoo.client.welcomeSeen") private var welcomeSeen: Bool = false
    @State private var showWelcome: Bool = false
    @State private var showFilters: Bool = false
    @State private var showClientRequests: Bool = false

    // Scorciatoie verso il ViewModel: il corpo della vista resta invariato.
    private var categories: [ServiceCategory] { vm.categories }
    private var organizers: [Profile] { vm.organizers }
    private var sortedOrganizers: [Profile] { vm.sortedOrganizers }
    private var boostedOrganizers: [Profile] { vm.boostedOrganizers }
    private var organizerCategoriesMap: [UUID: [ServiceCategory]] { vm.organizerCategoriesMap }
    private var organizerOffersMap: [UUID: [ServiceOffer]] { vm.organizerOffersMap }
    private var organizerRatings: [UUID: OrganizerRating] { vm.organizerRatings }
    private var canLoadMore: Bool { vm.canLoadMore }
    private var pageOffset: Int { vm.pageOffset }
    private var myOffers: [ServiceOffer] { vm.myOffers }
    private var myOfferCategoriesMap: [UUID: [ServiceCategory]] { vm.myOfferCategoriesMap }
    private var isLoading: Bool { vm.isLoading }
    private var errorMessage: String? { vm.errorMessage }
    private var hasOrganizerCategories: Bool { vm.hasOrganizerCategories }
    private var hasExtraFilters: Bool { vm.hasExtraFilters }
    private var hasActiveFilters: Bool { vm.hasActiveFilters }
    private var hasContentFilters: Bool { vm.hasContentFilters }
    private var lastSearchedText: String { vm.lastSearchedText }
    private var eventDate: Date? { vm.eventDate }
    private var sortMode: BoardSortMode { vm.sortMode }

    private var searchText: String {
        get { vm.searchText }
        nonmutating set { vm.searchText = newValue }
    }
    private var selectedCategoryIds: Set<UUID> {
        get { vm.selectedCategoryIds }
        nonmutating set { vm.selectedCategoryIds = newValue }
    }
    private var selectedAreaSlugs: Set<String> {
        get { vm.selectedAreaSlugs }
        nonmutating set { vm.selectedAreaSlugs = newValue }
    }

    private var isClient: Bool {
        clientPreview || session.currentProfile?.role == .client
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
            if !clientPreview {
                // Bacheca inversa: il cliente pubblica cosa cerca,
                // il professionista sfoglia le richieste aperte.
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showClientRequests = true
                    } label: {
                        Image(systemName: "megaphone")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.brindooCoral)
                    }
                    .accessibilityLabel(isClient ? "Le mie richieste" : "Richieste dei clienti")
                }
            }
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
                        Picker("Ordina", selection: Bindable(vm).sortMode) {
                            ForEach(BoardSortMode.allCases) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                    } label: {
                        // La variante "piena" segnala un ordinamento diverso da quello di default.
                        Image(systemName: sortMode == .recommended ? "arrow.up.arrow.down.circle" : "arrow.up.arrow.down.circle.fill")
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
            .navigationDestination(isPresented: $showClientRequests) {
                ClientRequestsView()
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
                AreaPickerSheet(selected: Bindable(vm).selectedAreaSlugs) {
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
                BoardFiltersSheet(minRating: Bindable(vm).minRating, maxPrice: Bindable(vm).maxPrice, eventDate: Bindable(vm).eventDate)
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
            .task(id: searchText) {
                // Ricerca "dal vivo": aggiorna la lista mentre si scrive,
                // con una breve pausa per non interrogare il server a ogni lettera.
                guard isClient, !isLoading, searchText != lastSearchedText else { return }
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled, searchText != lastSearchedText else { return }
                await loadOrganizers()
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
                    clearFiltersChip
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

        }
        .padding(.bottom, BrindooSpacing.sm)
    }

    /// Chip compatto "Pulisci" in testa alla riga categorie:
    /// sostituisce la vecchia fascia di riepilogo filtri.
    @ViewBuilder
    private var clearFiltersChip: some View {
        if !selectedCategoryIds.isEmpty || !selectedAreaSlugs.isEmpty || eventDate != nil {
            Button {
                selectedCategoryIds.removeAll()
                selectedAreaSlugs.removeAll()
                vm.eventDate = nil
                Task { await loadOrganizers() }
            } label: {
                HStack(spacing: BrindooSpacing.xxs) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Pulisci")
                        .font(BrindooFont.bodySmall.weight(.medium))
                }
                .foregroundStyle(Color.brindooCoral)
                .padding(.horizontal, BrindooSpacing.sm)
                .padding(.vertical, BrindooSpacing.xs)
                .background(Color.brindooCoral.opacity(0.1))
                .clipShape(Capsule())
            }
            .accessibilityLabel("Pulisci filtri")
        }
    }

    @ViewBuilder
    private var provinceChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BrindooSpacing.xs) {
                areaFilterButton
                Divider().frame(height: 22)
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

            TextField("Cerca professionista", text: Bindable(vm).searchText)
                .font(BrindooFont.bodyLarge)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .onSubmit { Task { await loadOrganizers() } }

            if !searchText.isEmpty {
                Button {
                    // La ricarica parte dal task di ricerca "dal vivo".
                    searchText = ""
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
        } else if sortedOrganizers.isEmpty {
            // I filtri extra (stelle/prezzo) tagliano tutto il caricato:
            // continua a caricare pagine finché trova un profilo valido
            // o le pagine finiscono, per non mostrare un vuoto ingannevole.
            if canLoadMore {
                VStack(spacing: BrindooSpacing.md) {
                    ProgressView()
                    Text("Cerco altri profili che rispettano i filtri…")
                        .font(BrindooFont.bodySmall)
                        .foregroundStyle(Color.brindooTextSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task(id: pageOffset) { await loadMoreOrganizers() }
            } else {
                emptyView(
                    icon: "line.3.horizontal.decrease.circle",
                    title: "Nessun risultato",
                    subtitle: "Nessun profilo rispetta i filtri scelti",
                    showClear: true
                )
            }
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
                Text("\(sortedOrganizers.count)\(canLoadMore ? "+" : "") professionisti consigliati per te")
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
            BrindooEmptyState(
                icon: "tag",
                title: "Nessuna offerta",
                message: "Pubblica la tua prima offerta per farti trovare dai clienti",
                actionTitle: "Crea offerta"
            ) {
                showCreateOffer = true
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

    private func clearAllFilters() {
        vm.clearAllFilters()
    }

    @ViewBuilder
    private func emptyView(icon: String, title: String, subtitle: String, showClear: Bool) -> some View {
        VStack(spacing: BrindooSpacing.md) {
            BrindooEmptyState(
                icon: icon,
                title: title,
                message: subtitle,
                actionTitle: showClear ? "Rimuovi filtri" : nil,
                action: showClear ? { clearAllFilters() } : nil
            )

            Text("Brindoo sta arrivando in tutto il Lazio. Aiutaci a crescere!")
                .font(BrindooFont.caption)
                .foregroundStyle(Color.brindooTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, BrindooSpacing.xl)

            ShareLink(item: Self.inviteMessage) {
                Label("Invita un professionista", systemImage: "person.badge.plus")
                    .font(BrindooFont.button)
                    .foregroundStyle(.white)
                    .frame(maxWidth: 260)
                    .padding(.vertical, BrindooSpacing.sm)
                    .background(Color.brindooCoral)
                    .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
            }
            .padding(.bottom, BrindooSpacing.xl)
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

    // MARK: - Loading (delegato al ViewModel)

    private func loadInitial() async {
        vm.configure(
            isClient: isClient,
            clientPreview: clientPreview,
            userID: session.userID,
            province: session.currentProfile?.province
        ) { toast in
            toastCenter.show(toast)
        }
        await vm.loadInitial()

        // Primo passo guidato per il cliente (una sola volta).
        if isClient && !clientPreview && !welcomeSeen && !categories.isEmpty {
            showWelcome = true
        }
    }

    private func checkOrganizerCategoriesIfNeeded() async { await vm.checkOrganizerCategoriesIfNeeded() }
    private func reload() async { await vm.reload() }
    private func loadOrganizers() async { await vm.loadOrganizers() }
    private func loadMoreOrganizers() async { await vm.loadMoreOrganizers() }
    private func loadMyOffers() async { await vm.loadMyOffers() }
}
