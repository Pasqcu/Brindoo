//
//  ChatHeaderView.swift
//  Brindoo
//
//  Header riutilizzabile per ChatView: avatar + nome + badge Pro.
//

import SwiftUI

struct ChatHeaderView: View {
    let user: Profile
    let isOnline: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: BrindooSpacing.xs) {
                ZStack(alignment: .bottomTrailing) {
                    AvatarView(url: user.avatarUrl, name: user.fullName, size: 34)
                    if isOnline {
                        Circle()
                            .fill(Color.brindooSuccess)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Color.brindooBackground, lineWidth: 2))
                    }
                }
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        Text(user.fullName ?? "Utente")
                            .font(BrindooFont.bodyMedium.weight(.semibold))
                            .foregroundStyle(Color.brindooTextPrimary)
                            .lineLimit(1)
                        if user.isPro {
                            Image(systemName: BrindooIcon.crown)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(red: 0.93, green: 0.55, blue: 0.20))
                        }
                    }
                    if isOnline {
                        Text("online ora")
                            .font(BrindooFont.caption)
                            .foregroundStyle(Color.brindooSuccess)
                    } else if user.isPro {
                        Text("Pro")
                            .font(BrindooFont.caption)
                            .foregroundStyle(Color.brindooCoral)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}
