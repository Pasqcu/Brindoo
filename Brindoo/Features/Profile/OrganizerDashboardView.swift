//
//  OrganizerDashboardView.swift
//  Brindoo
//
//  Dashboard sintetica per organizer: statistiche, performance e azioni rapide.
//

import SwiftUI

struct OrganizerDashboardStats: Equatable {
    var sentOffers: Int
    var acceptedOffers: Int
    var conversionRate: Double
    var avgRating: Double
    var reviewsCount: Int
    var profileViews: Int
    var unreadMessages: Int
    var responseTimeMinutes: Int

    static let placeholder = OrganizerDashboardStats(
        sentOffers: 0, acceptedOffers: 0, conversionRate: 0,
        avgRating: 0, reviewsCount: 0, profileViews: 0,
        unreadMessages: 0, responseTimeMinutes: 0
    )
}

@MainActor
@Observable
final class OrganizerDashboardViewModel: BrindooViewModel {
    var state: LoadState<OrganizerDashboardStats> = .idle

    func load() async {
        state = .loading
        do {
            let stats = try await fetchStats()
            state = .loaded(stats)
        } catch {
            guard !BrindooErrorText.isCancellation(error) else { return }
            state = .error(BrindooErrorText.message(
                for: error,
                fallback: BrindooText.loadError("i tuoi numeri")
            ))
        }
    }

    func refresh() async { await load() }

    private func fetchStats() async throws -> OrganizerDashboardStats {
        let ongoing = (try? await OfferProposalService.shared.fetchMyOngoingProposals()) ?? []
        let sent = ongoing.count
        let accepted = ongoing.filter { $0.status == .accepted }.count
        let conversion = sent == 0 ? 0 : Double(accepted) / Double(sent)

        var avg: Double = 0
        var reviewsCount = 0
        if let userId = SupabaseManager.shared.currentUserID,
           let rating = try? await ReviewService.shared.fetchRating(organizerId: userId) {
            avg = rating.avgRating
            reviewsCount = rating.reviewCount
        }

        let unreadDict = (try? await ConversationService.shared.fetchUnreadCounts()) ?? [:]
        let unread = unreadDict.values.reduce(0, +)

        return OrganizerDashboardStats(
            sentOffers: sent,
            acceptedOffers: accepted,
            conversionRate: conversion,
            avgRating: avg,
            reviewsCount: reviewsCount,
            profileViews: 0,
            unreadMessages: unread,
            responseTimeMinutes: 0
        )
    }
}

struct OrganizerDashboardView: View {
    @State private var vm = OrganizerDashboardViewModel()
    @Environment(SessionStore.self) private var session

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrindooSpacing.lg) {
                header
                switch vm.state {
                case .idle, .loading:
                    skeleton
                case .empty:
                    BrindooEmptyState(title: "Nessun dato ancora", message: "Le tue statistiche compariranno qui appena inizi a ricevere richieste.")
                case .loaded(let stats):
                    statsGrid(stats)
                    insightsCard(stats)
                case .error(let message):
                    BrindooErrorState(message: message) {
                        Task { await vm.refresh() }
                    }
                }
            }
            .padding(BrindooSpacing.md)
        }
        .background(Color.brindooBackground)
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.large)
        .task { await vm.load() }
        .refreshable { await vm.refresh() }
    }

    /// Niente saluto: due righe di cortesia in cima alla schermata più
    /// consultata rubavano lo spazio ai numeri per cui la si apre.
    private var header: some View {
        Text("Situazione di adesso, non uno storico.")
            .font(BrindooFont.bodySmall)
            .foregroundStyle(Color.brindooTextSecondary)
    }

    private var skeleton: some View {
        VStack(spacing: BrindooSpacing.md) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: BrindooSpacing.md) {
                    BrindooSkeleton(cornerRadius: BrindooRadius.lg).frame(height: 110)
                    BrindooSkeleton(cornerRadius: BrindooRadius.lg).frame(height: 110)
                }
            }
        }
    }

    private func statsGrid(_ s: OrganizerDashboardStats) -> some View {
        let columns = [GridItem(.flexible(), spacing: BrindooSpacing.md),
                       GridItem(.flexible(), spacing: BrindooSpacing.md)]
        return LazyVGrid(columns: columns, spacing: BrindooSpacing.md) {
            // I nomi seguono il dato vero: qui si contano le trattative in
            // corso, non quante offerte sono state pubblicate.
            BrindooStatTile(
                icon: BrindooIcon.send,
                value: "\(s.sentOffers)",
                label: "Trattative aperte"
            )
            BrindooStatTile(
                icon: BrindooIcon.success,
                value: "\(s.acceptedOffers)",
                label: "Accordi chiusi",
                tint: .brindooSuccess
            )
            BrindooStatTile(
                icon: BrindooIcon.chart,
                value: Self.hasEnoughDeals(s) ? percent(s.conversionRate) : "—",
                label: "Accordi su trattative",
                tint: .blue
            )
            // Con zero recensioni "0,0" sembra un voto pessimo: è un dato
            // che manca, e va scritto che manca.
            BrindooStatTile(
                icon: BrindooIcon.starFilled,
                value: s.reviewsCount > 0 ? String(format: "%.1f", s.avgRating) : "—",
                label: s.reviewsCount > 0 ? "\(s.reviewsCount) recensioni" : "Nessuna recensione",
                tint: .brindooWarning
            )
            BrindooStatTile(
                icon: BrindooIcon.chat,
                value: "\(s.unreadMessages)",
                label: "Messaggi non letti",
                tint: .brindooCoral
            )
        }
    }

    /// Sotto questa soglia una percentuale non racconta niente: due
    /// trattative andate male darebbero "0%" a un professionista bravo.
    private static let minDealsForRate = 5

    private static func hasEnoughDeals(_ s: OrganizerDashboardStats) -> Bool {
        s.sentOffers >= minDealsForRate
    }

    @ViewBuilder
    private func insightsCard(_ s: OrganizerDashboardStats) -> some View {
        // L'avviso arriva solo quando c'è abbastanza storia alle spalle:
        // rimproverare chi ha appena iniziato lo fa solo smettere.
        if Self.hasEnoughDeals(s) && s.conversionRate < 0.2 {
            BrindooBanner(
                style: .warning,
                title: "Poche trattative chiuse",
                message: "Prova a personalizzare di più le tue offerte: chi riceve un messaggio dedicato accetta il doppio delle volte."
            )
        } else if s.sentOffers == 0 {
            BrindooBanner(
                style: .info,
                title: "Pubblica la tua prima offerta",
                message: "Crea un'offerta dalla bacheca per farti trovare dai clienti."
            )
        } else if s.reviewsCount >= 3 && s.avgRating >= 4.5 {
            BrindooBanner(
                style: .success,
                title: "Ottime recensioni!",
                message: "Continua così: i clienti notano i profili con valutazione alta."
            )
        }
    }

    private func percent(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .percent
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "0%"
    }
}
