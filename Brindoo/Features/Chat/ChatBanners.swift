//
//  ChatBanners.swift
//  Brindoo
//
//  Fascette informative della chat: utente bloccato, rispondi/modifica,
//  trattativa collegata, "sta scrivendo…" e note di sistema.
//

import SwiftUI

// MARK: - Utente bloccato

struct ChatBlockedBanner: View {
    var onUnblock: () -> Void

    var body: some View {
        VStack(spacing: BrindooSpacing.xs) {
            HStack(spacing: BrindooSpacing.xs) {
                Image(systemName: "hand.raised.slash.fill")
                Text("Utente bloccato")
                    .font(BrindooFont.bodyMedium.weight(.medium))
            }
            .foregroundStyle(Color.brindooError)

            Button {
                onUnblock()
            } label: {
                Text("Sblocca")
                    .font(BrindooFont.bodySmall.weight(.semibold))
                    .foregroundStyle(Color.brindooCoral)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(BrindooSpacing.md)
        .background(Color.brindooError.opacity(0.08))
    }
}

// MARK: - Rispondi a…

struct ChatReplyBanner: View {
    let message: Message
    /// Nome mostrato dopo "Rispondi a" ("te stesso" o il nome dell'altro).
    let replyToName: String
    var onClose: () -> Void

    var body: some View {
        HStack(spacing: BrindooSpacing.sm) {
            Rectangle().fill(Color.brindooCoral).frame(width: 3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Rispondi a \(replyToName)")
                    .font(BrindooFont.caption.weight(.semibold))
                    .foregroundStyle(Color.brindooCoral)
                Text(message.messageType == .image ? "📷 Foto" : message.content)
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooTextSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Button { onClose() } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.brindooTextSecondary)
            }
        }
        .padding(.horizontal, BrindooSpacing.md)
        .padding(.vertical, BrindooSpacing.xs)
        .background(Color.brindooSurface)
    }
}

// MARK: - Modifica messaggio

struct ChatEditBanner: View {
    var onClose: () -> Void

    var body: some View {
        HStack(spacing: BrindooSpacing.sm) {
            Image(systemName: "pencil")
                .foregroundStyle(Color.brindooCoral)
            Text("Modifica messaggio")
                .font(BrindooFont.caption.weight(.semibold))
                .foregroundStyle(Color.brindooCoral)
            Spacer()
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.brindooTextSecondary)
            }
        }
        .padding(.horizontal, BrindooSpacing.md)
        .padding(.vertical, BrindooSpacing.xs)
        .background(Color.brindooSurface)
    }
}

// MARK: - Trattativa collegata (Chat ↔ Trattative)

struct ChatNegotiationBanner: View {
    let proposal: OfferProposal

    var body: some View {
        Button {
            DeepLinkRouter.shared.selectedTab = 1 // Trattative
        } label: {
            HStack(spacing: BrindooSpacing.xs) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                VStack(alignment: .leading, spacing: 0) {
                    Text(proposal.status == .accepted ? "Trattativa conclusa" : "Trattativa in corso")
                        .font(BrindooFont.caption.weight(.semibold))
                    Text(proposal.currentPriceDisplay)
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextSecondary)
                }
                Spacer()
                Text("Apri")
                    .font(BrindooFont.caption.weight(.semibold))
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(Color.brindooCoral)
            .padding(.horizontal, BrindooSpacing.md)
            .padding(.vertical, BrindooSpacing.xs)
            .background(Color.brindooCoral.opacity(0.08))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - "Sta scrivendo…"

struct ChatTypingIndicator: View {
    let userName: String
    let isAnimating: Bool

    var body: some View {
        HStack(spacing: BrindooSpacing.xs) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.brindooTextSecondary)
                    .frame(width: 6, height: 6)
                    .opacity(0.6)
                    .scaleEffect(isAnimating ? 1.0 : 0.4)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.18),
                        value: isAnimating
                    )
            }
            Text("\(userName) sta scrivendo…")
                .font(BrindooFont.caption)
                .foregroundStyle(Color.brindooTextSecondary)
            Spacer()
        }
        .padding(.horizontal, BrindooSpacing.md)
        .padding(.vertical, BrindooSpacing.xs)
        .transition(.opacity)
    }
}

// MARK: - Nota di sistema centrata (es. data evento spostata)

struct ChatSystemNote: View {
    let text: String

    var body: some View {
        Text(text)
            .font(BrindooFont.caption.weight(.medium))
            .foregroundStyle(Color.brindooTextSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, BrindooSpacing.md)
            .padding(.vertical, BrindooSpacing.xs)
            .background(Color.brindooSurface)
            .clipShape(Capsule())
            .frame(maxWidth: .infinity)
            .padding(.vertical, BrindooSpacing.xxs)
    }
}
