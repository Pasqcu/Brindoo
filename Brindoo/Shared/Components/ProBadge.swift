//
//  ProBadge.swift
//  Brindoo
//
//  Il segno "PRO" accanto al nome di chi ha Brindoo Pro: lo stesso in
//  tutte le schermate (card, profilo, chat, confronto).
//

import SwiftUI

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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Brindoo Pro")
    }
}
