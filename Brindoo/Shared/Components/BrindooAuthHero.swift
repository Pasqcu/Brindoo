//
//  BrindooAuthHero.swift
//  Brindoo
//
//  Intestazione di marca per le schermate di accesso/registrazione.
//

import SwiftUI

struct BrindooAuthHero: View {
    let subtitle: String

    var body: some View {
        // Misure contenute: accesso e registrazione devono stare in una schermata
        // sola, e l'intestazione è la parte che si comprime senza perdere nulla.
        VStack(spacing: BrindooSpacing.xs) {
            ZStack {
                Circle()
                    .fill(BrindooGradient.coral)
                    .frame(width: 64, height: 64)
                    .shadow(color: Color.brindooCoral.opacity(0.35), radius: 12, x: 0, y: 6)
                Image(systemName: "party.popper.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text("Brindoo")
                .font(BrindooFont.titleLarge)
                .foregroundStyle(Color.brindooTextPrimary)

            Text(subtitle)
                .font(BrindooFont.bodyMedium)
                .foregroundStyle(Color.brindooTextSecondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
        .brindooFadeInUp()
    }
}
