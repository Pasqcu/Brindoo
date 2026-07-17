//
//  BoardCards.swift
//  Brindoo
//
//  Card usate nella bacheca cliente: professionista con offerte annidate
//  e card compatta della vetrina "In evidenza". (Estratte da BoardView.)
//

import SwiftUI

// MARK: - Etichetta "Nuovo" (offerte fresche, < 7 giorni)

struct NewOfferBadge: View {
    var body: some View {
        Text("NUOVO")
            .font(.system(size: 9, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(BrindooGradient.coralSoft)
            .clipShape(Capsule())
            .accessibilityLabel("Offerta nuova")
    }
}

// MARK: - Card professionista con offerte annidate (cliente)

struct OrganizerWithOffersCard: View {

    let organizer: Profile
    let categories: [ServiceCategory]
    let offers: [ServiceOffer]
    var rating: OrganizerRating? = nil

    private let previewCount = 2

    private var coverImageUrl: String? {
        offers.first(where: { ($0.imageUrl?.isEmpty == false) })?.imageUrl
    }

    private var minPrice: Double? {
        offers.map(\.price).min()
    }

    private var minPriceDisplay: String? {
        guard let minPrice else { return nil }
        return BrindooFormat.euro(minPrice)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
            if let cover = coverImageUrl, let url = URL(string: cover) {
                ZStack(alignment: .bottomLeading) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFill()
                        case .empty: BrindooSkeleton(cornerRadius: BrindooRadius.sm)
                        default: Color.brindooSurface
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
                    .clipped()

                    BrindooGradient.glassOverlay
                        .frame(height: 70)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .allowsHitTesting(false)

                    if let price = minPriceDisplay {
                        Text("da \(price)")
                            .font(BrindooFont.bodyMedium.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, BrindooSpacing.sm)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .padding(BrindooSpacing.xs)
                    }
                }
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
            }

            HStack(spacing: BrindooSpacing.sm) {
                AvatarView(url: organizer.avatarUrl, name: organizer.fullName, size: 56)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(organizer.displayName)
                            .font(BrindooFont.titleSmall)
                            .lineLimit(1)
                        if organizer.isPro {
                            ProBadge()
                        }
                        if organizer.identityVerified {
                            VerifiedCheckIcon()
                        }
                        if let rating, rating.reviewCount > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill").font(.system(size: 10))
                                Text(String(format: "%.1f", rating.avgRating))
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundStyle(Color.brindooWarning)
                        }
                    }

                    if let city = organizer.city, !city.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 11))
                            Text(city)
                                .font(BrindooFont.caption)
                                .lineLimit(1)
                        }
                        .foregroundStyle(Color.brindooTextSecondary)
                    }

                    if let speed = organizer.responseSpeed {
                        HStack(spacing: 4) {
                            Image(systemName: speed.iconName)
                                .font(.system(size: 10))
                            Text(speed.label)
                                .font(BrindooFont.caption.weight(.medium))
                        }
                        .foregroundStyle(Color.brindooSuccess)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.brindooTextSecondary)
            }

            if !categories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(categories.prefix(4)) { cat in
                            HStack(spacing: 3) {
                                Image(systemName: cat.icon)
                                    .font(.system(size: 10, weight: .medium))
                                Text(cat.name)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(cat.tint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(cat.tint.opacity(0.12))
                            .clipShape(Capsule())
                        }
                        if categories.count > 4 {
                            Text("+\(categories.count - 4)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.brindooTextSecondary)
                        }
                    }
                }
            }

            if !offers.isEmpty {
                Divider()
                    .padding(.vertical, 2)

                VStack(spacing: BrindooSpacing.xs) {
                    ForEach(offers.prefix(previewCount)) { offer in
                        offerRow(offer)
                    }
                }

                if offers.count > previewCount {
                    Text("+\(offers.count - previewCount) altre offerte")
                        .font(BrindooFont.caption.weight(.medium))
                        .foregroundStyle(Color.brindooCoral)
                        .padding(.top, 2)
                }
            }
        }
        .padding(BrindooSpacing.md)
        .background(Color.brindooSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: BrindooRadius.lg)
                .strokeBorder(Color.brindooBorder, lineWidth: 1)
        )
        .brindooCardShadow()
    }

    @ViewBuilder
    private func offerRow(_ offer: ServiceOffer) -> some View {
        HStack(alignment: .top, spacing: BrindooSpacing.sm) {
            Image(systemName: "tag.fill")
                .font(.system(size: 12))
                .foregroundStyle(Color.brindooCoral)
                .frame(width: 24, height: 24)
                .background(Color.brindooCoral.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(offer.title)
                        .font(BrindooFont.bodySmall.weight(.semibold))
                        .lineLimit(1)
                        .foregroundStyle(Color.brindooTextPrimary)
                    if offer.isNew {
                        NewOfferBadge()
                    }
                }
                Text(offer.coverageArea)
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooTextSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(offer.priceDisplay)
                .font(BrindooFont.bodySmall.weight(.semibold))
                .foregroundStyle(Color.brindooCoral)
        }
    }
}

// MARK: - Card "In evidenza" (vetrina boost)

struct FeaturedOrganizerCard: View {
    let organizer: Profile
    var rating: OrganizerRating?
    var coverImageUrl: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                if let cover = coverImageUrl, let url = URL(string: cover) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFill()
                        case .empty: BrindooSkeleton(cornerRadius: 0)
                        default: BrindooGradient.coralSoft
                        }
                    }
                } else {
                    BrindooGradient.coralSoft
                }

                HStack(spacing: 3) {
                    Image(systemName: "star.fill").font(.system(size: 9))
                    Text("In evidenza").font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(BrindooSpacing.xs)
            }
            .frame(width: 240, height: 130)
            .clipped()

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(organizer.displayName)
                        .font(BrindooFont.bodyMedium.weight(.semibold))
                        .lineLimit(1)
                    if organizer.isPro { ProBadge() }
                    if organizer.identityVerified { VerifiedCheckIcon() }
                }
                HStack(spacing: BrindooSpacing.xs) {
                    if let city = organizer.city, !city.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "mappin.and.ellipse").font(.system(size: 10))
                            Text(city).font(BrindooFont.caption).lineLimit(1)
                        }
                        .foregroundStyle(Color.brindooTextSecondary)
                    }
                    if let rating, rating.reviewCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill").font(.system(size: 9))
                            Text(String(format: "%.1f", rating.avgRating)).font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(Color.brindooWarning)
                    }
                }
            }
            .padding(BrindooSpacing.sm)
        }
        .frame(width: 240)
        .background(Color.brindooSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: BrindooRadius.lg)
                .strokeBorder(Color.brindooCoral.opacity(0.35), lineWidth: 1)
        )
        .brindooCardShadow()
    }
}
