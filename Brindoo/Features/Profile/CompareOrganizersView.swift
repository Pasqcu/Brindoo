//
//  CompareOrganizersView.swift
//  Brindoo
//
//  Confronto fianco a fianco di 2-3 professionisti salvati nei preferiti:
//  valutazione, velocità di risposta, prezzo di partenza, città.
//

import SwiftUI

struct CompareOrganizersView: View {

    @Environment(\.dismiss) private var dismiss

    let organizers: [Profile]

    @State private var ratings: [UUID: OrganizerRating] = [:]
    @State private var minPrices: [UUID: Double] = [:]
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Intestazioni: avatar + nome
                    compareRow { profile in
                        VStack(spacing: BrindooSpacing.xs) {
                            AvatarView(url: profile.avatarUrl, name: profile.fullName, size: 56)
                            Text(profile.displayName)
                                .font(BrindooFont.bodySmall.weight(.semibold))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                            if profile.isPro {
                                BrindooBadge("Pro", style: .pro, icon: BrindooIcon.crown)
                            }
                        }
                    }
                    .padding(.vertical, BrindooSpacing.md)

                    Divider()

                    labeledRow("Valutazione") { profile in
                        if let rating = ratings[profile.id] {
                            VStack(spacing: 2) {
                                HStack(spacing: 2) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.brindooWarning)
                                    Text(String(format: "%.1f", rating.avgRating))
                                        .font(BrindooFont.bodyMedium.weight(.semibold))
                                }
                                Text("\(rating.reviewCount) recensioni")
                                    .font(BrindooFont.caption)
                                    .foregroundStyle(Color.brindooTextSecondary)
                                if bestRatingId == profile.id {
                                    bestTag
                                }
                            }
                        } else {
                            placeholderDash
                        }
                    }

                    labeledRow("Risposta in chat") { profile in
                        if let speed = profile.responseSpeed {
                            VStack(spacing: 2) {
                                Image(systemName: speed.iconName)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.brindooSuccess)
                                Text(speed.label)
                                    .font(BrindooFont.caption)
                                    .multilineTextAlignment(.center)
                            }
                        } else {
                            placeholderDash
                        }
                    }

                    labeledRow("Identità") { profile in
                        if profile.identityVerified {
                            VStack(spacing: 2) {
                                VerifiedCheckIcon(size: 13)
                                Text("Verificata")
                                    .font(BrindooFont.caption)
                                    .foregroundStyle(Color.brindooTextSecondary)
                            }
                        } else {
                            placeholderDash
                        }
                    }

                    labeledRow("Prezzo da") { profile in
                        if let price = minPrices[profile.id] {
                            VStack(spacing: 2) {
                                Text(priceDisplay(price))
                                    .font(BrindooFont.bodyMedium.weight(.semibold))
                                    .foregroundStyle(Color.brindooCoral)
                                if bestPriceId == profile.id {
                                    bestTag
                                }
                            }
                        } else {
                            placeholderDash
                        }
                    }

                    labeledRow("Città") { profile in
                        Text(profile.city ?? "—")
                            .font(BrindooFont.bodySmall)
                            .multilineTextAlignment(.center)
                    }

                    // Apri i profili completi
                    compareRow { profile in
                        NavigationLink {
                            OrganizerDetailView(organizer: profile)
                        } label: {
                            Text("Vedi profilo")
                                .font(BrindooFont.caption.weight(.semibold))
                                .foregroundStyle(Color.brindooCoral)
                        }
                    }
                    .padding(.vertical, BrindooSpacing.md)
                }
                .padding(.horizontal, BrindooSpacing.md)
            }
            .background(Color.brindooBackground)
            .navigationTitle("Confronto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chiudi") { dismiss() }
                }
            }
            .overlay {
                if isLoading {
                    ProgressView().tint(.brindooCoral)
                }
            }
            .task { await load() }
        }
    }

    // MARK: - Righe

    /// Una riga del confronto: una colonna per professionista.
    @ViewBuilder
    private func compareRow<Content: View>(
        @ViewBuilder cell: @escaping (Profile) -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: BrindooSpacing.sm) {
            ForEach(organizers) { profile in
                cell(profile)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func labeledRow<Content: View>(
        _ label: String,
        @ViewBuilder cell: @escaping (Profile) -> Content
    ) -> some View {
        VStack(spacing: BrindooSpacing.xs) {
            Text(label)
                .font(BrindooFont.caption.weight(.semibold))
                .foregroundStyle(Color.brindooTextSecondary)
                .textCase(.uppercase)
            compareRow(cell: cell)
        }
        .padding(.vertical, BrindooSpacing.sm)
        Divider()
    }

    // MARK: - Migliore della riga

    /// Valutazione più alta (solo se c'è più di un valore da confrontare).
    private var bestRatingId: UUID? {
        guard ratings.count > 1 else { return nil }
        return ratings.max { $0.value.avgRating < $1.value.avgRating }?.key
    }

    /// Prezzo di partenza più basso (solo se c'è più di un valore).
    private var bestPriceId: UUID? {
        guard minPrices.count > 1 else { return nil }
        return minPrices.min { $0.value < $1.value }?.key
    }

    private var bestTag: some View {
        Text("Migliore")
            .font(.system(size: 9, weight: .bold))
            .textCase(.uppercase)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(Color.brindooSuccess)
            .background(Color.brindooSuccess.opacity(0.12))
            .clipShape(Capsule())
    }

    private var placeholderDash: some View {
        Text("—")
            .font(BrindooFont.bodySmall)
            .foregroundStyle(Color.brindooTextTertiary)
    }

    private func priceDisplay(_ value: Double) -> String {
        BrindooFormat.euro(value)
    }

    // MARK: - Dati

    private func load() async {
        defer { isLoading = false }

        // Valutazioni in parallelo.
        await withTaskGroup(of: (UUID, OrganizerRating?).self) { group in
            for profile in organizers {
                group.addTask {
                    (profile.id, try? await ReviewService.shared.fetchSummary(organizerId: profile.id))
                }
            }
            for await (id, rating) in group {
                if let rating { ratings[id] = rating }
            }
        }

        // Prezzo di partenza: offerta attiva più economica di ciascuno.
        if let offersMap = try? await ServiceOfferService.shared
            .fetchActiveOffers(forOrganizers: organizers.map(\.id)) {
            for (organizerId, offers) in offersMap {
                if let min = offers.map(\.price).min() {
                    minPrices[organizerId] = min
                }
            }
        }
    }
}
