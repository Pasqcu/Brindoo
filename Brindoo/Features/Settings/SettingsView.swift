//
//  SettingsView.swift
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
                        section(title: "Modalità account") {
                            Button { showUpgradeToPro = true } label: {
                                upgradeCard
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // MARK: - Abbonamenti & Boost
                    section(title: "Abbonamenti & Visibilità") {
                        VStack(spacing: BrindooSpacing.xs) {
                            // Pro
                            Button { showPaywall = true } label: {
                                proCard
                            }
                            .buttonStyle(.plain)
                            
                            // Boost (solo organizzatori)
                            if isOrganizer {
                                Button { showBoost = true } label: {
                                    boostCard
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // MARK: - Privacy & Chat
                    section(title: "Privacy & Chat") {
                        VStack(spacing: 0) {
                            toggleRow(
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
                            
                            toggleRow(
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
                                row(
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
                        section(title: "Modalità vacanza") {
                            vacationCard
                        }
                    }

                    // MARK: - Scorciatoie
                    section(title: "Scorciatoie") {
                        VStack(spacing: 0) {
                            if isOrganizer {
                                NavigationLink {
                                    OrganizerDashboardView()
                                } label: {
                                    row(icon: BrindooIcon.dashboard, iconColor: .brindooCoral, title: "Dashboard", subtitle: "Statistiche e performance")
                                }
                                .buttonStyle(.plain)
                                Divider().padding(.leading, 56)
                            } else {
                                NavigationLink {
                                    FavoriteOrganizersView()
                                } label: {
                                    row(icon: BrindooIcon.heartFilled, iconColor: .brindooCoral, title: "Preferiti", subtitle: "Organizer salvati")
                                }
                                .buttonStyle(.plain)
                                Divider().padding(.leading, 56)
                            }
                            NavigationLink {
                                ReferralView()
                            } label: {
                                row(icon: BrindooIcon.gift, iconColor: Color(red: 0.93, green: 0.55, blue: 0.20), title: "Invita amici", subtitle: "1 mese Pro per ogni amico")
                            }
                            .buttonStyle(.plain)
                        }
                        .background(Color.brindooSurface)
                        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
                    }

                    // MARK: - Assistenza
                    section(title: "Assistenza") {
                        VStack(spacing: 0) {
                            NavigationLink {
                                HelpView()
                            } label: {
                                row(icon: "questionmark.circle", iconColor: .brindooCoral, title: "Aiuto e domande frequenti", subtitle: "Come funziona Brindoo")
                            }
                            .buttonStyle(.plain)

                            Divider().padding(.leading, 56)

                            if let url = URL(string: "mailto:supporto@brindoo.app?subject=Assistenza%20Brindoo") {
                                Link(destination: url) {
                                    row(icon: "envelope", iconColor: .brindooCoral, title: "Contattaci", subtitle: "supporto@brindoo.app")
                                }
                            }

                            Divider().padding(.leading, 56)

                            if let url = URL(string: "mailto:supporto@brindoo.app?subject=Segnalazione%20problema%20Brindoo") {
                                Link(destination: url) {
                                    row(icon: "exclamationmark.bubble", iconColor: .brindooCoral, title: "Segnala un problema", subtitle: nil)
                                }
                            }
                        }
                        .background(Color.brindooSurface)
                        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
                    }

                    // MARK: - Info & Supporto
                    section(title: "Info") {
                        VStack(spacing: 0) {
                            NavigationLink {
                                TermsOfServiceView()
                            } label: {
                                row(icon: "doc.text", iconColor: .brindooTextSecondary, title: "Termini di servizio", subtitle: nil)
                            }
                            .buttonStyle(.plain)
                            
                            Divider().padding(.leading, 56)
                            
                            NavigationLink {
                                PrivacyPolicyView()
                            } label: {
                                row(icon: "lock.shield", iconColor: .brindooTextSecondary, title: "Privacy Policy", subtitle: nil)
                            }
                            .buttonStyle(.plain)
                            
                            Divider().padding(.leading, 56)
                            
                            row(icon: "info.circle", iconColor: .brindooTextSecondary, title: "Versione", subtitle: appVersion)
                        }
                        .background(Color.brindooSurface)
                        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
                    }
                    
                    // MARK: - Account
                    section(title: "Account") {
                        VStack(spacing: 0) {
                            if let email = session.userEmail, !email.isEmpty {
                                row(
                                    icon: "envelope.fill",
                                    iconColor: .brindooTextSecondary,
                                    title: "Email",
                                    subtitle: email
                                )
                                Divider().padding(.leading, 56)
                            }

                            Button { showChangeEmail = true } label: {
                                row(
                                    icon: "pencil.circle.fill",
                                    iconColor: .brindooCoral,
                                    title: "Cambia email",
                                    subtitle: "Aggiorna l'indirizzo associato al tuo account"
                                )
                            }
                            .buttonStyle(.plain)

                            Divider().padding(.leading, 56)

                            Button { showSignOutConfirm = true } label: {
                                row(icon: "rectangle.portrait.and.arrow.right", iconColor: .brindooWarning, title: "Esci dall'account", subtitle: nil)
                            }
                            .buttonStyle(.plain)

                            Divider().padding(.leading, 56)

                            Button { showDeleteAccount = true } label: {
                                row(icon: "trash.fill", iconColor: .brindooError, title: "Elimina account", subtitle: "Azione permanente", titleColor: .brindooError)
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
    
    // MARK: - Section wrapper
    
    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
            Text(title)
                .font(BrindooFont.bodySmall.weight(.semibold))
                .foregroundStyle(Color.brindooTextSecondary)
                .textCase(.uppercase)
                .padding(.leading, BrindooSpacing.xs)
            content()
        }
    }
    
    @ViewBuilder
    private var proCard: some View {
        HStack(spacing: BrindooSpacing.sm) {
            ZStack {
                LinearGradient(
                    colors: [Color.brindooCoral, .orange],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Diventa Pro")
                        .font(BrindooFont.bodyMedium.weight(.semibold))
                    if isPro {
                        Text("ATTIVO")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.brindooSuccess)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
                Text(isPro ? "Gestisci abbonamento" : "Sblocca tutte le funzionalità")
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooTextSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundStyle(Color.brindooTextSecondary)
        }
        .padding(BrindooSpacing.sm)
        .background(Color.brindooSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
    }
    
    @ViewBuilder
    private var boostCard: some View {
        HStack(spacing: BrindooSpacing.sm) {
            ZStack {
                Color.brindooCoral.opacity(0.15)
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                Image(systemName: "bolt.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.brindooCoral)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Boost")
                    .font(BrindooFont.bodyMedium.weight(.semibold))
                Text("Metti in evidenza il tuo profilo")
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooTextSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundStyle(Color.brindooTextSecondary)
        }
        .padding(BrindooSpacing.sm)
        .background(Color.brindooSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
    }
    
    // MARK: - Upgrade card (Cliente → Professionista)

    @ViewBuilder
    private var upgradeCard: some View {
        HStack(spacing: BrindooSpacing.sm) {
            ZStack {
                LinearGradient(
                    colors: [Color.brindooCoral, .pink],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: 44, height: 44)
                .clipShape(Circle())

                Image(systemName: "sparkles")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Diventa Professionista")
                    .font(BrindooFont.bodyMedium.weight(.semibold))
                Text("Pubblica i tuoi servizi e fatti scegliere dai clienti")
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooTextSecondary)
                    .lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundStyle(Color.brindooTextSecondary)
        }
        .padding(BrindooSpacing.sm)
        .background(Color.brindooSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
    }

    // MARK: - Vacanza

    @ViewBuilder
    private var vacationCard: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
            // Riga principale con toggle (o lock se non Pro)
            HStack(spacing: BrindooSpacing.sm) {
                ZStack {
                    Color.brindooCoral.opacity(0.15)
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                    Image(systemName: "beach.umbrella.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.brindooCoral)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Sono in vacanza")
                            .font(BrindooFont.bodyMedium.weight(.semibold))
                        if !isPro {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.brindooTextSecondary)
                        }
                    }
                    Text(isPro
                        ? "Le tue offerte saranno nascoste ai clienti"
                        : "Disponibile con Brindoo Pro")
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextSecondary)
                }
                Spacer()

                if isPro {
                    Toggle("", isOn: $vacationOn)
                        .labelsHidden()
                        .tint(Color.brindooCoral)
                        .disabled(vacationSaving)
                        .onChange(of: vacationOn) { _, on in
                            Task { await persistVacation(on: on) }
                        }
                } else {
                    Button {
                        showPaywall = true
                    } label: {
                        Text("Passa a Pro")
                            .font(BrindooFont.bodySmall.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, BrindooSpacing.sm)
                            .padding(.vertical, 6)
                            .background(Color.brindooCoral)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(BrindooSpacing.md)
            .background(Color.brindooSurface)
            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))

            // DatePicker per la data di ritorno (visibile solo se attiva)
            if isPro && vacationOn {
                HStack {
                    Text("Torno il")
                        .font(BrindooFont.bodyMedium)
                    Spacer()
                    DatePicker(
                        "",
                        selection: $vacationUntil,
                        in: Date()...,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "it_IT"))
                    .onChange(of: vacationUntil) { _, _ in
                        Task { await persistVacation(on: true) }
                    }
                }
                .padding(BrindooSpacing.md)
                .background(Color.brindooSurface)
                .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
            }
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
            print("❌ \(error)")
        }
    }

    // MARK: - Generic rows
    
    @ViewBuilder
    private func row(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String?,
        titleColor: Color = .brindooTextPrimary
    ) -> some View {
        HStack(spacing: BrindooSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(iconColor)
                .frame(width: 32, height: 32)
                .background(iconColor.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BrindooFont.bodyMedium)
                    .foregroundStyle(titleColor)
                if let subtitle {
                    Text(subtitle)
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextSecondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(Color.brindooTextSecondary)
        }
        .padding(.horizontal, BrindooSpacing.md)
        .padding(.vertical, BrindooSpacing.sm)
        .contentShape(Rectangle())
    }
    
    @ViewBuilder
    private func toggleRow(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String?,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: BrindooSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(iconColor)
                .frame(width: 32, height: 32)
                .background(iconColor.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BrindooFont.bodyMedium)
                if let subtitle {
                    Text(subtitle)
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextSecondary)
                }
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.brindooCoral)
        }
        .padding(.horizontal, BrindooSpacing.md)
        .padding(.vertical, BrindooSpacing.sm)
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
            print("❌ \(error)")
        }
    }
}

// MARK: - Blocked Users View

struct BlockedUsersView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var profiles: [Profile] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView().tint(.brindooCoral)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if profiles.isEmpty {
                    VStack(spacing: BrindooSpacing.md) {
                        Image(systemName: "hand.raised.slash")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.brindooTextSecondary)
                        Text("Nessun utente bloccato")
                            .font(BrindooFont.bodyMedium)
                            .foregroundStyle(Color.brindooTextSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(profiles) { profile in
                            HStack {
                                AvatarView(url: profile.avatarUrl, name: profile.fullName, size: 40)
                                VStack(alignment: .leading) {
                                    Text(profile.fullName ?? "Utente")
                                        .font(BrindooFont.bodyMedium)
                                    if let city = profile.city {
                                        Text(city)
                                            .font(BrindooFont.caption)
                                            .foregroundStyle(Color.brindooTextSecondary)
                                    }
                                }
                                Spacer()
                                Button("Sblocca") {
                                    Task { await unblock(profile.id) }
                                }
                                .font(BrindooFont.bodySmall.weight(.medium))
                                .foregroundStyle(Color.brindooCoral)
                            }
                        }
                    }
                }
            }
            .background(Color.brindooBackground)
            .navigationTitle("Utenti bloccati")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chiudi") { dismiss() }
                }
            }
            .task { await load() }
        }
    }
    
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        await BlockService.shared.loadBlocks()
        await withTaskGroup(of: Profile?.self) { group in
            for id in BlockService.shared.blockedIds {
                group.addTask {
                    try? await ProfileService.shared.fetchProfile(userID: id)
                }
            }
            var loaded: [Profile] = []
            for await p in group {
                if let p { loaded.append(p) }
            }
            await MainActor.run { profiles = loaded }
        }
    }
    
    private func unblock(_ userId: UUID) async {
        do {
            try await BlockService.shared.unblock(userId: userId)
            profiles.removeAll { $0.id == userId }
        } catch { print("❌ \(error)") }
    }
}
