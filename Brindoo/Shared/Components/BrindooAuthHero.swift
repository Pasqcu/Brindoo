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
        VStack(spacing: BrindooSpacing.sm) {
            ZStack {
                Circle()
                    .fill(BrindooGradient.coral)
                    .frame(width: 88, height: 88)
                    .shadow(color: Color.brindooCoral.opacity(0.35), radius: 14, x: 0, y: 8)
                Image(systemName: "party.popper.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text("Brindoo")
                .font(BrindooFont.displayMedium)
                .foregroundStyle(Color.brindooTextPrimary)

            Text(subtitle)
                .font(BrindooFont.bodyLarge)
                .foregroundStyle(Color.brindooTextSecondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
        .brindooFadeInUp()
    }
}
