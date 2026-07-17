//
//  OrganizerProfileSections.swift
//  Brindoo
//
//  Sezioni del profilo pubblico del professionista, estratte da
//  OrganizerDetailView: ricevono solo dati e non toccano lo stato
//  della schermata. Più leggibili e riusabili.
//

import SwiftUI

// MARK: - Intestazione (nome, ruolo, città, badge)

struct OrganizerTitleSection: View {
    let organizer: Profile

    var body: some View {
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

            if organizer.identityVerified {
                HStack(spacing: 4) {
                    Image(systemName: "person.badge.shield.checkmark.fill").font(.system(size: 11))
                    Text("Identità verificata")
                        .font(BrindooFont.caption.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, BrindooSpacing.sm)
                .padding(.vertical, 3)
                .background(Color.blue)
                .clipShape(Capsule())
                .padding(.top, 2)
            }

            HStack(spacing: 4) {
                Image(systemName: "checkmark.shield.fill").font(.system(size: 11))
                Text("Su Brindoo dal \(memberSinceYear)")
                    .font(BrindooFont.caption)
            }
            .foregroundStyle(Color.brindooSuccess)
            .padding(.top, 2)

            if let speed = organizer.responseSpeed {
                HStack(spacing: 4) {
                    Image(systemName: speed.iconName).font(.system(size: 11))
                    Text(speed.label)
                        .font(BrindooFont.caption.weight(.medium))
                }
                .foregroundStyle(Color.brindooSuccess)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var memberSinceYear: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "yyyy"
        return f.string(from: organizer.createdAt)
    }
}

// MARK: - Banner vacanza

struct OrganizerVacationBanner: View {
    let organizer: Profile

    var body: some View {
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
}

// MARK: - Bio "Chi sono"

struct OrganizerBioSection: View {
    let bio: String

    var body: some View {
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
}

// MARK: - Domande frequenti

/// Risposte pronte: meno chat ripetitive.
struct OrganizerFAQsSection: View {
    let faqs: [ProfileFAQ]

    var body: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "questionmark.bubble")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.brindooCoral)
                Text("Domande frequenti")
                    .font(BrindooFont.titleSmall)
            }

            ForEach(faqs) { faq in
                DisclosureGroup {
                    Text(faq.answer)
                        .font(BrindooFont.bodySmall)
                        .foregroundStyle(Color.brindooTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, BrindooSpacing.xs)
                } label: {
                    Text(faq.question)
                        .font(BrindooFont.bodySmall.weight(.semibold))
                        .foregroundStyle(Color.brindooTextPrimary)
                        .multilineTextAlignment(.leading)
                }
                .tint(Color.brindooCoral)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BrindooSpacing.md)
        .background(Color.brindooSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
    }
}

// MARK: - Servizi offerti

struct OrganizerCategoriesSection: View {
    let categories: [OrganizerCategoryDetail]

    var body: some View {
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
}

// MARK: - Zone coperte (mappa)

struct OrganizerCoverageSection: View {
    let organizer: Profile

    var body: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
            Text("Dove lavoro")
                .font(BrindooFont.titleSmall)

            VStack(spacing: BrindooSpacing.sm) {
                LazioMapView(highlighted: LazioArea.provinces(forSlugs: organizer.coverageAreas))
                    .frame(maxHeight: 190)
                    .frame(maxWidth: .infinity)

                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 11))
                    Text(organizer.coverageAreasDisplay)
                        .font(BrindooFont.caption.weight(.medium))
                        .lineLimit(2)
                }
                .foregroundStyle(Color.brindooTextSecondary)
            }
            .padding(BrindooSpacing.md)
            .frame(maxWidth: .infinity)
            .background(Color.brindooSurface)
            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
        }
    }
}

// MARK: - Riquadro riassunto recensioni

struct OrganizerReviewsSummarySection: View {
    let organizer: Profile
    let summary: ReviewSummary

    var body: some View {
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
}

// MARK: - Banner anteprima

struct OrganizerPreviewBanner: View {
    var body: some View {
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
}

// MARK: - Suggerimento scheda vuota

struct OrganizerTabEmptyHint: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: BrindooSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 34))
                .foregroundStyle(Color.brindooCoral.opacity(0.6))
            Text(text)
                .font(BrindooFont.bodySmall)
                .foregroundStyle(Color.brindooTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BrindooSpacing.xl)
    }
}
