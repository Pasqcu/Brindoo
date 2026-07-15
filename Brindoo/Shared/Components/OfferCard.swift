//
//  OfferCard.swift
//  Brindoo
//
//  Card di un'offerta di servizio. Mostra:
//  - intestazione organizzatore (opzionale, lato cliente)
//  - titolo, descrizione, categorie, copertura, prezzo
//  - eventuale badge della trattativa attiva del cliente
//

import SwiftUI

struct OfferCard: View {
    let offer: ServiceOffer
    let categories: [ServiceCategory]
    let organizer: Profile?
    let showOrganizer: Bool
    /// Trattativa attiva del cliente corrente su questa offerta (se esiste).
    let activeProposal: OfferProposal?

    init(
        offer: ServiceOffer,
        categories: [ServiceCategory],
        organizer: Profile?,
        showOrganizer: Bool,
        activeProposal: OfferProposal? = nil
    ) {
        self.offer = offer
        self.categories = categories
        self.organizer = organizer
        self.showOrganizer = showOrganizer
        self.activeProposal = activeProposal
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.sm) {

            if let imageUrl = offer.imageUrl, let url = URL(string: imageUrl) {
                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: url) { phase in
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
                        .foregroundStyle(.white)
                        .padding(.horizontal, BrindooSpacing.sm)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(BrindooSpacing.xs)
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
            }

            if showOrganizer, let organizer {
                HStack(spacing: BrindooSpacing.sm) {
                    AvatarView(url: organizer.avatarUrl, name: organizer.fullName, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(organizer.fullName ?? "Organizzatore")
                                .font(BrindooFont.bodyMedium.weight(.semibold))
                                .lineLimit(1)
                            if organizer.isPro {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.brindooCoral)
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
                    Image(systemName: "mappin.and.ellipse").font(.system(size: 11))
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

            if let proposal = activeProposal {
                proposalBadge(proposal)
            }
        }
        .padding(BrindooSpacing.md)
        .background(Color.brindooSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: BrindooRadius.md)
                .strokeBorder(
                    activeProposal != nil ? Color.brindooCoral.opacity(0.4) : Color.brindooBorder,
                    lineWidth: activeProposal != nil ? 1.5 : 1
                )
        )
    }

    @ViewBuilder
    private func proposalBadge(_ proposal: OfferProposal) -> some View {
        let userIsClient = true
        let waitingForMe = proposal.lastProposer == .organizer && userIsClient
        let label: String = {
            switch proposal.status {
            case .accepted: return "Accettata"
            case .rejected: return "Rifiutata"
            case .withdrawn: return "Ritirata"
            case .pending:
                return waitingForMe
                    ? "Controproposta organizzatore"
                    : "Tua proposta in attesa"
            }
        }()
        let color: Color = waitingForMe ? .brindooCoral : .brindooWarning

        HStack(spacing: 6) {
            Image(systemName: waitingForMe ? "exclamationmark.bubble.fill" : "arrow.left.arrow.right")
                .font(.system(size: 11, weight: .semibold))
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(BrindooFont.caption.weight(.semibold))
                Text(proposal.currentPriceDisplay)
                    .font(.system(size: 11))
            }
            Spacer()
        }
        .foregroundStyle(color)
        .padding(.vertical, BrindooSpacing.xxs)
        .padding(.horizontal, BrindooSpacing.sm)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
    }

    @ViewBuilder
    private var statusBadge: some View {
        let (color, text): (Color, String) = {
            switch offer.status {
            case .active: return (.brindooSuccess, "Attiva")
            case .paused: return (.brindooTextSecondary, "In pausa")
            }
        }()
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }

    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
