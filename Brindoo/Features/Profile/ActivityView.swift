//
//  ActivityView.swift
//  Brindoo
//
//  Riepilogo delle novità: trattative da gestire, eventi in arrivo,
//  messaggi non letti, ultime recensioni. Aggrega dati già esistenti.
//

import SwiftUI

struct ActivityView: View {

    @Environment(SessionStore.self) private var session

    @State private var proposals: [OfferProposal] = []
    @State private var offerTitles: [UUID: String] = [:]
    @State private var unreadCount: Int = 0
    @State private var recentReviews: [Review] = []
    @State private var isLoading: Bool = true

    // Novità dai preferiti (lato cliente)
    @State private var favoriteNews: [ServiceOffer] = []
    @State private var favoriteNames: [UUID: String] = [:]

    private var me: UUID? { session.userID }
    private var isOrganizer: Bool { session.currentProfile?.role == .organizer }

    private var toHandle: [OfferProposal] {
        guard let me else { return [] }
        return proposals.filter { $0.awaitingAction(by: me) }
    }

    private var upcomingEvents: [OfferProposal] {
        proposals.filter {
            $0.status == .accepted
            && $0.effectiveBooking != .cancelled
            && !$0.isEventPast
            && ($0.eventDate?.isEmpty == false)
        }
        .sorted { ($0.eventDate ?? "") < ($1.eventDate ?? "") }
    }

