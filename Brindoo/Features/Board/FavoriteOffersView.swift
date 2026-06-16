//
//  FavoriteOffersView.swift
//  Brindoo
//
//  Lista delle offerte salvate dal cliente corrente.
//

import SwiftUI

struct FavoriteOffersView: View {

    @State private var offers: [ServiceOffer] = []
    @State private var organizers: [UUID: Profile] = [:]
    @State private var categories: [UUID: [ServiceCategory]] = [:]
    @State private var isLoading: Bool = true

    var body: some View {
        Group {
            if isLoading {
                VStack { Spacer(); ProgressView().tint(.brindooCoral); Spacer() }
            } else if offers.isEmpty {
                emptyView
            } else {
                list
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
        VStack(spacing: BrindooSpacing.md) {
            Spacer()
            ZStack {
                Circle().fill(Color.brindooCoral.opacity(0.1)).frame(width: 100, height: 100)
                Image(systemName: "heart")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.brindooCoral)
            }
            Text("Nessuna offerta salvata")
                .font(BrindooFont.titleMedium)
            Text("Tocca il cuore su un'offerta per salvarla qui")
                .font(BrindooFont.bodyMedium)
                .foregroundStyle(Color.brindooTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, BrindooSpacing.xl)
            Spacer()
        }
    }

    @ViewBuilder
    private var list: some View {
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
        isLoading = true
        defer { isLoading = false }
        do {
            offers = try await OfferFavoriteService.shared.fetchMyFavorites()
            await loadRelated()
        } catch {
            print("❌ \(error)")
        }
    }

    private func loadRelated() async {
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
