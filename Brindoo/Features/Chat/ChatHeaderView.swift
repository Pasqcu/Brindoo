//
//  ChatHeaderView.swift
//  Brindoo
//
//  Header riutilizzabile per ChatView: avatar + nome + badge Pro.
//

import SwiftUI

/// Intestazione della chat. Niente indicatore di presenza: l'app non sa
/// chi è collegato, sa solo chi sta scrivendo in questo momento, e quello
/// si legge già sopra la barra di scrittura. Il pallino verde diceva
/// "online ora" mentre significava tutt'altro.
struct ChatHeaderView: View {
    let user: Profile
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: BrindooSpacing.xs) {
                AvatarView(url: user.avatarUrl, name: user.fullName, size: 34)
                HStack(spacing: 4) {
                    Text(user.displayName)
                        .font(BrindooFont.bodyMedium.weight(.semibold))
                        .foregroundStyle(Color.brindooTextPrimary)
                        .lineLimit(1)
                    if user.showsProBadge {
                        ProBadge()
                    }
                    if user.identityVerified {
                        VerifiedCheckIcon(size: 11)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}
