//
//  OrganizerCard.swift
//  Brindoo
//
//  Card che mostra un profilo (organizzatore o cliente) nella lista Esplora.
//

import SwiftUI

struct OrganizerCard: View {

    let organizer: Profile
    let categories: [ServiceCategory]

    /// Colore guida della card: quello della prima categoria del professionista.
    /// Aiuta a riconoscere "a colpo d'occhio" di che tipo di servizio si tratta.
    private var accent: Color { categories.first?.tint ?? .brindooCoral }

    var body: some View {
        HStack(spacing: BrindooSpacing.md) {
            // Avatar tondo (foto reale se presente, altrimenti iniziali)
            AvatarView(
                url: organizer.avatarUrl,
                name: organizer.fullName,
                size: 64
            )
            
            VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
                // Nome + Pro badge (il badge Pro fa anche da "verificato")
                HStack(spacing: BrindooSpacing.xxs) {
                    Text(organizer.displayName)
                        .font(BrindooFont.titleSmall)
                        .foregroundStyle(Color.brindooTextPrimary)
                        .lineLimit(1)

                    if organizer.isPro {
                        ProBadge()
                    }
                    if organizer.identityVerified {
                        VerifiedCheckIcon()
                    }
                }
                
                // Città
                if let city = organizer.city, !city.isEmpty {
                    HStack(spacing: BrindooSpacing.xxs) {
                        Image(systemName: BrindooIcon.location)
                            .font(.system(size: 11))
                        Text(city)
                            .font(BrindooFont.caption)
                    }
                    .foregroundStyle(Color.brindooTextSecondary)
                }
                
                // Categorie chip (max 3)
                if !categories.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(categories.prefix(3)) { category in
                            HStack(spacing: 3) {
                                Image(systemName: category.icon)
                                    .font(.system(size: 10, weight: .medium))
                                Text(category.name)
                                    .font(BrindooFont.scaled(11, weight: .medium, relativeTo: .caption1))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(category.tint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(category.tint.opacity(0.12))
                            .clipShape(Capsule())
                        }
                        
                        if categories.count > 3 {
                            Text("+\(categories.count - 3)")
                                .font(BrindooFont.scaled(11, weight: .medium, relativeTo: .caption1))
                                .foregroundStyle(Color.brindooTextSecondary)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            
            Spacer()
            
            Image(systemName: BrindooIcon.forward)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.brindooTextSecondary)
        }
        .padding(BrindooSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brindooBackground)
        // Striscia laterale col colore della categoria principale.
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(accent)
                .frame(width: 4)
                .allowsHitTesting(false)
        }
        .overlay(
            RoundedRectangle(cornerRadius: BrindooRadius.lg)
                .strokeBorder(organizer.isBoosted ? accent.opacity(0.5) : Color.brindooBorder,
                              lineWidth: organizer.isBoosted ? 1.5 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.lg))
        // Chi è in vetrina "sta sopra": ombra più marcata.
        .brindooElevation(organizer.isBoosted ? .raised : .card)
    }
}

// MARK: - Badge Pro

struct ProBadge: View {
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: BrindooIcon.crown)
                .font(.system(size: 8, weight: .bold))
            Text("PRO")
                .font(BrindooFont.scaled(10, weight: .bold, rounded: true, relativeTo: .caption2))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(BrindooGradient.pro)
        .clipShape(Capsule())
        .shadow(color: Color.brindooProGoldDeep.opacity(0.4), radius: 3, x: 0, y: 1)
    }
}
