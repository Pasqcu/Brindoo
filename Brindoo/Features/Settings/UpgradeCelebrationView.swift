//
//  UpgradeCelebrationView.swift
//  Brindoo
//
//  Overlay celebrativo mostrato subito dopo che un cliente conferma il passaggio
//  a Professionista. Anima sparkles + scale + fade, poi chiama `onComplete`.
//

import SwiftUI

struct UpgradeCelebrationView: View {

    let onComplete: () -> Void

    @State private var iconScale: CGFloat = 0.2
    @State private var iconRotation: Double = -180
    @State private var iconOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.1
    @State private var ringOpacity: Double = 0.6
    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 16
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.brindooCoral, .pink, .purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            // Velo scuro leggero: al centro il rosa di sistema dava al testo
            // bianco un contrasto di 3,6:1, sotto la soglia AA.
            Color.black.opacity(0.15)
                .ignoresSafeArea()

            // Sparkles di sfondo
            ForEach(0..<14, id: \.self) { i in
                Image(systemName: "sparkle")
                    // Misura fissa per stellina: un random qui cambiava a
                    // ogni ridisegno e le stelline saltavano durante l'animazione.
                    .font(.system(size: CGFloat(12 + (i * 7) % 13)))
                    .foregroundStyle(.white.opacity(0.7))
                    .offset(
                        x: CGFloat(i.hashValue % 200 - 100),
                        y: CGFloat((i * 37) % 400 - 200)
                    )
                    .opacity(iconOpacity)
                    .rotationEffect(.degrees(Double(i) * 23))
                    .accessibilityHidden(true)
            }

            VStack(spacing: BrindooSpacing.xl) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.5), lineWidth: 2)
                        .frame(width: 220, height: 220)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)

                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 260, height: 260)
                        .scaleEffect(ringScale * 0.9)
                        .opacity(ringOpacity * 0.7)

                    Image(systemName: BrindooIcon.explore)
                        .font(.system(size: 90, weight: .bold))
                        .foregroundStyle(.white)
                        .scaleEffect(iconScale)
                        .rotationEffect(.degrees(iconRotation))
                        .opacity(iconOpacity)
                        .shadow(color: .white.opacity(0.6), radius: 18)
                }
                .accessibilityHidden(true)

                VStack(spacing: BrindooSpacing.xs) {
                    Text("Sei un Professionista!")
                        .font(BrindooFont.scaled(28, weight: .bold, rounded: true, relativeTo: .title1))
                        .foregroundStyle(.white)
                    Text("Ora completiamo il tuo profilo.")
                        .font(BrindooFont.bodyLarge)
                        .foregroundStyle(.white)
                }
                .opacity(textOpacity)
                .offset(y: textOffset)
            }
        }
        .onAppear { runAnimation() }
    }

    private func runAnimation() {
        BrindooHaptics.notify(.success)
        // La schermata si chiude da sola: con VoiceOver il messaggio va
        // annunciato, altrimenti passa senza che nessuno lo senta.
        AccessibilityNotification.Announcement("Sei un Professionista! Ora completiamo il tuo profilo.").post()

        if reduceMotion {
            // Stesso messaggio, senza scala né rotazione: stato finale diretto.
            iconScale = 1.0
            iconRotation = 0
            iconOpacity = 1
            ringOpacity = 0
            textOpacity = 1
            textOffset = 0
        } else {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.55)) {
                iconScale = 1.0
                iconRotation = 0
                iconOpacity = 1
            }
            withAnimation(.easeOut(duration: 1.2)) {
                ringScale = 1.8
                ringOpacity = 0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.35)) {
                textOpacity = 1
                textOffset = 0
            }
        }

        // Auto-dismiss dopo 1.8s
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            onComplete()
        }
    }
}

#Preview {
    UpgradeCelebrationView(onComplete: {})
}
