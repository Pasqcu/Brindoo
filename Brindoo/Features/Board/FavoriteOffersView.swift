//
//  FavoriteOffersView.swift
//  Brindoo
//
//  Lista delle offerte salvate dal cliente corrente.
//  Usa LoadState: caricamento / vuoto / errore / lista gestiti in modo standard.
//

import SwiftUI

struct FavoriteOffersView: View {

    @State private var state: LoadState<[ServiceOffer]> = .loading
    @State private var organizers: [UUID: Profile] = [:]
    @State private var categories: [UUID: [ServiceCategory]] = [:]

    var body: some View {
        Group {
            switch state {
            case .idle, .loading:
                VStack { Spacer(); ProgressView().tint(.brindooCoral); Spacer() }
            case .empty:
                emptyView
            case .error(let message):
                BrindooErrorState(message: message) {
                    Task { await load() }
                }
            case .loaded(let offers):
                list(offers)
            }
        }
        .background(Color.brindooBackground)
        .navigationTitle("Offerte salvate")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private var emptyView: some View {
        BrindooEmptyState(
            icon: "heart",
            title: "Nessuna offerta salvata",
            message: "Tocca il cuore su un'offerta per salvarla qui",
            actionTitle: "Esplora la bacheca",
            action: { DeepLinkRouter.shared.selectedTab = 0 }
        )
    }

    @ViewBuilder
    private func list(_ offers: [ServiceOffer]) -> some View {
        ScrollView {
            LazyVStack(spacing: BrindooSpacing.md) {
                ForEach(offers) { offer in
                    NavigationLink {
                        OfferDetailView(offer: offer) {
                            Task { await load() }
                        }
                    } label: {
                        OfferCard(
                            offer: offer,
                            categories: categories[offer.id] ?? [],
                            organizer: organizers[offer.organizerId],
                            showOrganizer: true,
                            activeProposal: nil
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(BrindooSpacing.md)
        }
    }

    private func load() async {
        if state.value == nil { state = .loading }
        do {
            let offers = try await OfferFavoriteService.shared.fetchMyFavorites()
            await loadRelated(for: offers)
            state = offers.isEmpty ? .empty : .loaded(offers)
        } catch {
            BrindooLog.error("Errore caricamento preferiti: \(error)")
            // Se una lista era già a schermo non la copriamo con l'errore.
            if state.value == nil {
                state = .error(BrindooText.loadError("le offerte salvate"))
            }
        }
    }

    /// Due richieste in tutto: i professionisti mancanti e le categorie delle
    /// offerte mancanti.
    ///
    /// Prima ne partiva una per offerta, e due offerte dello stesso
    /// professionista ne chiedevano il profilo due volte: il controllo
    /// "ce l'ho già" guardava una mappa che nessuna delle due aveva ancora
    /// riempito.
    private func loadRelated(for offers: [ServiceOffer]) async {
        let missingOrganizers = Set(offers.map { $0.organizerId }).subtracting(organizers.keys)
        let missingCategories = offers.map { $0.id }.filter { categories[$0] == nil }

        async let profiles = ProfileService.shared.fetchProfiles(ids: Array(missingOrganizers))
        async let categoryMap = ServiceOfferService.shared.fetchOfferCategoriesMap(offerIds: missingCategories)

        for profile in (try? await profiles) ?? [] {
            organizers[profile.id] = profile
        }
        let loaded = (try? await categoryMap) ?? [:]
        for offerId in missingCategories {
            categories[offerId] = loaded[offerId] ?? []
        }
    }
}
