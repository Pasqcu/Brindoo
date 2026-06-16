//
//  BrindooCard.swift
//  Brindoo
//
//  Card container standard con padding, sfondo, raggi e ombra del design system.
//

import SwiftUI

enum BrindooCardStyle {
    case elevated   // Sfondo + ombra
    case flat       // Solo sfondo
    case outlined   // Bordo, no ombra
    case highlight  // Sfondo coral chiaro per evidenziazione
}

struct BrindooCard<Content: View>: View {
    let style: BrindooCardStyle
    let padding: CGFloat
    let cornerRadius: CGFloat
    let content: () -> Content

    init(
        style: BrindooCardStyle = .elevated,
        padding: CGFloat = BrindooSpacing.md,
        cornerRadius: CGFloat = BrindooRadius.lg,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.style = style
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .modifier(ConditionalShadow(enabled: style == .elevated))
    }

    private var backgroundColor: Color {
        switch style {
        case .elevated, .flat, .outlined: return .brindooSurface
        case .highlight: return Color.brindooCoral.opacity(0.08)
        }
    }

    private var borderColor: Color {
        switch style {
        case .outlined: return .brindooBorder
        case .highlight: return Color.brindooCoral.opacity(0.35)
        default: return .clear
        }
    }

    private var borderWidth: CGFloat {
        switch style {
        case .outlined, .highlight: return 1
        default: return 0
        }
    }
}

private struct ConditionalShadow: ViewModifier {
    let enabled: Bool
    func body(content: Content) -> some View {
        if enabled {
            content.brindooCardShadow()
        } else {
            content
        }
    }
}

#Preview {
    VStack(spacing: BrindooSpacing.md) {
        BrindooCard(style: .elevated) {
            Text("Elevated").font(BrindooFont.titleMedium)
        }
        BrindooCard(style: .flat) {
            Text("Flat").font(BrindooFont.titleMedium)
        }
        BrindooCard(style: .outlined) {
            Text("Outlined").font(BrindooFont.titleMedium)
        }
        BrindooCard(style: .highlight) {
            Text("Highlight").font(BrindooFont.titleMedium)
        }
    }
    .padding()
}
