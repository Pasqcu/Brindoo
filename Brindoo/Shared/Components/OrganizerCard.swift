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
                    Text(organizer.fullName ?? "Senza nome")
                        .font(BrindooFont.titleSmall)
                        .foregroundStyle(Color.brindooTextPrimary)
                        .lineLimit(1)

                    if organizer.isPro {
                        ProBadge()
                    }
                }
                
                // Città
                if let city = organizer.city, !city.isEmpty {
                    HStack(spacing: BrindooSpacing.xxs) {
                        Image(systemName: "mappin.and.ellipse")
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
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(Color.brindooCoral)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.brindooCoral.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        
                        if categories.count > 3 {
                            Text("+\(categories.count - 3)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.brindooTextSecondary)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.brindooTextSecondary)
        }
        .padding(BrindooSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brindooBackground)
        .overlay(
            RoundedRectangle(cornerRadius: BrindooRadius.lg)
                .strokeBorder(Color.brindooBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.lg))
        .brindooCardShadow()
    }
}

// MARK: - Badge Pro

struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                LinearGradient(
                    colors: [Color.brindooCoral, Color.brindooCoralDark],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
    }
}
