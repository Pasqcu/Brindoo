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

    /// La schermata di avvio si toglie da sola: resta finché la prima schermata
    /// non ha i suoi dati e finché la sua animazione di uscita non è finita.
    @State private var splashFinished = false
    @State private var launchGate = AppLaunchGate.shared

    /// Oltre questo tempo la splash esce comunque: con la rete a terra è meglio
    /// una bacheca vuota che restare bloccati a guardare il logo.
    private let splashSafetyTimeout: Duration = .seconds(6)

    /// Ultimo stato non transitorio. Il rinnovo del token e i ricarichi del
    /// profilo riportano `authState` a `.loading` anche a sessione già risolta:
    /// senza questa memoria l'app verrebbe smontata e ricostruita sotto le dita
    /// dell'utente, con un lampo di schermo vuoto in mezzo.
    @State private var lastResolvedState: AuthState?

    /// Lo stato che l'interfaccia mostra davvero: si torna alla schermata di
    /// attesa solo al primo avvio, quando non c'è ancora nulla da tenere.
    private var displayedState: AuthState {
        if session.authState == .loading, let lastResolvedState {
            return lastResolvedState
        }
        return session.authState
    }

    /// La splash può uscire: sessione risolta e prima schermata pronta.
    private var isLaunchReady: Bool {
        switch displayedState {
        case .loading:
            return false
        case .signedOut, .profileSetup:
            // Niente da caricare dalla rete: quelle schermate sono già complete.
            return true
        case .signedIn:
            return launchGate.isFirstScreenReady
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                BrindooNetworkBar(isOffline: !network.isOnline)
                Group {
                    switch displayedState {
                    case .loading:
                        // Sotto la splash non serve nulla: la copre l'overlay.
                        Color.brindooBackground

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

            if !splashFinished {
                LoadingView(isReady: isLaunchReady) {
                    splashFinished = true
                }
                .zIndex(1)
                .task {
                    // Rete lenta o assente: sblocchiamo comunque.
                    try? await Task.sleep(for: splashSafetyTimeout)
                    guard !Task.isCancelled else { return }
                    launchGate.markFirstScreenReady()
                }
            }
        }
        .brindooToastOverlay()
        .environmentObject(toastCenter)
        // Il testo scala con le impostazioni di accessibilità, ma con un limite
        // ragionevole per non rompere i layout a dimensioni estreme.
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .onChange(of: session.authState, initial: true) { _, state in
            guard state != .loading else { return }
            lastResolvedState = state
        }
        .animation(BrindooAnimation.standardEase, value: displayedState)
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
            try? await Task.sleep(for: .milliseconds(600))
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
            .brindooSurfaceBackground()
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

    /// La sessione ha finito di caricare: da qui può partire l'uscita.
    var isReady: Bool = false

    /// Chiamata a uscita finita, quando la splash può essere rimossa.
    var onFinished: (() -> Void)?

    /// Tempo minimo a schermo: senza questo, su un telefono veloce la sessione
    /// risponde in un lampo e l'animazione non si vede nemmeno.
    private let minimumSeconds: TimeInterval = 1.6

    /// Diametro del logo a riposo. Il cerchio parte pieno, quindi lo spessore
    /// della fascia è metà del diametro finché il buco resta chiuso.
    private let logoDiameter: CGFloat = 110

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var appearedAt = Date()

    @State private var logoIn = false
    @State private var iconIn = false
    @State private var textIn = false
    @State private var spinnerIn = false
    @State private var pulsing = false
    @State private var breathing = false

    // Uscita: icona e scritte svaniscono, poi il logo si svuota e la fascia
    // corallo esce dai bordi. Sfondo e logo condividono lo stesso buco.
    @State private var contentOut = false
    @State private var holeDiameter: CGFloat = 0
    @State private var ringThickness: CGFloat = 55

    var body: some View {
        ZStack {
            // Strato mascherato: quello che il buco scava vale sia per lo
            // sfondo sia per il logo, così il taglio è uno solo.
            //
            // Logo e alone stanno in `overlay`, non in uno `ZStack`: crescendo
            // il cerchio arriva a migliaia di punti, e come figlio di uno stack
            // ne gonfierebbe la misura, spingendo fuori schermo l'app che sta
            // sotto. In overlay può debordare quanto vuole senza toccare il
            // layout di nessuno.
            Color.brindooBackground
                .overlay(alignment: .center) {
                    // Alone che pulsa dietro al logo: eco decorativa dello stesso cerchio.
                    Circle()
                        .fill(Color.brindooCoral)
                        .frame(width: logoDiameter, height: logoDiameter)
                        .scaleEffect(pulsing ? 1.5 : 1.0)
                        .opacity(pulsing ? 0 : 0.35)
                        .opacity(contentOut ? 0 : 1)
                }
                .overlay(alignment: .center) {
                    Circle()
                        .fill(BrindooGradient.coral)
                        .frame(width: holeDiameter + ringThickness * 2,
                               height: holeDiameter + ringThickness * 2)
                        .shadow(color: Color.brindooCoral.opacity(0.35), radius: 16, x: 0, y: 8)
                        .scaleEffect(breathing ? 1.035 : 1.0)
                        .scaleEffect(logoIn ? 1.0 : 0.55)
                        .opacity(logoIn ? 1 : 0)
                }
                .overlay(alignment: .center) {
                    Image(systemName: "party.popper.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.white)
                        .scaleEffect(iconIn ? 1.0 : 0.4)
                        .rotationEffect(.degrees(iconIn ? 0 : -18))
                        .opacity(iconIn ? 1 : 0)
                        .opacity(contentOut ? 0 : 1)
                }
                .mask(alignment: .center) {
                    Rectangle()
                        .overlay(alignment: .center) {
                            Circle()
                                .frame(width: holeDiameter, height: holeDiameter)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                }
                .ignoresSafeArea()
                .accessibilityHidden(true)

            // Nome e indicatore stanno sotto al logo senza spostarlo: il logo
            // deve restare al centro esatto, è da lì che si apre il buco.
            VStack(spacing: BrindooSpacing.xl) {
                Text("Brindoo")
                    .font(BrindooFont.displayMedium)
                    .foregroundStyle(Color.brindooTextPrimary)
                    .offset(y: textIn ? 0 : 10)
                    .opacity(textIn ? 1 : 0)

                ProgressView()
                    .tint(.brindooCoral)
                    .opacity(spinnerIn ? 1 : 0)
            }
            .offset(y: logoDiameter / 2 + BrindooSpacing.xxl)
            .opacity(contentOut ? 0 : 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Brindoo, caricamento in corso")
        .onAppear {
            appearedAt = Date()
            startEntrance()
        }
        .task(id: isReady) {
            guard isReady else { return }

            // Aspetta quel che manca al minimo, poi esce.
            let remaining = minimumSeconds - Date().timeIntervalSince(appearedAt)
            if remaining > 0 {
                try? await Task.sleep(for: .seconds(remaining))
            }
            guard !Task.isCancelled else { return }

            await runExit()
            onFinished?()
        }
    }

    private func startEntrance() {
        guard !reduceMotion else {
            // Riduci Movimento: mostriamo subito lo stato finale, senza movimento.
            logoIn = true
            iconIn = true
            textIn = true
            spinnerIn = true
            return
        }
        withAnimation(BrindooAnimation.bouncy) { logoIn = true }
        withAnimation(BrindooAnimation.bouncy.delay(0.12)) { iconIn = true }
        withAnimation(BrindooAnimation.smooth.delay(0.30)) { textIn = true }
        withAnimation(BrindooAnimation.standardEase.delay(0.55)) { spinnerIn = true }
        withAnimation(.easeOut(duration: 1.9).repeatForever(autoreverses: false).delay(0.6)) {
            pulsing = true
        }
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(0.9)) {
            breathing = true
        }
    }

    private func runExit() async {
        guard !reduceMotion else {
            // Riduci Movimento: niente corsa, solo una dissolvenza.
            withAnimation(BrindooAnimation.standardEase) {
                contentOut = true
                holeDiameter = 4000
                ringThickness = 0
            }
            try? await Task.sleep(for: .milliseconds(300))
            return
        }

        // Il respiro si posa su 1× mentre icona e scritte svaniscono: la corsa
        // parte da fermo e non si vede lo scatto.
        withAnimation(.easeOut(duration: 0.28)) {
            contentOut = true
            breathing = false
            pulsing = false
        }
        try? await Task.sleep(for: .milliseconds(120))

        // Una sola interpolazione: buco e bordo esterno crescono insieme.
        withAnimation(.timingCurve(0.55, 0, 0.8, 0.6, duration: 0.85)) {
            holeDiameter = 2400      // ben oltre la diagonale di qualsiasi iPhone
            ringThickness = 520
        }
        try? await Task.sleep(for: .milliseconds(870))
    }
}

#Preview("Loading") {
    LoadingView()
}

#Preview("Loading → uscita") {
    // Simula la sessione pronta subito: si vede entrata, attesa minima e uscita.
    LoadingView(isReady: true)
}
