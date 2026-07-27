//
//  BrindooIconBadge.swift
//  Brindoo
//
//  Icona bianca dentro un cerchio pieno: apre le righe con un titolo e una
//  descrizione (categorie del profilo, trattative, attività recente).
//
//  Era ricopiata in sei punti con tre misure d'icona diverse dentro lo stesso
//  cerchio da 36 pt, e con una dimensione fissa: chi legge in grande vedeva
//  il testo crescere e l'icona restare com'era. Qui cerchio e icona crescono
//  insieme, così la riga resta proporzionata.
//

import SwiftUI

struct BrindooIconBadge: View {
    let systemName: String
    let tint: Color

    /// Diametro del cerchio, legato alla grandezza del testo scelta nelle
    /// impostazioni del telefono.
    @ScaledMetric(relativeTo: .body) private var diameter: CGFloat = 36

    init(_ systemName: String, tint: Color = .brindooCoral) {
        self.systemName = systemName
        self.tint = tint
    }

    var body: some View {
        Image(systemName: systemName)
            .font(BrindooFont.scaled(17, weight: .semibold, relativeTo: .body))
            .foregroundStyle(.white)
            .frame(width: diameter, height: diameter)
            .background(tint)
            .clipShape(Circle())
            // È decorativa: la riga accanto dice già di cosa si tratta.
            .accessibilityHidden(true)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
        BrindooIconBadge(BrindooIcon.tag)
        BrindooIconBadge(BrindooIcon.chat, tint: .brindooSuccess)
    }
    .padding()
}
