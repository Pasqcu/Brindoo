//
//  BrindooAnimation.swift
//  Brindoo
//
//  Animazioni standard riutilizzabili.
//

import SwiftUI

enum BrindooAnimation {
    static let snappy = Animation.spring(response: 0.32, dampingFraction: 0.78)
    static let smooth = Animation.spring(response: 0.45, dampingFraction: 0.85)
    static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.62)
    static let quickEase = Animation.easeInOut(duration: 0.18)
    static let standardEase = Animation.easeInOut(duration: 0.28)

    static let pageTransition: AnyTransition = .asymmetric(
        insertion: .opacity.combined(with: .move(edge: .trailing)),
        removal: .opacity.combined(with: .move(edge: .leading))
    )

    static let sheetTransition: AnyTransition = .move(edge: .bottom).combined(with: .opacity)
    static let scaleFade: AnyTransition = .scale(scale: 0.92).combined(with: .opacity)
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
