//
//  BrindooGradient.swift
//  Brindoo
//
//  Gradienti riutilizzabili per CTA, header e background.
//

import SwiftUI

enum BrindooGradient {
    static let coral = LinearGradient(
        colors: [Color.brindooCoral, Color.brindooCoralDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let coralSoft = LinearGradient(
        colors: [Color.brindooCoralLight.opacity(0.6), Color.brindooCoral.opacity(0.85)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let pro = LinearGradient(
        colors: [
            Color(red: 0.95, green: 0.74, blue: 0.30),
            Color(red: 0.93, green: 0.50, blue: 0.20)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let success = LinearGradient(
        colors: [Color.brindooSuccess.opacity(0.85), Color.brindooSuccess],
        startPoint: .top,
        endPoint: .bottom
    )

    static let skeleton = LinearGradient(
        colors: [
            Color.brindooSurface,
            Color.brindooSurfaceElevated,
            Color.brindooSurface
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let glassOverlay = LinearGradient(
        colors: [Color.black.opacity(0), Color.black.opacity(0.55)],
        startPoint: .top,
        endPoint: .bottom
    )
}
