//
//  OfferCard.swift
//  Brindoo
//
//  Card di un'offerta di servizio. Mostra:
//  - intestazione organizzatore (opzionale, lato cliente)
//  - titolo, descrizione, categorie, copertura, prezzo
//

import SwiftUI

struct OfferCard: View {
    let offer: ServiceOffer
    let categories: [ServiceCategory]
    let organizer: Profile?
    let showOrganizer: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.sm) {

            if let imageUrl = offer.imageUrl, let url = URL(string: imageUrl) {
                ZStack(alignment: .bottomTrailing) {
                    BrindooCachedImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .empty:
                            BrindooSkeleton(cornerRadius: BrindooRadius.sm)
                        default:
                            Color.brindooSurface
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipped()

                    BrindooGradient.glassOverlay
                        .frame(height: 60)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .allowsHitTesting(false)

                    Text(offer.priceDisplay)
                        .font(BrindooFont.bodyMedium.weight(.bold))
                        .brindooOverlayPill()
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
            }

            if showOrganizer, let organizer {
                HStack(spacing: BrindooSpacing.sm) {
                    AvatarView(url: organizer.avatarUrl, name: organizer.fullName, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(organizer.displayName)
                                .font(BrindooFont.bodyMedium.weight(.semibold))
                                .lineLimit(1)
                            if organizer.showsProBadge {
                                ProBadge()
                            }
                            if organizer.identityVerified {
                                VerifiedCheckIcon(size: 11)
                            }
                        }
                        Text(timeAgo(offer.createdAt))
                            .font(BrindooFont.caption)
                            .foregroundStyle(Color.brindooTextSecondary)
                    }
                    Spacer()
                    if offer.status == .paused {
                        statusBadge
                    }
                }
            }

            HStack(alignment: .top, spacing: BrindooSpacing.sm) {
                Text(offer.title)
                    .font(BrindooFont.titleSmall)
                    .foregroundStyle(Color.brindooTextPrimary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if offer.isNew {
                    NewOfferBadge()
                }

                if !showOrganizer {
                    statusBadge
                }
            }

            Text(offer.description)
                .font(BrindooFont.bodySmall)
                .foregroundStyle(Color.brindooTextSecondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !categories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: BrindooSpacing.xxs) {
                        ForEach(categories) { cat in
                            HStack(spacing: 3) {
                                Image(systemName: cat.icon).font(.system(size: 10))
                                Text(cat.name).font(BrindooFont.caption.weight(.medium))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .foregroundStyle(cat.tint)
                            .background(cat.tint.opacity(0.12))
                            .clipShape(Capsule())
                        }
                    }
                }
            }

            HStack(spacing: BrindooSpacing.md) {
                HStack(spacing: 4) {
                    Image(systemName: BrindooIcon.location).font(.system(size: 11))
                    Text(offer.coverageArea)
                        .font(BrindooFont.caption)
                        .lineLimit(1)
                }
                Spacer()
                Text(offer.priceDisplay)
                    .font(BrindooFont.bodySmall.weight(.semibold))
                    .foregroundStyle(Color.brindooCoral)
            }
            .foregroundStyle(Color.brindooTextSecondary)
        }
        .padding(BrindooSpacing.md)
        .brindooSurfaceBackground()
        .overlay(
            RoundedRectangle(cornerRadius: BrindooRadius.md)
                .strokeBorder(Color.brindooBorder, lineWidth: 1)
        )
    }

    private var statusBadge: some View {
        BrindooDotBadge(offer.status.displayName, color: offer.status.tint)
    }

    private func timeAgo(_ date: Date) -> String {
        BrindooFormat.timeAgoShort(date)
    }
}
