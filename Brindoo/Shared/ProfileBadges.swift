//
//  ProfileBadges.swift
//  Brindoo
//
//  Distintivi dei traguardi del professionista ("10 eventi", "Sempre 5 stelle"…)
//  calcolati solo da dati pubblici. Logica pura + riga di badge per la UI.
//

import SwiftUI

// MARK: - Logica (testabile)

struct AchievementBadge: Identifiable, Equatable {
    let id: String
    let icon: String
    let title: String

    /// Distintivi guadagnati da un professionista, in ordine di prestigio.
    static func earned(
        reviewCount: Int,
        avgRating: Double,
        verifiedReviewCount: Int,
        portfolioCount: Int,
        memberSince: Date,
        responseSpeed: ResponseSpeed?,
        now: Date = Date()
    ) -> [AchievementBadge] {
        var badges: [AchievementBadge] = []

        if reviewCount >= 5 && avgRating >= 4.8 {
            badges.append(.init(id: "top_rated", icon: "trophy.fill", title: "Valutazioni al top"))
        }
        if verifiedReviewCount >= 3 {
            badges.append(.init(id: "verified_events", icon: "checkmark.seal.fill",
                                title: "\(verifiedReviewCount) eventi con recensione verificata"))
        }
        if reviewCount >= 10 {
            badges.append(.init(id: "in_demand", icon: "flame.fill", title: "Molto richiesto"))
        }
        if responseSpeed == .withinHour {
            badges.append(.init(id: "fast_replies", icon: "bolt.fill", title: "Risposte fulminee"))
        }
        if portfolioCount >= 8 {
            badges.append(.init(id: "rich_portfolio", icon: "photo.stack.fill", title: "Portfolio ricco"))
        }
        if now.timeIntervalSince(memberSince) >= 365 * 24 * 60 * 60 {
            badges.append(.init(id: "veteran", icon: "star.circle.fill", title: "Su Brindoo da oltre un anno"))
        }
        return badges
    }
}

// MARK: - Riga di distintivi

struct AchievementBadgeRow: View {

    let badges: [AchievementBadge]

    var body: some View {
        if !badges.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: BrindooSpacing.xs) {
                    ForEach(badges) { badge in
                        HStack(spacing: 4) {
                            Image(systemName: badge.icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(badge.title)
                                .font(BrindooFont.caption.weight(.semibold))
                        }
                        .foregroundStyle(Color.brindooCoral)
                        .padding(.horizontal, BrindooSpacing.sm)
                        .padding(.vertical, 5)
                        .background(Color.brindooCoral.opacity(0.1))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Color.brindooCoral.opacity(0.25), lineWidth: 1))
                    }
                }
                .padding(.horizontal, BrindooSpacing.md)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Traguardi: " + badges.map(\.title).joined(separator: ", "))
        }
    }
}
