//
//  BrindooBadge.swift
//  Brindoo
//
//  Badge per status: pending, accepted, rejected, info, ecc.
//

import SwiftUI

enum BrindooBadgeStyle {
    case neutral
    case success
    case warning
    case error
    case info
    case coral
    case pro

    var background: Color {
        switch self {
        case .neutral: return Color.brindooTextSecondary.opacity(0.12)
        case .success: return Color.brindooSuccess.opacity(0.15)
        case .warning: return Color.brindooWarning.opacity(0.18)
        case .error:   return Color.brindooError.opacity(0.15)
        case .info:    return Color.blue.opacity(0.14)
        case .coral:   return Color.brindooCoral.opacity(0.14)
        case .pro:     return Color.brindooProGoldLight.opacity(0.18)
        }
    }

    var foreground: Color {
        switch self {
        case .neutral: return .brindooTextSecondary
        case .success: return .brindooSuccess
        case .warning: return .brindooWarning
        case .error:   return .brindooError
        case .info:    return .blue
        case .coral:   return .brindooCoral
        case .pro:     return Color.brindooProGoldInk
        }
    }
}

struct BrindooBadge: View {
    let text: String
    let style: BrindooBadgeStyle
    let icon: String?

    init(_ text: String, style: BrindooBadgeStyle = .neutral, icon: String? = nil) {
        self.text = text
        self.style = style
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(BrindooFont.scaled(11, weight: .bold, relativeTo: .caption1))
            }
            Text(text)
                .font(BrindooFont.scaled(12, weight: .semibold, rounded: true, relativeTo: .caption1))
        }
        .foregroundStyle(style.foreground)
        .padding(.horizontal, BrindooSpacing.xs)
        .padding(.vertical, 4)
        .background(style.background)
        .clipShape(Capsule())
    }
}

/// Pastiglia con pallino colorato: dice lo stato di un'offerta o di una
/// richiesta ("Attiva", "In pausa", "Aperta") senza rubare attenzione.
///
/// Era ricopiata identica in tre schermate — bacheca richieste, card offerta
/// e testata del dettaglio — con gli stessi numeri battuti a mano ogni volta.
struct BrindooDotBadge: View {
    let text: String
    let color: Color

    init(_ text: String, color: Color) {
        self.text = text
        self.color = color
    }

    var body: some View {
        HStack(spacing: BrindooSpacing.xxs) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(BrindooFont.scaled(11, weight: .semibold, relativeTo: .caption1))
                .foregroundStyle(color)
        }
        .padding(.horizontal, BrindooSpacing.xs)
        .padding(.vertical, BrindooSpacing.xxs)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Stato: \(text)")
    }
}

// MARK: - Colore degli stati
//
// I modelli restano su Foundation: il colore con cui si mostra uno stato è
// una scelta di interfaccia e vive qui, accanto alla pastiglia che lo usa.

extension ServiceOfferStatus {
    /// Verde se l'offerta è visibile in bacheca, grigio se è in pausa.
    var tint: Color {
        switch self {
        case .active: return .brindooSuccess
        case .paused: return .brindooTextSecondary
        }
    }
}

extension ClientRequestStatus {
    /// Verde finché la richiesta accetta risposte.
    var tint: Color {
        switch self {
        case .open:   return .brindooSuccess
        case .closed: return .brindooTextSecondary
        }
    }
}

#Preview {
    VStack(spacing: 8) {
        BrindooDotBadge("Attiva", color: .brindooSuccess)
        BrindooDotBadge("In pausa", color: .brindooTextSecondary)
        BrindooBadge("In attesa", style: .warning, icon: "clock.fill")
        BrindooBadge("Accettato", style: .success, icon: "checkmark")
        BrindooBadge("Rifiutato", style: .error, icon: "xmark")
        BrindooBadge("Pro", style: .pro, icon: "crown.fill")
        BrindooBadge("Nuovo", style: .coral)
    }
    .padding()
}
