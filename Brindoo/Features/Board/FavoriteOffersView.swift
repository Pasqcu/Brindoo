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
                BrindooEmptyState(
                    icon: "exclamationmark.triangle",
                    title: message,
                    message: "Controlla la connessione e riprova.",
                    actionTitle: "Riprova"
                ) {
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
                state = .error("Impossibile caricare le offerte salvate")
            }
        }
    }

    private func loadRelated(for offers: [ServiceOffer]) async {
        await withTaskGroup(of: Void.self) { group in
            for offer in offers {
                if organizers[offer.organizerId] == nil {
                    group.addTask {
                        if let p = try? await ProfileService.shared.fetchProfile(userID: offer.organizerId) {
                            await MainActor.run { organizers[offer.organizerId] = p }
                        }
                    }
                }
                if categories[offer.id] == nil {
                    group.addTask {
                        let cats = (try? await ServiceOfferService.shared.fetchOfferCategories(offerId: offer.id)) ?? []
                        await MainActor.run { categories[offer.id] = cats }
                    }
                }
            }
        }
    }
}
