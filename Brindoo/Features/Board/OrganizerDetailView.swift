//
//  OrganizerDetailView.swift
//  Brindoo
//

import SwiftUI

struct OrganizerDetailView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session

    let organizer: Profile
    var isPreview: Bool = false

    @State private var categories: [OrganizerCategoryDetail] = []
    @State private var portfolioItems: [PortfolioItem] = []
    /// Giorni occupati del professionista ("yyyy-MM-dd"), per il calendario.
    @State private var unavailableDays: Set<String> = []
    @State private var reviewSummary: ReviewSummary?
    @State private var navigateToChat: Conversation?
    @State private var isStartingChat: Bool = false
    @State private var isBlocked: Bool = false
    @State private var showBlockConfirm: Bool = false
    @State private var showAvatarFullScreen: Bool = false
    @State private var showReport: Bool = false
    @State private var isFavorite: Bool = false
    @State private var isFavoriteSaving: Bool = false

    // Profilo a schede
    private enum ProfileTab: String, CaseIterable, Identifiable {
        case about = "Presentazione"
        case portfolio = "Portfolio"
        case reviews = "Recensioni"
        var id: String { rawValue }
    }
    @State private var selectedTab: ProfileTab = .about

    // Distintivi e cartolina di condivisione
    @State private var verifiedReviewCount: Int = 0
    @State private var isPreparingShare: Bool = false
    @State private var shareItems: SharePayload?

    private struct SharePayload: Identifiable {
        let id = UUID()
        let items: [Any]
    }

    private var isViewingOwn: Bool {
        session.userID == organizer.id
    }

    private var badges: [AchievementBadge] {
        AchievementBadge.earned(
            reviewCount: reviewSummary?.reviewCount ?? 0,
            avgRating: reviewSummary?.avgRating ?? 0,
            verifiedReviewCount: verifiedReviewCount,
            portfolioCount: portfolioItems.count,
            memberSince: organizer.createdAt,
            responseSpeed: organizer.responseSpeed
        )
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                heroSection

                VStack(alignment: .leading, spacing: BrindooSpacing.lg) {
                    OrganizerTitleSection(organizer: organizer)

                    AchievementBadgeRow(badges: badges)
                        .padding(.horizontal, -BrindooSpacing.md)

                    tabPicker

                    switch selectedTab {
                    case .about:     aboutTab
                    case .portfolio: portfolioTab
                    case .reviews:   reviewsTab
                    }

                    if !isViewingOwn && !isPreview {
                        actionsSection
                    }

                    if isPreview {
                        OrganizerPreviewBanner()
                    }
                }
                .padding(.horizontal, BrindooSpacing.md)
                .padding(.top, BrindooSpacing.md)
                .padding(.bottom, BrindooSpacing.xl)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Color.brindooBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isPreview {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await prepareShareCard() }
                    } label: {
                        if isPreparingShare {
                            ProgressView()
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.brindooCoral)
                        }
                    }
                    .disabled(isPreparingShare)
                    .accessibilityLabel("Condividi profilo")
                }
            }
            if !isPreview && !isViewingOwn {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await toggleFavorite() }
                    } label: {
                        Image(systemName: isFavorite ? BrindooIcon.heartFilled : BrindooIcon.heart)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(isFavorite ? Color.brindooCoral : Color.brindooTextSecondary)
                            .scaleEffect(isFavorite ? 1.1 : 1.0)
                            .animation(BrindooAnimation.bouncy, value: isFavorite)
                    }
                    .disabled(isFavoriteSaving)
                    .accessibilityLabel(isFavorite ? "Rimuovi dai preferiti" : "Aggiungi ai preferiti")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if isBlocked {
                            Button {
                                Task { await unblock() }
                            } label: {
                                Label("Sblocca", systemImage: "hand.raised")
                            }
                        } else {
                            Button(role: .destructive) {
                                showBlockConfirm = true
                            } label: {
                                Label("Blocca utente", systemImage: "hand.raised.slash")
                            }
                        }

                        Divider()

                        Button(role: .destructive) {
                            showReport = true
                        } label: {
                            Label("Segnala profilo", systemImage: "exclamationmark.bubble")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .foregroundStyle(Color.brindooCoral)
                    }
                }
            }
        }
        .task {
            await loadData()
            isBlocked = BlockService.shared.isBlockingOrBlocked(organizer.id)
            if !isViewingOwn && !isPreview {
                await AnalyticsService.shared.trackProfileView(profileId: organizer.id)
                isFavorite = (try? await OrganizerFavoriteService.shared.isFavorite(organizerId: organizer.id)) ?? false
            }
        }
        .navigationDestination(item: $navigateToChat) { conv in
            ChatView(conversation: conv, otherUser: organizer)
        }
        .alert("Bloccare \(organizer.displayName)?", isPresented: $showBlockConfirm) {
            Button("Annulla", role: .cancel) {}
            Button("Blocca", role: .destructive) {
                Task { await block() }
            }
        }
        .fullScreenCover(isPresented: $showAvatarFullScreen) {
            AvatarFullScreenView(url: organizer.avatarUrl, name: organizer.fullName) {
                showAvatarFullScreen = false
            }
        }
        .sheet(isPresented: $showReport) {
            ReportSheet(
                targetType: .user,
                targetId: organizer.id,
                targetLabel: organizer.fullName ?? "questo profilo"
            )
        }
        .sheet(item: $shareItems) { payload in
            ActivityShareSheet(items: payload.items)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Schede

    @ViewBuilder
    private var tabPicker: some View {
        Picker("Sezione", selection: $selectedTab) {
            ForEach(ProfileTab.allCases) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    /// Scheda "Presentazione": bio, servizi e zone coperte.
    @ViewBuilder
    private var aboutTab: some View {
        if organizer.isOnVacation {
            OrganizerVacationBanner(organizer: organizer)
        }

        if let bio = organizer.bio, !bio.isEmpty {
            OrganizerBioSection(bio: bio)
        }

        if !categories.isEmpty {
            OrganizerCategoriesSection(categories: categories)
        }

        OrganizerCoverageSection(organizer: organizer)

        if !organizer.faqs.isEmpty {
            OrganizerFAQsSection(faqs: organizer.faqs)
        }

        // Disponibilità: i clienti vedono i giorni occupati prima di scrivere.
        if !isViewingOwn && !unavailableDays.isEmpty {
            VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
                Text("Disponibilità")
                    .font(BrindooFont.titleSmall)
                AvailabilityCalendarView(unavailableDays: unavailableDays)
            }
        }

        if (organizer.bio ?? "").isEmpty && categories.isEmpty {
            OrganizerTabEmptyHint(icon: "person.text.rectangle", text: "Il professionista non ha ancora completato la presentazione.")
        }
    }

    /// Scheda "Portfolio": griglia di foto.
    @ViewBuilder
    private var portfolioTab: some View {
        if portfolioItems.isEmpty {
            OrganizerTabEmptyHint(icon: "photo.on.rectangle.angled", text: "Nessuna foto nel portfolio, per ora.")
        } else {
            VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: BrindooSpacing.xs), count: 3),
                    spacing: BrindooSpacing.xs
                ) {
                    ForEach(portfolioItems.prefix(9)) { item in
                        AsyncImage(url: URL(string: item.imageUrl)) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Color.brindooBorder
                        }
                        .frame(height: 110)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
                    }
                }

                NavigationLink {
                    PortfolioGalleryView(organizerId: organizer.id, isOwner: false)
                } label: {
                    Text(portfolioItems.count > 9
                         ? "Vedi tutte le \(portfolioItems.count) foto"
                         : "Apri la galleria")
                        .font(BrindooFont.bodySmall.weight(.medium))
                        .foregroundStyle(Color.brindooCoral)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, BrindooSpacing.xs)
                }
            }
        }
    }

    /// Scheda "Recensioni".
    @ViewBuilder
    private var reviewsTab: some View {
        if let summary = reviewSummary, summary.totalReviews > 0 {
            OrganizerReviewsSummarySection(organizer: organizer, summary: summary)
        } else {
            OrganizerTabEmptyHint(icon: "star", text: "Ancora nessuna recensione. Sarà il primo evento a parlare!")
        }
    }

    // MARK: - Cartolina di condivisione

    /// Prepara l'immagine-cartolina e apre il foglio di condivisione
    /// (immagine + link insieme). Se qualcosa va storto, condivide solo il link.
    private func prepareShareCard() async {
        isPreparingShare = true
        defer { isPreparingShare = false }

        let url = URL(string: "https://brindoo.app/p/\(organizer.id.uuidString)")!
        let avatar = await ShareCardRenderer.loadImage(from: organizer.avatarUrl)
        let card = ProfileShareCard(
            name: organizer.displayName,
            city: organizer.city,
            categories: categories.map { $0.category.name },
            rating: reviewSummary,
            isPro: organizer.isPro,
            avatar: avatar
        )

        if let image = ShareCardRenderer.render(card) {
            shareItems = SharePayload(items: [image, url])
        } else {
            shareItems = SharePayload(items: [url])
        }
    }

    // MARK: - Hero

    @ViewBuilder
    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            if let banner = portfolioItems.first?.imageUrl, let url = URL(string: banner) {
                ZStack(alignment: .bottom) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        BrindooGradient.coralSoft
                    }
                    .frame(height: 220)
                    .clipped()

                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: Color.brindooBackground.opacity(0.6), location: 0.7),
                            .init(color: Color.brindooBackground, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 220)
                }
            } else {
                LinearGradient(
                    stops: [
                        .init(color: Color.brindooCoral.opacity(0.35), location: 0.0),
                        .init(color: Color.brindooCoral.opacity(0.20), location: 0.4),
                        .init(color: Color.brindooCoral.opacity(0.08), location: 0.75),
                        .init(color: Color.brindooBackground, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 220)
            }

            Button {
                if organizer.avatarUrl?.isEmpty == false {
                    showAvatarFullScreen = true
                }
            } label: {
                AvatarView(url: organizer.avatarUrl, name: organizer.fullName, size: 120)
                    .overlay(Circle().strokeBorder(Color.brindooBackground, lineWidth: 4))
            }
            .buttonStyle(.plain)
            .offset(y: 50)
        }
        .padding(.bottom, 50)
    }

    @ViewBuilder
    private var actionsSection: some View {
        VStack(spacing: BrindooSpacing.xs) {
            BrindooButton(
                organizer.isOnVacation ? "Non disponibile" : "Invia messaggio",
                style: .primary,
                size: .large,
                isLoading: isStartingChat,
                isDisabled: isBlocked || organizer.isOnVacation
            ) {
                Task { await startChat() }
            }

            if isBlocked {
                Text("Hai bloccato questo utente")
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooError)
            }
        }
    }

    // MARK: - Actions

    private func loadData() async {
        do {
            categories = try await OrganizerCategoriesService.shared.fetchDetailed(organizerId: organizer.id)
        } catch { BrindooLog.error("\(error)") }

        do {
            portfolioItems = try await PortfolioService.shared.fetchPortfolio(organizerId: organizer.id)
        } catch { BrindooLog.error("\(error)") }

        do {
            reviewSummary = try await ReviewService.shared.fetchSummary(organizerId: organizer.id)
        } catch { BrindooLog.error("\(error)") }

        // Conteggio recensioni verificate: alimenta il distintivo "eventi verificati".
        if let reviews = try? await ReviewService.shared.fetchReviews(organizerId: organizer.id) {
            verifiedReviewCount = reviews.filter(\.isVerified).count
        }

        // Giorni occupati per il calendario disponibilità (best-effort).
        if !isViewingOwn {
            unavailableDays = (try? await AvailabilityService.shared
                .fetchUnavailableDays(organizerId: organizer.id)) ?? []
        }
    }

    private func startChat() async {
        isStartingChat = true
        defer { isStartingChat = false }
        do {
            let conv: Conversation
            if session.currentProfile?.role == .client {
                conv = try await ConversationService.shared.findOrCreateConversationAsClient(organizerId: organizer.id)
            } else {
                conv = try await ConversationService.shared.findOrCreateConversationAsOrganizer(clientId: organizer.id)
            }
            navigateToChat = conv
        } catch { BrindooLog.error("\(error)") }
    }

    private func block() async {
        do {
            try await BlockService.shared.block(userId: organizer.id)
            isBlocked = true
            dismiss()
        } catch { BrindooLog.error("\(error)") }
    }

    private func unblock() async {
        do {
            try await BlockService.shared.unblock(userId: organizer.id)
            isBlocked = false
        } catch { BrindooLog.error("\(error)") }
    }

    private func toggleFavorite() async {
        guard !isFavoriteSaving else { return }
        isFavoriteSaving = true
        defer { isFavoriteSaving = false }
        let willBeFavorite = !isFavorite
        do {
            if willBeFavorite {
                try await OrganizerFavoriteService.shared.add(organizerId: organizer.id)
            } else {
                try await OrganizerFavoriteService.shared.remove(organizerId: organizer.id)
            }
            isFavorite = willBeFavorite
            BrindooHaptics.impact(willBeFavorite ? .medium : .light)
        } catch {
            BrindooLog.error("toggleFavorite: \(error)")
        }
    }
}
