//
//  OrganizerStatsView.swift
//  Brindoo
//
//  Dashboard statistiche per organizzatori Pro: visite profilo, visite offerte,
//  proposte ricevute, tempo medio di risposta — tutto sugli ultimi 30 giorni.
//

import SwiftUI

struct OrganizerStatsView: View {

    @Environment(SessionStore.self) private var session

    @State private var stats: AnalyticsService.OrganizerStats?
    @State private var isLoading: Bool = true

    private var isPro: Bool { session.currentProfile?.isPro ?? false }

    var body: some View {
        ScrollView {
            VStack(spacing: BrindooSpacing.lg) {
                if isLoading {
                    ProgressView().tint(.brindooCoral)
                        .padding(.vertical, BrindooSpacing.xl)
                } else if let stats {
                    grid(stats)
                    responseTimeCard(stats)
                    footer
                }
            }
            .padding(BrindooSpacing.md)
        }
        .background(Color.brindooBackground)
        .navigationTitle("Statistiche")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private func grid(_ s: AnalyticsService.OrganizerStats) -> some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
            Text("Ultimi 30 giorni")
                .font(BrindooFont.titleSmall)
                .foregroundStyle(Color.brindooTextSecondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BrindooSpacing.md) {
                statCard(
                    icon: "eye.fill",
                    title: "Visite profilo",
                    value: "\(s.profileViews30d)"
                )
                statCard(
                    icon: "tag.fill",
                    title: "Visite offerte",
                    value: "\(s.offerViews30d)"
                )
                statCard(
                    icon: "arrow.left.arrow.right",
                    title: "Proposte ricevute",
                    value: "\(s.proposalsReceived30d)"
                )
                statCard(
                    icon: "clock.fill",
                    title: "Tempo medio risposta",
                    value: responseTimeShort(s.averageResponseMinutes)
                )
            }
        }
    }

    @ViewBuilder
    private func statCard(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color.brindooCoral)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Color.brindooTextPrimary)
            Text(title)
                .font(BrindooFont.caption)
                .foregroundStyle(Color.brindooTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BrindooSpacing.md)
        .background(Color.brindooSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
    }

    @ViewBuilder
    private func responseTimeCard(_ s: AnalyticsService.OrganizerStats) -> some View {
        if let avg = s.averageResponseMinutes {
            HStack(spacing: BrindooSpacing.sm) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(Color.brindooCoral)
                Text(qualitativeResponse(avg))
                    .font(BrindooFont.bodyMedium.weight(.medium))
                Spacer()
            }
            .padding(BrindooSpacing.md)
            .background(Color.brindooCoral.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
        }
    }

    @ViewBuilder
    private var footer: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
            Text("Le statistiche si aggiornano in tempo reale e mostrano gli eventi degli ultimi 30 giorni.")
                .font(BrindooFont.caption)
                .foregroundStyle(Color.brindooTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func responseTimeShort(_ minutes: Double?) -> String {
        guard let m = minutes else { return "—" }
        if m < 60 { return "\(Int(m.rounded())) min" }
        let hours = m / 60
        if hours < 24 { return "\(Int(hours.rounded())) h" }
        let days = hours / 24
        return "\(Int(days.rounded())) g"
    }

    private func qualitativeResponse(_ minutes: Double) -> String {
        if minutes < 15 { return "Rispondi molto velocemente 🚀" }
        if minutes < 60 { return "Risposta veloce, ottimo!" }
        if minutes < 60 * 6 { return "Risposta in poche ore" }
        if minutes < 60 * 24 { return "Risposta entro 24h" }
        return "Risposta lenta, prova ad essere più reattivo"
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            stats = try await AnalyticsService.shared.fetchMyStats()
        } catch {
            print("❌ \(error)")
        }
    }
}
