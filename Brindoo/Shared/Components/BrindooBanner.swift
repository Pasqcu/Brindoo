//
//  BrindooBanner.swift
//  Brindoo
//
//  Banner inline per messaggi di sistema (info, errore, successo).
//

import SwiftUI

enum BrindooBannerStyle {
    case info, success, warning, error

    var color: Color {
        switch self {
        case .info: return .blue
        case .success: return .brindooSuccess
        case .warning: return .brindooWarning
        case .error: return .brindooError
        }
    }

    var icon: String {
        switch self {
        case .info: return BrindooIcon.info
        case .success: return BrindooIcon.success
        case .warning: return BrindooIcon.warning
        case .error: return BrindooIcon.error
        }
    }
}

/// Errore in linea, sotto un modulo o dentro una scheda.
///
/// Prima queste dieci righe erano ricopiate in otto schermate: bastava che
/// una divergesse di un padding perché l'app sembrasse cucita a pezzi.
struct BrindooInlineError: View {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: BrindooSpacing.xs) {
            Image(systemName: BrindooIcon.warning)
                .accessibilityHidden(true)
            Text(message)
                .font(BrindooFont.bodySmall)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Color.brindooError)
        .padding(BrindooSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brindooError.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
        // Una sola battuta di VoiceOver invece di icona + testo separati.
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Errore: \(message)")
    }
}

struct BrindooBanner: View {
    let style: BrindooBannerStyle
    let title: String
    let message: String?
    let dismissAction: (() -> Void)?

    init(
        style: BrindooBannerStyle,
        title: String,
        message: String? = nil,
        dismissAction: (() -> Void)? = nil
    ) {
        self.style = style
        self.title = title
        self.message = message
        self.dismissAction = dismissAction
    }

    var body: some View {
        HStack(alignment: .top, spacing: BrindooSpacing.sm) {
            Image(systemName: style.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(style.color)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BrindooFont.titleSmall)
                    .foregroundStyle(Color.brindooTextPrimary)
                if let message {
                    Text(message)
                        .font(BrindooFont.bodySmall)
                        .foregroundStyle(Color.brindooTextSecondary)
                }
            }
            Spacer(minLength: 0)
            if let dismissAction {
                Button(action: dismissAction) {
                    Image(systemName: BrindooIcon.close)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.brindooTextSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Chiudi l'avviso")
            }
        }
        .padding(BrindooSpacing.md)
        .background(style.color.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: BrindooRadius.md)
                .strokeBorder(style.color.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
    }
}

#Preview {
    VStack(spacing: BrindooSpacing.sm) {
        BrindooBanner(style: .info, title: "Suggerimento", message: "Aggiungi foto al tuo profilo per più visibilità.")
        BrindooBanner(style: .success, title: "Offerta accettata")
        BrindooBanner(style: .warning, title: "Profilo incompleto", message: "Mancano alcuni dati per ricevere offerte.")
        BrindooBanner(style: .error, title: "Connessione assente") {}
    }
    .padding()
}
