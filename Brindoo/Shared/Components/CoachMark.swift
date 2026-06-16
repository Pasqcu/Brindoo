//
//  CoachMark.swift
//  Brindoo
//
//  Tooltip "coach mark" per onboarding contestuale.
//  Si autodismiss dopo essere stato visto una volta (chiave persistita in UserDefaults).
//
//  USO:
//      .coachMark(.boardClient) { CoachMarkContent(...) }
//
//  Si registra una sola volta per `CoachMarkID` per utente / device.
//

import SwiftUI

enum CoachMarkID: String, CaseIterable {
    case boardClient            = "coach_board_client_v1"
    case boardOrganizer         = "coach_board_organizer_v1"
    case chatList               = "coach_chat_list_v1"
    case profile                = "coach_profile_v1"

    var defaultsKey: String { rawValue }
}

@MainActor
final class CoachMarkTracker {
    static let shared = CoachMarkTracker()
    private init() {}

    func hasSeen(_ id: CoachMarkID) -> Bool {
        UserDefaults.standard.bool(forKey: id.defaultsKey)
    }

    func markSeen(_ id: CoachMarkID) {
        UserDefaults.standard.set(true, forKey: id.defaultsKey)
    }

    func reset() {
        for id in CoachMarkID.allCases {
            UserDefaults.standard.removeObject(forKey: id.defaultsKey)
        }
    }
}

struct CoachMarkContent {
    let icon: String
    let title: String
    let message: String
}

struct CoachMarkOverlay: View {
    let id: CoachMarkID
    let content: CoachMarkContent
    @Binding var isVisible: Bool

    var body: some View {
        if isVisible {
            ZStack {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture { dismiss() }

                VStack(spacing: BrindooSpacing.md) {
                    ZStack {
                        Circle()
                            .fill(Color.brindooCoral.opacity(0.18))
                            .frame(width: 64, height: 64)
                        Image(systemName: content.icon)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(Color.brindooCoral)
                    }

                    Text(content.title)
                        .font(BrindooFont.titleMedium)
                        .multilineTextAlignment(.center)

                    Text(content.message)
                        .font(BrindooFont.bodyMedium)
                        .foregroundStyle(Color.brindooTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, BrindooSpacing.sm)

                    BrindooButton("Ho capito", style: .primary, size: .medium) {
                        dismiss()
                    }
                    .padding(.top, BrindooSpacing.xs)
                }
                .padding(BrindooSpacing.xl)
                .background(Color.brindooBackground)
                .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.lg))
                .shadow(color: .black.opacity(0.2), radius: 20)
                .padding(.horizontal, BrindooSpacing.xl)
                .transition(.scale.combined(with: .opacity))
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isVisible)
        }
    }

    private func dismiss() {
        CoachMarkTracker.shared.markSeen(id)
        withAnimation { isVisible = false }
    }
}

extension View {
    /// Mostra un coach mark una sola volta. Si attiva al primo `task`.
    func coachMark(_ id: CoachMarkID, content: CoachMarkContent) -> some View {
        modifier(CoachMarkModifier(id: id, content: content))
    }
}

private struct CoachMarkModifier: ViewModifier {
    let id: CoachMarkID
    let content: CoachMarkContent
    @State private var isVisible: Bool = false

    func body(content body: Content) -> some View {
        body.overlay {
            CoachMarkOverlay(id: id, content: content, isVisible: $isVisible)
        }
        .task {
            // Aspetta che la view sia disegnata prima di mostrare
            try? await Task.sleep(nanoseconds: 600_000_000)
            if !CoachMarkTracker.shared.hasSeen(id) {
                withAnimation { isVisible = true }
            }
        }
    }
}
