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
            state = .error(error.localizedDescription)
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
                    BrindooEmptyState(
                        icon: BrindooIcon.error,
                        title: "Errore di caricamento",
                        message: message,
                        actionTitle: "Riprova"
                    ) {
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

    private var header: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.xxs) {
            Text("Ciao, \(session.currentProfile?.fullName ?? "Organizer") 👋")
                .font(BrindooFont.titleMedium)
            Text("Ecco un riepilogo della tua attività.")
                .font(BrindooFont.bodySmall)
                .foregroundStyle(Color.brindooTextSecondary)
        }
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
            BrindooStatTile(
                icon: BrindooIcon.send,
                value: "\(s.sentOffers)",
                label: "Offerte inviate"
            )
            BrindooStatTile(
                icon: BrindooIcon.success,
                value: "\(s.acceptedOffers)",
                label: "Accettate",
                tint: .brindooSuccess
            )
            BrindooStatTile(
                icon: BrindooIcon.chart,
                value: percent(s.conversionRate),
                label: "Conversione",
                tint: .blue
            )
            BrindooStatTile(
                icon: BrindooIcon.starFilled,
                value: String(format: "%.1f", s.avgRating),
                label: "\(s.reviewsCount) recensioni",
                tint: .brindooWarning
            )
            BrindooStatTile(
                icon: BrindooIcon.chat,
                value: "\(s.unreadMessages)",
                label: "Messaggi non letti",
                tint: .brindooCoral
            )
            BrindooStatTile(
                icon: BrindooIcon.profile,
                value: "\(s.profileViews)",
                label: "Visite profilo",
                tint: .purple
            )
        }
    }

    @ViewBuilder
    private func insightsCard(_ s: OrganizerDashboardStats) -> some View {
        if s.sentOffers > 0 && s.conversionRate < 0.2 {
            BrindooBanner(
                style: .warning,
                title: "Conversione bassa",
                message: "Prova a personalizzare di più le tue offerte: chi riceve un messaggio dedicato accetta il doppio delle volte."
            )
        } else if s.sentOffers == 0 {
            BrindooBanner(
                style: .info,
                title: "Pubblica la tua prima offerta",
                message: "Crea un'offerta dalla bacheca per farti trovare dai clienti."
            )
        } else if s.avgRating >= 4.5 {
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
