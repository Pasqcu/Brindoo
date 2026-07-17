//
//  ProfileView.swift
//  Brindoo
//

import SwiftUI

struct ProfileView: View {

    @Environment(SessionStore.self) private var session

    @State private var showEditProfile: Bool = false
    @State private var showPublicPreview: Bool = false
    @State private var showBoardPreview: Bool = false
    @State private var showPortfolio: Bool = false
    @State private var showAvailability: Bool = false
    @State private var showFAQs: Bool = false
    @State private var showAvatarFullScreen: Bool = false
    @State private var organizerCategories: [OrganizerCategoryDetail] = []
    @State private var reviewSummary: ReviewSummary?
    @State private var portfolioCount: Int = 0
    @State private var activeOffersCount: Int = 0

    private var isOrganizer: Bool {
        session.currentProfile?.role == .organizer
    }

    /// Quanto è curato il profilo del professionista (barra + suggerimenti).
    private var completion: ProfileCompletion? {
        guard isOrganizer, let profile = session.currentProfile else { return nil }
        return ProfileCompletion.evaluate(
            hasAvatar: profile.avatarUrl?.isEmpty == false,
            bioLength: (profile.bio ?? "").trimmingCharacters(in: .whitespacesAndNewlines).count,
            categoriesCount: organizerCategories.count,
            portfolioCount: portfolioCount,
            activeOffersCount: activeOffersCount,
            coverageAreasCount: profile.coverageAreas.count
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let profile = session.currentProfile {
                    VStack(spacing: BrindooSpacing.lg) {
                        headerSection(profile)

                        if let completion, !completion.isComplete {
                            ProfileCompletionCard(completion: completion) {
                                showEditProfile = true
                            }
                        }

                        if let bio = profile.bio, !bio.isEmpty {
                            bioSection(bio)
                        }

                        activityLink

                        negotiationsLink

                        // Preferiti (per i clienti)
                        if !isOrganizer {
                            favoritesLink
                        }

                        // Statistiche (solo organizzatori Pro)
                        if isOrganizer && profile.isPro {
                            statsLink
                        }

                        if isOrganizer {
                            if !organizerCategories.isEmpty {
                                categoriesSection
                            }

                            if let summary = reviewSummary, summary.totalReviews > 0 {
                                reviewsSection(summary)
                            }

                            HStack(spacing: BrindooSpacing.sm) {
                                actionMiniCard(
                                    icon: "photo.stack",
                                    title: "Portfolio",
                                    subtitle: portfolioCount > 0 ? "\(portfolioCount) elementi" : "Aggiungi foto"
                                ) {
                                    showPortfolio = true
                                }

                                actionMiniCard(
                                    icon: "eye",
                                    title: "Anteprima",
                                    subtitle: "Profilo pubblico"
                                ) {
                                    showPublicPreview = true
                                }
                            }

                            availabilityLink

                            faqsLink

                            boardPreviewLink
                        }

                        // Modifica profilo IN FONDO
                        Button {
                            showEditProfile = true
                        } label: {
                            HStack(spacing: BrindooSpacing.sm) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Modifica profilo")
                                    .font(BrindooFont.bodyLarge.weight(.semibold))
                            }
                            .foregroundStyle(Color.brindooCoral)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, BrindooSpacing.md)
                            .background(Color.brindooCoral.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: BrindooRadius.md)
                                    .strokeBorder(Color.brindooCoral.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(BrindooSpacing.md)
                }
            }
            .background(Color.brindooBackground)
            .navigationTitle("Il mio profilo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.brindooCoral)
                    }
                    .accessibilityLabel("Impostazioni")
                }
            }
            .task { await loadData() }
            .refreshable { await loadData() }
            .sheet(isPresented: $showEditProfile, onDismiss: {
                Task { await loadData() }
            }) {
                EditProfileView()
            }
            .sheet(isPresented: $showPublicPreview) {
                if let profile = session.currentProfile {
                    NavigationStack {
                        OrganizerDetailView(organizer: profile, isPreview: true)
                    }
                    .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $showBoardPreview) {
                NavigationStack {
                    BoardView(clientPreview: true)
                }
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showPortfolio) {
                if let userId = session.userID {
                    NavigationStack {
                        PortfolioGalleryView(organizerId: userId, isOwner: true)
                    }
                }
            }
            .sheet(isPresented: $showAvailability) {
                AvailabilityView()
            }
            .sheet(isPresented: $showFAQs) {
                EditFAQsView()
            }
            .fullScreenCover(isPresented: $showAvatarFullScreen) {
                AvatarFullScreenView(
                    url: session.currentProfile?.avatarUrl,
                    name: session.currentProfile?.fullName
                ) {
                    showAvatarFullScreen = false
                }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func headerSection(_ profile: Profile) -> some View {
        VStack(spacing: BrindooSpacing.sm) {
            Button {
                showAvatarFullScreen = true
            } label: {
                AvatarView(url: profile.avatarUrl, name: profile.fullName, size: 110)
            }
            .buttonStyle(.plain)

            VStack(spacing: 4) {
                HStack(spacing: BrindooSpacing.xs) {
                    Text(profile.fullName ?? "Senza nome")
                        .font(BrindooFont.titleLarge)
                    if profile.isPro {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Color.brindooCoral)
                    }
                }

                roleBadge(for: profile.role)

                if let city = profile.city {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse").font(.system(size: 12))
                        Text(city).font(BrindooFont.bodySmall)
                    }
                    .foregroundStyle(Color.brindooTextSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BrindooSpacing.md)
    }

    @ViewBuilder
    private func roleBadge(for role: UserRole) -> some View {
        HStack(spacing: 4) {
            Image(systemName: role.iconName)
                .font(.system(size: 10, weight: .semibold))
            Text(role.displayName)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, BrindooSpacing.sm)
        .padding(.vertical, 4)
        .background(role == .organizer ? Color.brindooCoral : Color.blue)
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var favoritesLink: some View {
        NavigationLink {
            FavoriteOffersView()
        } label: {
            navLinkRow(
                icon: "heart.fill",
                background: Color.brindooCoral,
                title: "Offerte salvate",
                subtitle: "Le offerte che hai aggiunto ai preferiti"
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var statsLink: some View {
        NavigationLink {
            OrganizerStatsView()
        } label: {
            navLinkRow(
                icon: "chart.bar.fill",
                background: Color.brindooSuccess,
                title: "Statistiche",
                subtitle: "Visite profilo, offerte, proposte (ultimi 30 giorni)"
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func navLinkRow(icon: String, background: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: BrindooSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(background)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BrindooFont.bodyMedium.weight(.semibold))
                    .foregroundStyle(Color.brindooTextPrimary)
                Text(subtitle)
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooTextSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.brindooTextSecondary)
        }
        .padding(BrindooSpacing.md)
        .background(Color.brindooSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
    }

    @ViewBuilder
    private var availabilityLink: some View {
        Button {
            showAvailability = true
        } label: {
            navLinkRow(
                icon: "calendar",
                background: Color.brindooWarning,
                title: "Disponibilità",
                subtitle: "Segna i giorni in cui non sei disponibile"
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var faqsLink: some View {
        Button {
            showFAQs = true
        } label: {
            navLinkRow(
                icon: "questionmark.bubble.fill",
                background: Color.blue,
                title: "Domande frequenti",
                subtitle: "Risposte pronte per i clienti (max 5)"
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var boardPreviewLink: some View {
        Button {
            showBoardPreview = true
        } label: {
            navLinkRow(
                icon: "rectangle.stack.badge.person.crop",
                background: Color.blue,
                title: "Anteprima bacheca",
                subtitle: "Vedi come ti vedono i clienti che cercano"
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var activityLink: some View {
        NavigationLink {
            ActivityView()
        } label: {
            navLinkRow(
                icon: "bell.badge.fill",
                background: Color.brindooSuccess,
                title: "Attività",
                subtitle: "Novità, eventi in arrivo e cose da gestire"
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var negotiationsLink: some View {
        NavigationLink {
            NegotiationsView()
        } label: {
            HStack(spacing: BrindooSpacing.sm) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.brindooCoral)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Trattative attive")
                        .font(BrindooFont.bodyMedium.weight(.semibold))
                        .foregroundStyle(Color.brindooTextPrimary)
                    Text("Proposte e controproposte sulle offerte")
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.brindooTextSecondary)
            }
            .padding(BrindooSpacing.md)
            .background(Color.brindooSurface)
            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func bioSection(_ bio: String) -> some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
            Text("Chi sono")
                .font(BrindooFont.titleSmall)
            Text(bio)
                .font(BrindooFont.bodyMedium)
                .foregroundStyle(Color.brindooTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BrindooSpacing.md)
        .background(Color.brindooSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
    }

    @ViewBuilder
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
            Text("Servizi offerti")
                .font(BrindooFont.titleSmall)

            VStack(spacing: BrindooSpacing.xs) {
                ForEach(organizerCategories) { detail in
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
    private func reviewsSection(_ summary: ReviewSummary) -> some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
            Text("Recensioni")
                .font(BrindooFont.titleSmall)

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
    private func actionMiniCard(
        icon: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color.brindooCoral)
                Text(title)
                    .font(BrindooFont.bodyMedium.weight(.semibold))
                    .foregroundStyle(Color.brindooTextPrimary)
                Text(subtitle)
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooTextSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(BrindooSpacing.md)
            .background(Color.brindooSurface)
            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
        }
        .buttonStyle(.plain)
    }

    private func loadData() async {
        guard let userId = session.userID else { return }

        if isOrganizer {
            do {
                organizerCategories = try await OrganizerCategoriesService.shared.fetchDetailed(organizerId: userId)
            } catch { BrindooLog.error("\(error)") }

            do {
                reviewSummary = try await ReviewService.shared.fetchSummary(organizerId: userId)
            } catch { BrindooLog.error("\(error)") }

            do {
                let items = try await PortfolioService.shared.fetchPortfolio(organizerId: userId)
                portfolioCount = items.count
            } catch { BrindooLog.error("\(error)") }

            // Per la barra "profilo completo": quante offerte attive ha.
            if let offers = try? await ServiceOfferService.shared.fetchMyOffers() {
                activeOffersCount = offers.filter { $0.status == .active }.count
            }
        }
    }
}
