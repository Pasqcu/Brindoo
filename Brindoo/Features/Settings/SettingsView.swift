//
//  SettingsView.swift
//
//  Schermata Impostazioni. I mattoncini grafici (sezioni, righe, card)
//  vivono in SettingsComponents.swift; la lista bloccati in BlockedUsersView.swift.
//

import SwiftUI

struct SettingsView: View {

    @Environment(SessionStore.self) private var session

    @State private var showPaywall: Bool = false
    @State private var showBoost: Bool = false
    @State private var showDeleteAccount: Bool = false
    @State private var showSignOutConfirm: Bool = false
    @State private var showBlockedUsers: Bool = false
    @State private var showUpgradeToPro: Bool = false
    @State private var showChangeEmail: Bool = false
    @State private var readReceiptsEnabled: Bool = true
    @State private var pushEnabled: Bool = true

    // Diagnostica (rapporto errori da inviare al supporto)
    @State private var diagnosticsPayload: DiagnosticsPayload?

    private struct DiagnosticsPayload: Identifiable {
        let id = UUID()
        let url: URL
    }

    // Vacanza (solo organizzatori Pro)
    @State private var vacationOn: Bool = false
    @State private var vacationUntil: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var vacationSaving: Bool = false

    private var isOrganizer: Bool {
        session.currentProfile?.role == .organizer
    }

