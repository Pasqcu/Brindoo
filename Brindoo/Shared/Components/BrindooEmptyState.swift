//
//  BrindooEmptyState.swift
//  Brindoo
//
//  Placeholder per liste o schermate vuote.
//

import SwiftUI

struct BrindooEmptyState: View {
    let icon: String
    let title: String
    let message: String?
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        icon: String = BrindooIcon.empty,
        title: String,
        message: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: BrindooSpacing.md) {
            ZStack {
                // Un po' di festa attorno al vuoto: coriandoli fermi, palette
                // del marchio. Statici di proposito: niente da animare, niente
                // da chiedere a Riduci Movimento.
                festiveDots
                Circle()
                    .fill(Color.brindooCoral.opacity(0.1))
                    .frame(width: 84, height: 84)
                Image(systemName: icon)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color.brindooCoral)
            }
            .accessibilityHidden(true)
            VStack(spacing: BrindooSpacing.xxs) {
                Text(title)
                    .font(BrindooFont.titleMedium)
                    .foregroundStyle(Color.brindooTextPrimary)
                    .multilineTextAlignment(.center)
                if let message {
                    Text(message)
                        .font(BrindooFont.bodyMedium)
                        .foregroundStyle(Color.brindooTextSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            if let actionTitle, let action {
                BrindooButton(actionTitle, style: .primary, size: .medium, action: action)
                    .padding(.top, BrindooSpacing.xs)
                    .padding(.horizontal, BrindooSpacing.xxl)
            }
        }
    }

    /// Coriandoli e stelline fissi, sparsi attorno al cerchio dell'icona.
    /// Posizioni scelte a mano: il caso vero ogni tanto ammucchia.
    private var festiveDots: some View {
        ZStack {
            Group {
                Circle().fill(Color.brindooCoral.opacity(0.55)).frame(width: 7, height: 7)
                    .offset(x: -52, y: -34)
                Circle().fill(Color(red: 1.00, green: 0.72, blue: 0.30).opacity(0.6)).frame(width: 5, height: 5)
                    .offset(x: 48, y: -42)
                Circle().fill(Color(red: 0.35, green: 0.78, blue: 0.60).opacity(0.55)).frame(width: 6, height: 6)
                    .offset(x: 58, y: 12)
                Circle().fill(Color(red: 0.42, green: 0.60, blue: 0.98).opacity(0.5)).frame(width: 5, height: 5)
                    .offset(x: -58, y: 18)
                Capsule().fill(Color.brindooCoral.opacity(0.4)).frame(width: 9, height: 4)
                    .rotationEffect(.degrees(24))
                    .offset(x: 38, y: 44)
                Capsule().fill(Color(red: 0.95, green: 0.55, blue: 0.85).opacity(0.5)).frame(width: 8, height: 4)
                    .rotationEffect(.degrees(-32))
                    .offset(x: -40, y: 42)
            }
            Image(systemName: "sparkle")
                .font(.system(size: 11))
                .foregroundStyle(Color(red: 1.00, green: 0.72, blue: 0.30).opacity(0.7))
                .offset(x: -30, y: -52)
            Image(systemName: "sparkle")
                .font(.system(size: 8))
                .foregroundStyle(Color.brindooCoral.opacity(0.6))
                .offset(x: 34, y: 52)
        }
        .padding(BrindooSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Stato d'errore standard con "Riprova": da usare con LoadState.error.
struct BrindooErrorState: View {
    let message: String
    var retry: () -> Void

    var body: some View {
        BrindooEmptyState(
            icon: "exclamationmark.triangle",
            title: message,
            message: BrindooText.retryHint,
            actionTitle: "Riprova",
            action: retry
        )
    }
}

#Preview {
    BrindooEmptyState(
        icon: BrindooIcon.heart,
        title: "Nessun preferito",
        message: "Salva gli organizer che ti piacciono per ritrovarli qui.",
        actionTitle: "Esplora ora"
    ) {}
}
