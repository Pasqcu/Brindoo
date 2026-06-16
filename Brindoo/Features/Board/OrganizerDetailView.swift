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
    @State private var reviewSummary: ReviewSummary?
    @State private var navigateToChat: Conversation?
    @State private var isStartingChat: Bool = false
    @State private var isBlocked: Bool = false
    @State private var showBlockConfirm: Bool = false
    @State private var showAvatarFullScreen: Bool = false
    @State private var showReport: Bool = false
    @State private var isFavorite: Bool = false
    @State private var isFavoriteSaving: Bool = false

    private var isViewingOwn: Bool {
        session.userID == organizer.id
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                heroSection

                VStack(alignment: .leading, spacing: BrindooSpacing.lg) {
                    titleSection

                    if organizer.isOnVacation {
                        vacationBanner
                    }

                    if let bio = organizer.bio, !bio.isEmpty {
                        bioSection(bio)
                    }

                    if !categories.isEmpty {
                        categoriesSection
                    }

                    if !portfolioItems.isEmpty {
                        portfolioSection
                    }

                    if let summary = reviewSummary, summary.totalReviews > 0 {
                        reviewsSection(summary)
                    }

                    if !isViewingOwn && !isPreview {
                        actionsSection
                    }

                    if isPreview {
                        previewBanner
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
                    ShareLink(item: URL(string: "https://brindoo.app/p/\(organizer.id.uuidString)")!) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.brindooCoral)
                    }
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
        .alert("Bloccare \(organizer.fullName ?? "utente")?", isPresented: $showBlockConfirm) {
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
    private var titleSection: some View {
        VStack(spacing: BrindooSpacing.xxs) {
            HStack(spacing: BrindooSpacing.xs) {
                Text(organizer.fullName ?? "Senza nome")
                    .font(BrindooFont.titleLarge)
                if organizer.isPro {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.brindooCoral)
                }
            }

            Text(organizer.role.displayName)
                .font(BrindooFont.bodySmall)
                .foregroundStyle(Color.brindooTextSecondary)

            if let city = organizer.city {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse").font(.system(size: 12))
                    Text(city).font(BrindooFont.bodySmall)
                }
                .foregroundStyle(Color.brindooTextSecondary)
            }

            HStack(spacing: 4) {
                Image(systemName: "checkmark.shield.fill").font(.system(size: 11))
                Text("Su Brindoo dal \(memberSinceYear)")
                    .font(BrindooFont.caption)
            }
            .foregroundStyle(Color.brindooSuccess)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
    }

    private var memberSinceYear: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "yyyy"
        return f.string(from: organizer.createdAt)
    }

    @ViewBuilder
    private var vacationBanner: some View {
        HStack(spacing: BrindooSpacing.sm) {
            Image(systemName: "beach.umbrella.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.brindooWarning)
            VStack(alignment: .leading, spacing: 2) {
                Text("In vacanza")
                    .font(BrindooFont.bodyMedium.weight(.semibold))
                if let until = organizer.vacationUntilDisplay {
                    Text("Torna disponibile dal \(until)")
                        .font(BrindooFont.bodySmall)
                        .foregroundStyle(Color.brindooTextSecondary)
                }
            }
            Spacer()
        }
        .padding(BrindooSpacing.md)
        .background(Color.brindooWarning.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
    }

    @ViewBuilder
    private func bioSection(_ bio: String) -> some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
            HStack(spacing: 6) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.brindooCoral)
                Text("Chi sono")
                    .font(BrindooFont.titleSmall)
            }

            Text(bio)
                .font(BrindooFont.bodyMedium)
                .foregroundStyle(Color.brindooTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BrindooSpacing.md)
        .background(Color.brindooSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: BrindooRadius.md)
                .strokeBorder(Color.brindooCoral.opacity(0.25), lineWidth: 1.5)
        )
    }

    @ViewBuilder
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
            Text("Servizi offerti")
                .font(BrindooFont.titleSmall)

            VStack(spacing: BrindooSpacing.xs) {
                ForEach(categories) { detail in
                    HStack(alignment: .top, spacing: BrindooSpacing.sm) {
                        Image(systemName: detail.category.icon)
                            .font(.system(size: 18))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.brindooCoral)
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(detail.category.name)
                                .font(BrindooFont.bodyMedium.weight(.semibold))
                            if let desc = detail.description, !desc.isEmpty {
                                Text(desc)
                                    .font(BrindooFont.bodySmall)
                                    .foregroundStyle(Color.brindooTextSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer()
                    }
                    .padding(BrindooSpacing.sm)
                    .background(Color.brindooSurface)
                    .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
                }
            }
        }
    }

    @ViewBuilder
    private var portfolioSection: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
            HStack {
                Text("Portfolio")
                    .font(BrindooFont.titleSmall)
                Spacer()
                NavigationLink {
                    PortfolioGalleryView(organizerId: organizer.id, isOwner: false)
                } label: {
                    Text("Vedi tutto")
                        .font(BrindooFont.bodySmall.weight(.medium))
                        .foregroundStyle(Color.brindooCoral)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: BrindooSpacing.xs) {
                    ForEach(portfolioItems.prefix(8)) { item in
                        AsyncImage(url: URL(string: item.imageUrl)) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Color.brindooBorder
                        }
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func reviewsSection(_ summary: ReviewSummary) -> some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
            HStack {
                Text("Recensioni")
                    .font(BrindooFont.titleSmall)
                Spacer()
                NavigationLink {
                    ReviewsListView(organizer: organizer)
                } label: {
                    Text("Vedi tutte")
                        .font(BrindooFont.bodySmall.weight(.medium))
                        .foregroundStyle(Color.brindooCoral)
                }
            }

            HStack(spacing: BrindooSpacing.md) {
                VStack(spacing: 2) {
                    Text(String(format: "%.1f", summary.averageRating))
                        .font(BrindooFont.displayMedium)
                        .foregroundStyle(Color.brindooCoral)
                    StarRatingView(rating: summary.averageRating, size: 14)
                    Text("\(summary.totalReviews) \(summary.totalReviews == 1 ? "recensione" : "recensioni")")
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextSecondary)
                }
                Spacer()
            }
            .padding(BrindooSpacing.md)
            .background(Color.brindooSurface)
            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
        }
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

    @ViewBuilder
    private var previewBanner: some View {
        VStack(spacing: 6) {
            HStack(spacing: BrindooSpacing.xs) {
                Image(systemName: "eye")
                Text("Questa è l'anteprima del tuo profilo pubblico")
                    .font(BrindooFont.bodySmall)
            }
            .foregroundStyle(Color.brindooCoral)

            HStack(spacing: 3) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                Text("Scorri giù per chiudere")
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(Color.brindooTextSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(BrindooSpacing.md)
        .background(Color.brindooCoral.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
    }

    // MARK: - Actions

    private func loadData() async {
        do {
            categories = try await OrganizerCategoriesService.shared.fetchDetailed(organizerId: organizer.id)
        } catch { print("❌ \(error)") }

        do {
            portfolioItems = try await PortfolioService.shared.fetchPortfolio(organizerId: organizer.id)
        } catch { print("❌ \(error)") }

        do {
            reviewSummary = try await ReviewService.shared.fetchSummary(organizerId: organizer.id)
        } catch { print("❌ \(error)") }
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
        } catch { print("❌ \(error)") }
    }

    private func block() async {
        do {
            try await BlockService.shared.block(userId: organizer.id)
            isBlocked = true
            dismiss()
        } catch { print("❌ \(error)") }
    }

    private func unblock() async {
        do {
            try await BlockService.shared.unblock(userId: organizer.id)
            isBlocked = false
        } catch { print("❌ \(error)") }
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
            print("❌ toggleFavorite: \(error)")
        }
    }
}
