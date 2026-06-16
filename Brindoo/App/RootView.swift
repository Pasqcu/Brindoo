//
//  RootView.swift
//  Brindoo
//
//  Vista radice dell'app. In base allo stato di autenticazione mostra:
//  - LoadingView mentre verifica sessione/profilo
//  - OnboardingView se l'utente non è loggato
//  - ProfileSetupView se loggato ma profilo da completare
//  - MainTabView se loggato e profilo completo
//

import SwiftUI
import Combine

struct RootView: View {

    @Environment(SessionStore.self) private var session
    @StateObject private var toastCenter = BrindooToastCenter()
    @State private var network = NetworkMonitor.shared

    @State private var hasAskedForNotifications = false
    @State private var showNotificationPrePrompt = false

    var body: some View {
        VStack(spacing: 0) {
            BrindooNetworkBar(isOffline: !network.isOnline)
            Group {
                switch session.authState {
                case .loading:
                    LoadingView()

                case .signedOut:
                    OnboardingView()

                case .profileSetup:
                    ProfileSetupView()

                case .signedIn:
                    MainTabView()
                        .task(id: session.userID) {
                            // Al primo accesso, mostra il pre-prompt informativo
                            await preparePushPermissionFlow()
                        }
                }
            }
        }
        .brindooToastOverlay()
        .environmentObject(toastCenter)
        // Il testo scala con le impostazioni di accessibilità, ma con un limite
        // ragionevole per non rompere i layout a dimensioni estreme.
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .animation(.easeInOut(duration: 0.3), value: session.authState)
        .animation(BrindooAnimation.smooth, value: network.isOnline)
        .sheet(isPresented: $showNotificationPrePrompt) {
            NotificationPrePromptView(
                onAccept: {
                    showNotificationPrePrompt = false
                    Task {
                        await NotificationService.shared.requestAuthorization()
                    }
                },
                onSkip: {
                    showNotificationPrePrompt = false
                    // Non chiediamo il prompt iOS adesso: l'utente potrà
                    // riprovare da Impostazioni → Notifiche push.
                }
            )
            .interactiveDismissDisabled(false)
        }
    }

    // MARK: - Permessi notifiche

    private func preparePushPermissionFlow() async {
        guard !hasAskedForNotifications else { return }
        hasAskedForNotifications = true

        await NotificationService.shared.refreshAuthorizationStatus()
        let status = NotificationService.shared.authorizationStatus

        switch status {
        case .notDetermined:
            // Mostra il soft-ask con UI in stile Brindoo prima del prompt iOS.
            // Apple raccomanda di NON mostrare subito il dialog di sistema:
            // un utente informato dà permesso molto più spesso.
            try? await Task.sleep(nanoseconds: 600_000_000)
            await MainActor.run { showNotificationPrePrompt = true }

        case .authorized, .provisional:
            await NotificationService.shared.registerForRemoteNotificationsIfAuthorized()

        case .denied, .ephemeral:
            // Niente: l'utente ha rifiutato in passato, non insistiamo.
            break

        @unknown default:
            break
        }
    }
}

// MARK: - Pre-prompt notifiche

/// Sheet informativo mostrato PRIMA del dialog di sistema iOS, per spiegare
/// all'utente perché Brindoo vuole inviargli notifiche. Pattern raccomandato
/// da Apple e dalle linee guida UX delle Human Interface Guidelines.
private struct NotificationPrePromptView: View {

    let onAccept: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: BrindooSpacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.brindooCoral.opacity(0.15))
                    .frame(width: 120, height: 120)
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.brindooCoral)
            }

            VStack(spacing: BrindooSpacing.sm) {
                Text("Resta aggiornato")
                    .font(BrindooFont.displayMedium)
                    .multilineTextAlignment(.center)

                Text("Attiva le notifiche per ricevere subito nuovi messaggi, proposte e aggiornamenti sulle tue trattative.")
                    .font(BrindooFont.bodyLarge)
                    .foregroundStyle(Color.brindooTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, BrindooSpacing.lg)
            }

            VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
                bullet(icon: "bubble.left.and.bubble.right.fill",
                       text: "Nuovi messaggi in chat")
                bullet(icon: "paperplane.fill",
                       text: "Proposte e trattative sulle tue offerte")
                bullet(icon: "star.fill",
                       text: "Nuove recensioni sul tuo profilo")
            }
            .padding(BrindooSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.brindooSurface)
            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
            .padding(.horizontal, BrindooSpacing.lg)

            Spacer()

            VStack(spacing: BrindooSpacing.sm) {
                BrindooButton("Attiva notifiche", style: .primary, size: .large) {
                    onAccept()
                }

                Button("Non adesso") {
                    onSkip()
                }
                .font(BrindooFont.bodyMedium.weight(.medium))
                .foregroundStyle(Color.brindooTextSecondary)
            }
            .padding(.horizontal, BrindooSpacing.lg)
            .padding(.bottom, BrindooSpacing.md)
        }
        .background(Color.brindooBackground)
    }

    @ViewBuilder
    private func bullet(icon: String, text: String) -> some View {
        HStack(spacing: BrindooSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.brindooCoral)
                .frame(width: 24)
            Text(text)
                .font(BrindooFont.bodyMedium)
        }
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.brindooBackground
                .ignoresSafeArea()
            
            VStack(spacing: BrindooSpacing.lg) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.brindooCoral, Color.brindooCoralDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 110, height: 110)
                        .shadow(color: Color.brindooCoral.opacity(0.35), radius: 16, x: 0, y: 8)
                    Image(systemName: "party.popper.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.white)
                }

                Text("Brindoo")
                    .font(BrindooFont.displayMedium)
                    .foregroundStyle(Color.brindooTextPrimary)
                
                ProgressView()
                    .tint(.brindooCoral)
                    .padding(.top, BrindooSpacing.md)
            }
        }
    }
}

#Preview("Loading") {
    LoadingView()
}
