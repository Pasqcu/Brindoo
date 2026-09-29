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
        // Scritta bruna sull'oro: il bianco sull'oro chiaro restava a 2:1 e
        // "PRO" a 10 punti non si leggeva. Il marrone scuro supera 4:1 su
        // tutto il gradiente e non cambia tra chiaro e scuro, come l'oro.
        .foregroundStyle(Color(red: 0.30, green: 0.17, blue: 0.0))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(BrindooGradient.pro)
        .clipShape(Capsule())
        .shadow(color: Color.brindooProGoldDeep.opacity(0.4), radius: 3, x: 0, y: 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Brindoo Pro")
    }
}
