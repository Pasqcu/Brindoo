//
//  BrindooAnimation.swift
//  Brindoo
//
//  Animazioni standard riutilizzabili.
//

import SwiftUI

nonisolated enum BrindooAnimation {
    static let snappy = Animation.spring(response: 0.32, dampingFraction: 0.78)
    static let smooth = Animation.spring(response: 0.45, dampingFraction: 0.85)
    static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.62)
    static let quickEase = Animation.easeInOut(duration: 0.18)
    static let standardEase = Animation.easeInOut(duration: 0.28)
}

extension View {
    /// Aggiunge un effetto di "press" con scala ridotta
    func brindooPressEffect(isPressed: Bool) -> some View {
        scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(BrindooAnimation.snappy, value: isPressed)
    }

    /// Animazione di apparizione "morbida" per onAppear
    func brindooFadeInUp(delay: Double = 0) -> some View {
        modifier(FadeInUpModifier(delay: delay))
    }
}

private struct FadeInUpModifier: ViewModifier {
    let delay: Double
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 12)
            .onAppear {
                withAnimation(BrindooAnimation.smooth.delay(delay)) {
                    visible = true
                }
            }
    }
}

// MARK: - Transizione card → dettaglio

// Su iPhone aggiornati la card si "apre" nel dettaglio invece di comparire
// di colpo: il passaggio è più leggibile e l'app sembra più curata.
// Sui telefoni più vecchi non cambia nulla (nessun effetto, nessun errore).
extension View {

    /// Segna la card di partenza dell'effetto di apertura.
    @ViewBuilder
    func brindooZoomSource(id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            self.matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    /// Segna la schermata di arrivo dell'effetto di apertura.
    @ViewBuilder
    func brindooZoomDestination(id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            self.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }
}