    var body: some View {
        Group {
            if isLoading {
                ScrollView {
                    LazyVStack(spacing: BrindooSpacing.sm) {
                        ForEach(0..<5, id: \.self) { _ in BrindooSkeletonCard() }
                    }
                    .padding(BrindooSpacing.md)
                }
                .disabled(true)
            } else if isEmptyState {
                emptyView
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: BrindooSpacing.lg) {
                        if !toHandle.isEmpty {
                            section(title: "Da gestire", icon: "exclamationmark.bubble.fill", color: .brindooCoral) {
                                ForEach(toHandle) { p in
                                    row(icon: "arrow.left.arrow.right",
                                        title: offerTitles[p.offerId] ?? "Trattativa",
                                        subtitle: "Aspetta una tua risposta · \(p.currentPriceDisplay)") {
                                        DeepLinkRouter.shared.selectedTab = 1
                                    }
                                }
                            }
                        }

                        if unreadCount > 0 {
                            section(title: "Messaggi", icon: "bubble.left.and.bubble.right.fill", color: .brindooSuccess) {
                                row(icon: "envelope.badge.fill",
                                    title: "\(unreadCount) messaggi non letti",
                                    subtitle: "Apri la chat per leggerli") {
                                    DeepLinkRouter.shared.selectedTab = 2
                                }
                            }
                        }

                        if !upcomingEvents.isEmpty {
                            section(title: "Eventi in arrivo", icon: "calendar", color: .brindooWarning) {
                                ForEach(upcomingEvents) { p in
                                    row(icon: "calendar",
                                        title: offerTitles[p.offerId] ?? "Evento",
                                        subtitle: p.eventDateDisplay ?? "") {
                                        DeepLinkRouter.shared.selectedTab = 1
                                    }
                                }
                            }
                        }

                        if !isOrganizer && !favoriteNews.isEmpty {
                            section(title: "Novità dai tuoi preferiti", icon: "heart.fill", color: .brindooCoral) {
                                ForEach(favoriteNews) { offer in
                                    favoriteNewsRow(offer)
                                }
                            }
                        }

                        if isOrganizer && !recentReviews.isEmpty {
                            section(title: "Ultime recensioni", icon: "star.fill", color: .brindooCoral) {
                                ForEach(recentReviews) { r in
                                    row(icon: "star.fill",
                                        title: "\(r.rating)★ · \(r.createdAtDisplay)",
                                        subtitle: r.comment ?? "Nessun commento",
                                        action: nil)
                                }
                            }
                        }
                    }
                    .padding(BrindooSpacing.md)
                    .brindooReadableWidth()
                }
            }
        }
        .background(Color.brindooBackground)
        .navigationTitle("Attività")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private var isEmptyState: Bool {
        toHandle.isEmpty && upcomingEvents.isEmpty && unreadCount == 0
            && recentReviews.isEmpty && favoriteNews.isEmpty
    }

    /// Nuova offerta pubblicata da un professionista salvato nei preferiti.
    @ViewBuilder
    private func favoriteNewsRow(_ offer: ServiceOffer) -> some View {
        NavigationLink {
            OfferDetailView(offer: offer)
        } label: {
            HStack(spacing: BrindooSpacing.sm) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.brindooCoral)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(offer.title)
                            .font(BrindooFont.bodyMedium.weight(.semibold))
                            .foregroundStyle(Color.brindooTextPrimary)
                            .lineLimit(1)
                        if offer.isNew { NewOfferBadge() }
                    }
                    Text("\(favoriteNames[offer.organizerId] ?? "Un tuo preferito") · \(offer.priceDisplay)")
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.brindooTextSecondary)
            }
            .padding(BrindooSpacing.md)
            .background(Color.brindooSurface)
            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var emptyView: some View {
        BrindooEmptyState(
            icon: "bell.badge",
            title: "Tutto tranquillo",
            message: "Qui troverai trattative da gestire, eventi in arrivo e messaggi non letti."
        )
    }

    @ViewBuilder
    private func section<Content: View>(
        title: String, icon: String, color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
            HStack(spacing: BrindooSpacing.xs) {
                Image(systemName: icon).font(.system(size: 14)).foregroundStyle(color)
                Text(title).font(BrindooFont.titleSmall)
            }
            content()
        }
    }

    @ViewBuilder
    private func row(icon: String, title: String, subtitle: String, action: (() -> Void)?) -> some View {
        let content = HStack(spacing: BrindooSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color.brindooCoral)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(BrindooFont.bodyMedium.weight(.semibold)).lineLimit(1)
                Text(subtitle).font(BrindooFont.caption).foregroundStyle(Color.brindooTextSecondary).lineLimit(2)
            }
            Spacer()
            if action != nil {
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.brindooTextSecondary)
            }
        }
        .padding(BrindooSpacing.md)
        .background(Color.brindooSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))

        if let action {
            Button(action: action) { content }.buttonStyle(.plain)
        } else {
            content
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        async let propsTask = OfferProposalService.shared.fetchMyOngoingProposals()
        async let unreadTask = ConversationService.shared.fetchUnreadCounts()

        proposals = (try? await propsTask) ?? []
        unreadCount = ((try? await unreadTask) ?? [:]).values.reduce(0, +)

        // Titoli offerte coinvolte (una sola richiesta).
        let missingTitleIds = Set(proposals.map { $0.offerId }).filter { offerTitles[$0] == nil }
        if let offers = try? await ServiceOfferService.shared.fetchOffers(ids: Array(missingTitleIds)) {
            for o in offers { offerTitles[o.id] = o.title }
        }

        if isOrganizer, let me {
            let all = (try? await ReviewService.shared.fetchReviews(organizerId: me)) ?? []
            recentReviews = Array(all.prefix(3))
        }

        // Cliente: nuove offerte (ultime 2 settimane) dei professionisti preferiti.
        if !isOrganizer {
            let favoriteIds = (try? await OrganizerFavoriteService.shared.fetchMyFavoriteOrganizerIds()) ?? []
            if !favoriteIds.isEmpty {
                let since = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
                let news = (try? await ServiceOfferService.shared.fetchRecentOffers(
                    fromOrganizers: Array(favoriteIds),
                    since: since
                )) ?? []
                favoriteNews = news

                let nameIds = Set(news.map(\.organizerId)).filter { favoriteNames[$0] == nil }
                if let profiles = try? await ProfileService.shared.fetchProfiles(ids: Array(nameIds)) {
                    for p in profiles { favoriteNames[p.id] = p.fullName ?? "Professionista" }
                }
            } else {
                favoriteNews = []
            }
        }
    }
}
