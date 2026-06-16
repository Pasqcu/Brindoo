//
//  BrindooButton.swift
//  Brindoo
//
//  Bottone riutilizzabile con varianti di stile.
//  Usato in tutta l'app per coerenza visiva.
//

import SwiftUI

/// Stili disponibili per BrindooButton
enum BrindooButtonStyle {
    /// Pieno corallo, testo bianco. Azione primaria.
    case primary
    
    /// Bordo corallo, testo corallo. Azione secondaria.
    case secondary
    
    /// Solo testo corallo, senza bordo. Azione terziaria.
    case tertiary
    
    /// Pieno bianco con testo corallo. Per sfondi colorati.
    case white
    
    /// Pieno rosso. Azioni distruttive (cancella, elimina).
    case destructive
}

/// Dimensioni del bottone
enum BrindooButtonSize {
    case large  // 56pt - schermate principali
    case medium // 48pt - default
    case small  // 36pt - inline
    
    var height: CGFloat {
        switch self {
        case .large: return 56
        case .medium: return 48
        case .small: return 36
        }
    }
    
    var horizontalPadding: CGFloat {
        switch self {
        case .large: return BrindooSpacing.xl
        case .medium: return BrindooSpacing.lg
        case .small: return BrindooSpacing.md
        }
    }
    
    var font: Font {
        switch self {
        case .large, .medium: return BrindooFont.button
        case .small: return BrindooFont.buttonSmall
        }
    }
}

struct BrindooButton: View {
    
    let title: String
    let style: BrindooButtonStyle
    let size: BrindooButtonSize
    let icon: String?
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void
    
    init(
        _ title: String,
        style: BrindooButtonStyle = .primary,
        size: BrindooButtonSize = .medium,
        icon: String? = nil,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.size = size
        self.icon = icon
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: BrindooSpacing.xs) {
                if isLoading {
                    ProgressView()
                        .tint(foregroundColor)
                } else {
                    if let icon {
                        Image(systemName: icon)
                            .font(size.font)
                    }
                    Text(title)
                        .font(size.font)
                }
            }
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: size.height)
            .padding(.horizontal, size.horizontalPadding)
            .background(backgroundView)
            .overlay(
                RoundedRectangle(cornerRadius: BrindooRadius.md)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )
            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
            .opacity(isDisabled ? 0.5 : 1.0)
        }
        .disabled(isDisabled || isLoading)
    }
    
    // MARK: - Stili dinamici

    /// Sfondo: gradiente per l'azione primaria (più profondità), tinta piatta per le altre.
    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .primary:     BrindooGradient.coral
        case .secondary:   Color.clear
        case .tertiary:    Color.clear
        case .white:       Color.white
        case .destructive: Color.brindooError
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary: return .white
        case .secondary: return Color.brindooCoral
        case .tertiary: return Color.brindooCoral
        // ⚠️ Forzato corallo: stile .white è pensato per sfondi colorati,
        // quindi il testo deve essere sempre corallo (non si adatta a dark mode).
        case .white: return Color.brindooCoral
        case .destructive: return .white
        }
    }
    
    private var borderColor: Color {
        switch style {
        case .primary, .tertiary, .destructive, .white: return .clear
        case .secondary: return Color.brindooCoral
        }
    }
    
    private var borderWidth: CGFloat {
        switch style {
        case .primary, .tertiary, .destructive, .white: return 0
        case .secondary: return 1.5
        }
    }
}

// MARK: - Preview

#Preview("Tutti gli stili") {
    VStack(spacing: BrindooSpacing.md) {
        BrindooButton("Primary Large", style: .primary, size: .large) {}
        BrindooButton("Secondary", style: .secondary) {}
        BrindooButton("Tertiary", style: .tertiary) {}
        BrindooButton("White", style: .white) {}
        BrindooButton("Destructive", style: .destructive) {}
        BrindooButton("Con Icona", style: .primary, icon: "arrow.right") {}
        BrindooButton("Caricamento", style: .primary, isLoading: true) {}
        BrindooButton("Disabilitato", style: .primary, isDisabled: true) {}
    }
    .padding()
}

#Preview("White su corallo") {
    ZStack {
        Color.brindooCoral.ignoresSafeArea()
        BrindooButton("Inizia ora", style: .white, size: .large) {}
            .padding()
    }
}
