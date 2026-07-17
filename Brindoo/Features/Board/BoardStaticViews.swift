//
//  BoardStaticViews.swift
//  Brindoo
//
//  Pezzi "senza stato" della bacheca (estratti da BoardView): banner,
//  vetrina In evidenza, invito, stati di vuoto/errore/caricamento.
//

import SwiftUI

// MARK: - Banner anteprima cliente

struct BoardPreviewBanner: View {
    var body: some View {
        HStack(spacing: BrindooSpacing.xs) {
            Image(systemName: "eye")
            Text("Stai vedendo la bacheca come la vedono i clienti.")
                .font(BrindooFont.caption)
            Spacer()
        }
        .foregroundStyle(Color.brindooCoral)
        .padding(.horizontal, BrindooSpacing.md)
        .padding(.vertical, BrindooSpacing.xs)
        .background(Color.brindooCoral.opacity(0.08))
    }
}

// MARK: - Invito a completare il profilo (professionista appena upgradato)

struct CompleteProfileHint: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: BrindooSpacing.sm) {
                Image(systemName: "exclamationmark.bubble.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.brindooCoral)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Completa il tuo profilo Professionista")
                        .font(BrindooFont.bodyMedium.weight(.semibold))
                        .foregroundStyle(Color.brindooTextPrimary)
                    Text("Aggiungi le categorie di servizio per essere trovato dai clienti.")
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextSecondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.brindooTextSecondary)
            }
            .padding(BrindooSpacing.md)
            .background(Color.brindooCoral.opacity(0.08))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Vetrina "In evidenza" (Boost attivo)

struct BoardFeaturedCarousel: View {
    let organizers: [Profile]
    let ratings: [UUID: OrganizerRating]
    let offersMap: [UUID: [ServiceOffer]]

    var body: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 13))
                Text("In evidenza")
                    .font(BrindooFont.titleSmall)
            }
            .foregroundStyle(Color.brindooCoral)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: BrindooSpacing.md) {
                    ForEach(organizers) { org in
                        NavigationLink {
                            OrganizerDetailView(organizer: org)
                        } label: {
                            FeaturedOrganizerCard(
                                organizer: org,
                                rating: ratings[org.id],
                                coverImageUrl: offersMap[org.id]?.first(where: { $0.imageUrl?.isEmpty == false })?.imageUrl
                            )
                        }
                        .buttonStyle(BrindooPressStyle())
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.top, BrindooSpacing.xs)
    }
}

// MARK: - Intestazione di scoperta

struct BoardDiscoveryHeader: View {
    let count: Int
    let hasMore: Bool

    var body: some View {
        HStack(spacing: BrindooSpacing.xs) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.brindooCoral)
            Text("\(count)\(hasMore ? "+" : "") professionisti consigliati per te")
                .font(BrindooFont.bodySmall.weight(.medium))
                .foregroundStyle(Color.brindooTextSecondary)
            Spacer()
        }
        .padding(.top, BrindooSpacing.xs)
    }
}

// MARK: - Invito a portare nuovi professionisti

struct BoardInviteCard: View {

    static let inviteMessage = "Ti ho trovato su Brindoo? 🎉 È l'app per organizzare feste ed eventi: crea il tuo profilo da professionista e fatti scegliere dai clienti del Lazio!"

    var body: some View {
        ShareLink(item: Self.inviteMessage) {
            HStack(spacing: BrindooSpacing.sm) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.brindooCoral)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Conosci un professionista?")
                        .font(BrindooFont.bodyMedium.weight(.semibold))
                        .foregroundStyle(Color.brindooTextPrimary)
                    Text("Invitalo su Brindoo e aiutalo a farsi trovare")
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextSecondary)
                }
                Spacer()
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.brindooCoral)
            }
            .padding(BrindooSpacing.md)
            .frame(maxWidth: .infinity)
            .background(Color.brindooCoral.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
        }
        .buttonStyle(.plain)
        .padding(.top, BrindooSpacing.xs)
    }
}

// MARK: - Vuoto / errore / caricamento

struct BoardEmptyView: View {
    let icon: String
    let title: String
    let subtitle: String
    let showClear: Bool
    let onClear: () -> Void

    var body: some View {
        VStack(spacing: BrindooSpacing.md) {
            BrindooEmptyState(
                icon: icon,
                title: title,
                message: subtitle,
                actionTitle: showClear ? "Rimuovi filtri" : nil,
                action: showClear ? onClear : nil
            )

            Text("Brindoo sta arrivando in tutto il Lazio. Aiutaci a crescere!")
                .font(BrindooFont.caption)
                .foregroundStyle(Color.brindooTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, BrindooSpacing.xl)

            ShareLink(item: BoardInviteCard.inviteMessage) {
                Label("Invita un professionista", systemImage: "person.badge.plus")
                    .font(BrindooFont.button)
                    .foregroundStyle(.white)
                    .frame(maxWidth: 260)
                    .padding(.vertical, BrindooSpacing.sm)
                    .background(Color.brindooCoral)
                    .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
            }
            .padding(.bottom, BrindooSpacing.xl)
        }
    }
}

struct BoardErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: BrindooSpacing.md) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.brindooWarning)
            Text(message)
                .font(BrindooFont.bodyMedium)
                .foregroundStyle(Color.brindooTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, BrindooSpacing.xl)
            BrindooButton("Riprova", style: .secondary, action: onRetry)
                .frame(maxWidth: 200)
            Spacer()
        }
    }
}

struct BoardLoadingSkeleton: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: BrindooSpacing.md) {
                ForEach(0..<6, id: \.self) { _ in
                    BrindooSkeletonCard()
                }
            }
            .padding(BrindooSpacing.md)
        }
        .disabled(true)
    }
}