    private var isPro: Bool {
        session.currentProfile?.isPro ?? false
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BrindooSpacing.lg) {

                    // MARK: - Modalità account (upgrade Cliente → Professionista)
                    if !isOrganizer {
                        SettingsSection(title: "Modalità account") {
                            Button { showUpgradeToPro = true } label: {
                                SettingsPromoCard(
                                    icon: "sparkles",
                                    iconStyle: .gradient([Color.brindooCoral, .pink]),
                                    title: "Diventa Professionista",
                                    subtitle: "Pubblica i tuoi servizi e fatti scegliere dai clienti"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // MARK: - Abbonamenti & Boost
                    SettingsSection(title: "Abbonamenti & Visibilità") {
                        VStack(spacing: BrindooSpacing.xs) {
                            // Pro
                            Button { showPaywall = true } label: {
                                SettingsPromoCard(
                                    icon: "crown.fill",
                                    iconStyle: .gradient([Color.brindooCoral, .orange]),
                                    title: "Diventa Pro",
                                    badgeText: isPro ? "ATTIVO" : nil,
                                    subtitle: isPro ? "Gestisci abbonamento" : "Sblocca tutte le funzionalità"
                                )
                            }
                            .buttonStyle(.plain)

                            // Boost (solo organizzatori)
                            if isOrganizer {
                                Button { showBoost = true } label: {
                                    SettingsPromoCard(
                                        icon: "bolt.fill",
                                        iconStyle: .tinted(.brindooCoral),
                                        title: "Boost",
                                        subtitle: "Metti in evidenza il tuo profilo"
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // MARK: - Privacy & Chat
                    SettingsSection(title: "Privacy & Chat") {
                        VStack(spacing: 0) {
                            SettingsToggleRow(
                                icon: "checkmark.message.fill",
                                iconColor: .brindooCoral,
                                title: "Conferma lettura messaggi",
                                subtitle: "Mostra agli altri quando leggi i loro messaggi",
                                isOn: $readReceiptsEnabled
                            )
                            .onChange(of: readReceiptsEnabled) { _, newValue in
                                Task { await updateReadReceipts(newValue) }
                            }

                            Divider().padding(.leading, 56)

                            SettingsToggleRow(
                                icon: "bell.fill",
                                iconColor: .brindooCoral,
                                title: "Notifiche push",
                                subtitle: "Ricevi notifiche per messaggi e trattative",
                                isOn: $pushEnabled
                            )
                            .onChange(of: pushEnabled) { _, newValue in
                                Task {
                                    if newValue {
                                        await NotificationService.shared.requestAuthorization()
                                    }
                                }
                            }

                            Divider().padding(.leading, 56)

                            Button { showBlockedUsers = true } label: {
                                SettingsRow(
                                    icon: "hand.raised.slash.fill",
                                    iconColor: .brindooError,
                                    title: "Utenti bloccati",
                                    subtitle: "Gestisci la lista dei profili bloccati"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .background(Color.brindooSurface)
                        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
                    }

                    // MARK: - Modalità vacanza (organizzatori, Pro-only)
                    if isOrganizer {
                        SettingsSection(title: "Modalità vacanza") {
                            SettingsVacationCard(
                                isPro: isPro,
                                saving: vacationSaving,
                                vacationOn: $vacationOn,
                                vacationUntil: $vacationUntil,
                                onChange: { on in Task { await persistVacation(on: on) } },
                                onUpgradeTap: { showPaywall = true }
                            )
                        }
                    }

                    // MARK: - Scorciatoie
                    SettingsSection(title: "Scorciatoie") {
                        VStack(spacing: 0) {
                            if isOrganizer {
                                NavigationLink {
                                    OrganizerDashboardView()
                                } label: {
                                    SettingsRow(icon: BrindooIcon.dashboard, iconColor: .brindooCoral, title: "Dashboard", subtitle: "Statistiche e performance")
                                }
                                .buttonStyle(.plain)
                                Divider().padding(.leading, 56)
                            } else {
                                NavigationLink {
                                    FavoriteOrganizersView()
                                } label: {
                                    SettingsRow(icon: BrindooIcon.heartFilled, iconColor: .brindooCoral, title: "Preferiti", subtitle: "Organizer salvati")
                                }
                                .buttonStyle(.plain)
                                Divider().padding(.leading, 56)
                            }
                            NavigationLink {
                                ReferralView()
                            } label: {
                                SettingsRow(icon: BrindooIcon.gift, iconColor: Color(red: 0.93, green: 0.55, blue: 0.20), title: "Invita amici", subtitle: "1 mese Pro per ogni amico")
                            }
                            .buttonStyle(.plain)
                        }
                        .background(Color.brindooSurface)
                        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
                    }

                    // MARK: - Assistenza
                    SettingsSection(title: "Assistenza") {
                        VStack(spacing: 0) {
                            NavigationLink {
                                HelpView()
                            } label: {
                                SettingsRow(icon: "questionmark.circle", iconColor: .brindooCoral, title: "Aiuto e domande frequenti", subtitle: "Come funziona Brindoo")
                            }
                            .buttonStyle(.plain)

                            Divider().padding(.leading, 56)

                            if let url = URL(string: "mailto:supporto@brindoo.app?subject=Assistenza%20Brindoo") {
                                Link(destination: url) {
                                    SettingsRow(icon: "envelope", iconColor: .brindooCoral, title: "Contattaci", subtitle: "supporto@brindoo.app")
                                }
                            }

                            Divider().padding(.leading, 56)

                            if let url = URL(string: "mailto:supporto@brindoo.app?subject=Segnalazione%20problema%20Brindoo") {
                                Link(destination: url) {
                                    SettingsRow(icon: "exclamationmark.bubble", iconColor: .brindooCoral, title: "Segnala un problema")
                                }
                            }

                            Divider().padding(.leading, 56)

                            Button {
                                if let url = BrindooDiagnostics.reportFileURL() {
                                    diagnosticsPayload = DiagnosticsPayload(url: url)
                                }
                            } label: {
                                SettingsRow(
                                    icon: "stethoscope",
                                    iconColor: .brindooCoral,
                                    title: "Invia diagnostica",
                                    subtitle: "Condividi il rapporto errori col supporto"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .background(Color.brindooSurface)
                        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
                    }

                    // MARK: - Info & Supporto
                    SettingsSection(title: "Info") {
                        VStack(spacing: 0) {
                            NavigationLink {
                                TermsOfServiceView()
                            } label: {
                                SettingsRow(icon: "doc.text", iconColor: .brindooTextSecondary, title: "Termini di servizio")
                            }
                            .buttonStyle(.plain)

                            Divider().padding(.leading, 56)

                            NavigationLink {
                                PrivacyPolicyView()
                            } label: {
                                SettingsRow(icon: "lock.shield", iconColor: .brindooTextSecondary, title: "Privacy Policy")
                            }
                            .buttonStyle(.plain)

                            Divider().padding(.leading, 56)

                            SettingsRow(icon: "info.circle", iconColor: .brindooTextSecondary, title: "Versione", subtitle: appVersion)
                        }
                        .background(Color.brindooSurface)
                        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
                    }

                    // MARK: - Account
                    SettingsSection(title: "Account") {
                        VStack(spacing: 0) {
                            if let email = session.userEmail, !email.isEmpty {
                                SettingsRow(
                                    icon: "envelope.fill",
                                    iconColor: .brindooTextSecondary,
                                    title: "Email",
                                    subtitle: email
                                )
                                Divider().padding(.leading, 56)
                            }

                            Button { showChangeEmail = true } label: {
                                SettingsRow(
                                    icon: "pencil.circle.fill",
                                    iconColor: .brindooCoral,
                                    title: "Cambia email",
                                    subtitle: "Aggiorna l'indirizzo associato al tuo account"
                                )
                            }
                            .buttonStyle(.plain)

                            Divider().padding(.leading, 56)

                            Button { showSignOutConfirm = true } label: {
                                SettingsRow(icon: "rectangle.portrait.and.arrow.right", iconColor: .brindooWarning, title: "Esci dall'account")
                            }
                            .buttonStyle(.plain)

                            Divider().padding(.leading, 56)

                            Button { showDeleteAccount = true } label: {
                                SettingsRow(icon: "trash.fill", iconColor: .brindooError, title: "Elimina account", subtitle: "Azione permanente", titleColor: .brindooError)
                            }
                            .buttonStyle(.plain)
                        }
                        .background(Color.brindooSurface)
                        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
                    }
                }
                .padding(BrindooSpacing.md)
            }
            .background(Color.brindooBackground)
            .navigationTitle("Impostazioni")
            .navigationBarTitleDisplayMode(.large)
            .task { await loadPreferences() }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showBoost) {
                BoostView()
            }
            .sheet(isPresented: $showDeleteAccount) {
                DeleteAccountView()
            }
            .sheet(isPresented: $showBlockedUsers) {
                BlockedUsersView()
            }
            .sheet(isPresented: $showUpgradeToPro) {
                UpgradeToProfessionalView()
            }
            .sheet(isPresented: $showChangeEmail) {
                ChangeEmailView()
            }
            .sheet(item: $diagnosticsPayload) { payload in
                ActivityShareSheet(items: [payload.url])
                    .presentationDetents([.medium, .large])
            }
            .alert("Esci dall'account?", isPresented: $showSignOutConfirm) {
                Button("Annulla", role: .cancel) {}
                Button("Esci", role: .destructive) {
                    Task { await AuthService.shared.signOut() }
                }
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    // MARK: - Actions

    private func loadPreferences() async {
        guard let profile = session.currentProfile else { return }
        readReceiptsEnabled = profile.readReceiptsEnabled
        pushEnabled = await NotificationService.shared.isAuthorized()

        if let until = profile.vacationUntil, profile.isOnVacation {
            vacationOn = true
            vacationUntil = until
        } else {
            vacationOn = false
        }
    }

    private func updateReadReceipts(_ enabled: Bool) async {
        guard session.userID != nil else { return }
        do {
            try await ProfileService.shared.updateReadReceipts(enabled: enabled)
        } catch {
            BrindooLog.error("\(error)")
        }
    }

    private func persistVacation(on: Bool) async {
        vacationSaving = true
        defer { vacationSaving = false }
        do {
            try await ProfileService.shared.setVacation(until: on ? vacationUntil : nil)
            if let userId = session.userID,
               let profile = try? await ProfileService.shared.fetchProfile(userID: userId) {
                session.updateLocalProfile(profile)
            }
        } catch {
            BrindooLog.error("\(error)")
        }
    }
}
