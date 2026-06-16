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
        case .pro:     return Color(red: 0.95, green: 0.74, blue: 0.30).opacity(0.18)
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
        case .pro:     return Color(red: 0.78, green: 0.45, blue: 0.10)
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
                    .font(.system(size: 11, weight: .bold))
            }
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(style.foreground)
        .padding(.horizontal, BrindooSpacing.xs)
        .padding(.vertical, 4)
        .background(style.background)
        .clipShape(Capsule())
    }
}

#Preview {
    VStack(spacing: 8) {
        BrindooBadge("In attesa", style: .warning, icon: "clock.fill")
        BrindooBadge("Accettato", style: .success, icon: "checkmark")
        BrindooBadge("Rifiutato", style: .error, icon: "xmark")
        BrindooBadge("Pro", style: .pro, icon: "crown.fill")
        BrindooBadge("Nuovo", style: .coral)
    }
    .padding()
}
