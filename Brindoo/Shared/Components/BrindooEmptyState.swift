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
                Circle()
                    .fill(Color.brindooCoral.opacity(0.1))
                    .frame(width: 84, height: 84)
                Image(systemName: icon)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color.brindooCoral)
            }
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
        .padding(BrindooSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
