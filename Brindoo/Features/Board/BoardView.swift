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
    /// Barra filtri ridotta: si attiva quando l'utente scorre la bacheca.
    @State private var filtersCompact: Bool = false
    /// Spazio condiviso per l'effetto "la card si apre nel dettaglio".
    @Namespace private var cardZoom
    @State private var showSavedSearches: Bool = false


    private var isClient: Bool {
        clientPreview || session.currentProfile?.role == .client
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
                BoardPreviewBanner()
            }

            if !isClient && shouldShowCompleteHint {
                CompleteProfileHint { showCompleteProfile = true }
            }

            if isClient {
                BoardFiltersBar(vm: vm, showAreaPicker: $showAreaPicker, isCompact: filtersCompact)
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
                // Preventivo guidato: tre domande e subito le offerte adatte.
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        GuidedQuoteView()
                    } label: {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.brindooCoral)
                    }
                    .accessibilityLabel("Preventivo guidato")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSavedSearches = true
                    } label: {
                        Image(systemName: "bookmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.brindooCoral)
                    }
                    .accessibilityLabel("Ricerche salvate")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFilters = true
                    } label: {
                        Image(systemName: vm.hasExtraFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
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
                        // Trasparenza sul criterio: senza spiegazione
                        // "Consigliati" sembra un ordine a pagamento.
                        Section("Come funziona") {
                            Text(BoardSortMode.recommended.hint)
                        }
                    } label: {
                        // La variante "piena" segnala un ordinamento diverso da quello di default.
                        Image(systemName: vm.sortMode == .recommended ? "arrow.up.arrow.down.circle" : "arrow.up.arrow.down.circle.fill")
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
            .sheet(isPresented: $showSavedSearches) {
                SavedSearchesSheet(
                    categories: vm.categories,
                    currentFilters: vm.currentFiltersAsSavedSearch
                ) { search in
                    Task { await vm.applySavedSearch(search) }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showFilters) {
                BoardFiltersSheet(minRating: Bindable(vm).minRating, maxPrice: Bindable(vm).maxPrice, eventDate: Bindable(vm).eventDate)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showWelcome) {
                ClientWelcomeSheet(categories: vm.categories) { chosen in
                    welcomeSeen = true
                    if !chosen.isEmpty {
                        vm.selectedCategoryIds = chosen
                        Task { await loadOrganizers() }
                    }
                } onSkip: {
                    welcomeSeen = true
                }
                .presentationDetents([.medium, .large])
            }
            .task { await loadInitial() }
            .onChange(of: vm.eventDate) { _, _ in
                Task { await loadOrganizers() }
            }
            .task(id: vm.searchText) {
                // Ricerca "dal vivo": aggiorna la lista mentre si scrive,
                // con una breve pausa per non interrogare il server a ogni lettera.
                guard isClient, !vm.isLoading, vm.searchText != vm.lastSearchedText else { return }
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled, vm.searchText != vm.lastSearchedText else { return }
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
        ProfessionalOnboardingHint.isPending && !vm.hasOrganizerCategories
    }

    // MARK: - Content router

    @ViewBuilder
    private var content: some View {
        if vm.isLoading {
            BoardLoadingSkeleton()
        } else if let errorMessage = vm.errorMessage {
            BoardErrorView(message: errorMessage) {
                Task { await reload() }
            }
        } else if isClient {
            clientList
        } else {
            organizerList
        }
    }

    // MARK: - Lista cliente

    @ViewBuilder
    private var clientList: some View {
        if vm.organizers.isEmpty {
            BoardEmptyView(
                icon: vm.hasActiveFilters ? "magnifyingglass" : "person.2",
                title: vm.hasActiveFilters ? "Nessun risultato" : "Nessun professionista",
                subtitle: vm.hasActiveFilters
                    ? "Nessun professionista con questi filtri"
                    : "Non ci sono ancora professionisti disponibili",
                showClear: vm.hasActiveFilters,
                onClear: { clearAllFilters() },
                suggestions: vm.noResultSuggestions,
                onSuggestion: { s in Task { await vm.apply(s) } },
                showGuidedQuote: isClient
            )
        } else if vm.sortedOrganizers.isEmpty {
            // I filtri extra (stelle/prezzo) tagliano tutto il caricato:
            // continua a caricare pagine finché trova un profilo valido
            // o le pagine finiscono, per non mostrare un vuoto ingannevole.
            if vm.canLoadMore {
                VStack(spacing: BrindooSpacing.md) {
                    ProgressView()
                    Text("Cerco altri profili che rispettano i filtri…")
                        .font(BrindooFont.bodySmall)
                        .foregroundStyle(Color.brindooTextSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task(id: vm.pageOffset) { await loadMoreOrganizers() }
            } else {
                BoardEmptyView(
                    icon: "line.3.horizontal.decrease.circle",
                    title: "Nessun risultato",
                    subtitle: "Nessun profilo rispetta i filtri scelti",
                    showClear: true,
                    onClear: { clearAllFilters() },
                    suggestions: vm.noResultSuggestions,
                    onSuggestion: { s in Task { await vm.apply(s) } },
                    showGuidedQuote: isClient
                )
            }
        } else {
            ScrollView {
                LazyVStack(spacing: BrindooSpacing.md) {
                    // Sonda invisibile: dice quanto si è scorso, così la
                    // barra filtri può ridursi e liberare schermo.
                    Color.clear
                        .frame(height: 0)
                        .background(
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: BoardScrollOffsetKey.self,
                                    value: proxy.frame(in: .named("boardScroll")).minY
                                )
                            }
                        )

                    if !vm.hasContentFilters && !vm.boostedOrganizers.isEmpty {
                        BoardFeaturedCarousel(
                            organizers: vm.boostedOrganizers,
                            ratings: vm.organizerRatings,
                            offersMap: vm.organizerOffersMap
                        )
                    }

                    if !vm.hasContentFilters {
                        BoardDiscoveryHeader(count: vm.sortedOrganizers.count, hasMore: vm.canLoadMore)
                    }

                    ForEach(vm.sortedOrganizers) { organizer in
                        NavigationLink {
                            OrganizerDetailView(organizer: organizer)
                                .brindooZoomDestination(id: organizer.id, in: cardZoom)
                        } label: {
                            OrganizerWithOffersCard(
                                organizer: organizer,
                                categories: vm.organizerCategoriesMap[organizer.id] ?? [],
                                offers: vm.organizerOffersMap[organizer.id] ?? [],
                                rating: vm.organizerRatings[organizer.id]
                            )
                        }
                        .buttonStyle(BrindooPressStyle())
                        .brindooZoomSource(id: organizer.id, in: cardZoom)
                    }

                    if vm.canLoadMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, BrindooSpacing.md)
                            .task(id: vm.pageOffset) { await loadMoreOrganizers() }
                    }

                    BoardInviteCard()
                }
                .padding(.horizontal, BrindooSpacing.md)
                .padding(.bottom, BrindooSpacing.lg)
                .brindooReadableWidth()
            }
            .coordinateSpace(name: "boardScroll")
            .onPreferenceChange(BoardScrollOffsetKey.self) { [compact = $filtersCompact] offset in
                // Soglie diverse per chiudere e riaprire: evita il
                // tremolio quando si sta esattamente sul limite.
                if offset < -70, !compact.wrappedValue {
                    withAnimation(BrindooAnimation.snappy) { compact.wrappedValue = true }
                } else if offset > -20, compact.wrappedValue {
                    withAnimation(BrindooAnimation.snappy) { compact.wrappedValue = false }
                }
            }
            // Tira-per-aggiornare solo sulla lista verticale: la barra dei
            // filtri resta ferma e non innesca ricariche accidentali.
            .refreshable { await reload() }
        }
    }

    // MARK: - Lista organizer (mie offerte)

    @ViewBuilder
    private var organizerList: some View {
        if vm.myOffers.isEmpty {
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
                    ForEach(vm.myOffers) { offer in
                        NavigationLink {
                            OfferDetailView(offer: offer) {
                                Task { await loadMyOffers() }
                            }
                            .brindooZoomDestination(id: offer.id, in: cardZoom)
                        } label: {
                            OfferCard(
                                offer: offer,
                                categories: vm.myOfferCategoriesMap[offer.id] ?? [],
                                organizer: nil,
                                showOrganizer: false
                            )
                        }
                        .buttonStyle(BrindooPressStyle())
                        .brindooZoomSource(id: offer.id, in: cardZoom)
                        .contextMenu {
                            Button {
                                duplicateTemplate = OfferTemplate(
                                    offer: offer,
                                    categoryIds: (vm.myOfferCategoriesMap[offer.id] ?? []).map(\.id)
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
            .refreshable { await reload() }
        }
    }

    // MARK: - Empty / error

    private func clearAllFilters() {
        vm.clearAllFilters()
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
        if isClient && !clientPreview && !welcomeSeen && !vm.categories.isEmpty {
            showWelcome = true
        }
    }

    private func checkOrganizerCategoriesIfNeeded() async { await vm.checkOrganizerCategoriesIfNeeded() }
    private func reload() async { await vm.reload() }
    private func loadOrganizers() async { await vm.loadOrganizers() }
    private func loadMoreOrganizers() async { await vm.loadMoreOrganizers() }
    private func loadMyOffers() async { await vm.loadMyOffers() }
}

// MARK: - Sonda di scorrimento

/// Riporta quanto è stata scorsa la bacheca, per ridurre la barra filtri.
struct BoardScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
