//
//  BrindooStatTile.swift
//  Brindoo
//
//  Tile per le statistiche (usata nella dashboard organizer).
//

import SwiftUI

struct BrindooStatTile: View {
    let icon: String
    let value: String
    let label: String
    let tint: Color
    let trend: String?

    init(icon: String, value: String, label: String, tint: Color = .brindooCoral, trend: String? = nil) {
        self.icon = icon
        self.value = value
        self.label = label
        self.tint = tint
        self.trend = trend
    }

    var body: some View {
        BrindooCard(style: .elevated, padding: BrindooSpacing.md) {
            VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(tint.opacity(0.14))
                            .frame(width: 36, height: 36)
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(tint)
                    }
                    Spacer()
                    if let trend {
                        BrindooBadge(trend, style: trend.hasPrefix("-") ? .error : .success)
                    }
                }
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.brindooTextPrimary)
                Text(label)
                    .font(BrindooFont.bodySmall)
                    .foregroundStyle(Color.brindooTextSecondary)
            }
        }
    }
}

#Preview {
    HStack(spacing: BrindooSpacing.md) {
        BrindooStatTile(icon: "tray.full.fill", value: "12", label: "Offerte inviate", trend: "+3")
        BrindooStatTile(icon: "star.fill", value: "4.8", label: "Rating medio", tint: .brindooWarning)
    }
    .padding()
}
