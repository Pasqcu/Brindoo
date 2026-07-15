//
//  OfferDetailHeader.swift
//  Brindoo
//
//  Parti "descrittive" del dettaglio offerta: intestazione con organizzatore,
//  badge di stato, categorie, riquadro info e descrizione.
//

import SwiftUI

// MARK: - Galleria foto (copertina offerta + portfolio dell'organizzatore)

struct OfferPhotoGallery: View {
    /// URL delle immagini da mostrare, in ordine (la copertina per prima).
    let urls: [String]

    var body: some View {
        TabView {
            ForEach(urls, id: \.self) { urlString in
                if let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .empty:
                            BrindooSkeleton(cornerRadius: 0)
                        default:
                            Color.brindooSurface
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .clipped()
                }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: urls.count > 1 ? .automatic : .never))
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
        .accessibilityLabel(urls.count > 1 ? "Galleria foto, \(urls.count) immagini" : "Foto dell'offerta")
    }
}

// MARK: - Intestazione (titolo, stato, link al profilo organizzatore)

struct OfferHeaderSection: View {
    let offer: ServiceOffer
    let currentStatus: ServiceOfferStatus
    let organizerProfile: Profile?

    var body: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
            HStack {
                Text(offer.title)
                    .font(BrindooFont.titleLarge)
                Spacer()
                OfferStatusBadge(status: currentStatus)
            }

            if let profile = organizerProfile {
                NavigationLink {
                    OrganizerDetailView(organizer: profile)
                } label: {
                    HStack(spacing: BrindooSpacing.xs) {
                        AvatarView(url: profile.avatarUrl, name: profile.fullName, size: 32)
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 4) {
                                Text(profile.fullName ?? "Organizzatore")
                                    .font(BrindooFont.bodyMedium.weight(.medium))
                                if profile.isPro {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.brindooCoral)
                                }
                            }
                            Text("Vedi profilo")
                                .font(BrindooFont.caption)
                                .foregroundStyle(Color.brindooCoral)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.brindooTextSecondary)
                    }
                }
                .buttonStyle(.plain)

                // Segnale di fiducia: velocità di risposta in chat, ben visibile.
                if let speed = profile.responseSpeed {
                    HStack(spacing: 4) {
                        Image(systemName: speed.iconName)
                            .font(.system(size: 11, weight: .semibold))
                        Text(speed.label)
                            .font(BrindooFont.caption.weight(.semibold))
                    }
                    .foregroundStyle(Color.brindooSuccess)
                    .padding(.horizontal, BrindooSpacing.sm)
                    .padding(.vertical, 4)
                    .background(Color.brindooSuccess.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
        }
    }
}

// MARK: - Badge stato offerta

struct OfferStatusBadge: View {
    let status: ServiceOfferStatus

    var body: some View {
        let (color, text): (Color, String) = {
            switch status {
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
}

// MARK: - Categorie

struct OfferCategoriesSection: View {
    let categories: [ServiceCategory]

    var body: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
            Text("Categorie").font(BrindooFont.titleSmall)
            FlowLayoutView(spacing: BrindooSpacing.xs) {
                ForEach(categories) { cat in
                    HStack(spacing: 4) {
                        Image(systemName: cat.icon).font(.system(size: 12))
                        Text(cat.name).font(BrindooFont.bodySmall.weight(.medium))
                    }
                    .padding(.horizontal, BrindooSpacing.sm)
                    .padding(.vertical, BrindooSpacing.xs)
                    .foregroundStyle(Color.brindooCoral)
                    .background(Color.brindooCoral.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
        }
    }
}

// MARK: - Riquadro info (zona, prezzo)

struct OfferInfoSection: View {
    let offer: ServiceOffer

    var body: some View {
        VStack(spacing: BrindooSpacing.xs) {
            infoRow(icon: "mappin.and.ellipse", title: "Zona", value: offer.coverageArea)
            infoRow(icon: "eurosign.circle", title: "Prezzo richiesto", value: offer.priceDisplay)
        }
        .padding(BrindooSpacing.md)
        .background(Color.brindooSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
    }

    @ViewBuilder
    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack {
            HStack(spacing: BrindooSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.brindooCoral)
                Text(title)
                    .font(BrindooFont.bodySmall)
                    .foregroundStyle(Color.brindooTextSecondary)
            }
            Spacer()
            Text(value)
                .font(BrindooFont.bodyMedium.weight(.medium))
        }
    }
}

// MARK: - Descrizione

struct OfferDescriptionSection: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
            Text("Descrizione")
                .font(BrindooFont.titleSmall)
            Text(text)
                .font(BrindooFont.bodyMedium)
                .foregroundStyle(Color.brindooTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
