//
//  AutoReplySettingsView.swift
//  Brindoo
//
//  Risposta automatica del professionista ("fuori sede", stile Outlook).
//  Il messaggio lo manda il database (trigger `brindoo_send_auto_reply`),
//  così parte anche con l'app chiusa: qui si salvano solo le impostazioni.
//

import SwiftUI

// MARK: - Riga nelle Impostazioni

struct SettingsAutoReplyRow: View {
    let profile: Profile?
    let isPro: Bool
    /// Chiamata dagli utenti non Pro: apre la paywall.
    var onUpgradeTap: () -> Void

    private var isOn: Bool { profile?.autoReplyEnabled ?? false }

    private var subtitle: String {
        guard let profile, profile.autoReplyEnabled else {
            return isPro ? "Spenta" : "Disponibile con Brindoo Pro"
        }
        if !isPro { return "Pro scaduto: non parte più, puoi solo spegnerla" }
        if profile.isAutoReplyActive {
            return profile.autoReplyUntil
                .map { "Attiva fino al \(BrindooFormat.italianDayMonth(from: $0))" } ?? "Attiva"
        }
        if let from = profile.autoReplyFrom, BrindooFormat.startOfDay(from) > BrindooFormat.startOfDay() {
            return "Programmata dal \(BrindooFormat.italianDayMonth(from: from))"
        }
        return "Periodo concluso"
    }

    var body: some View {
        // A Pro scaduto si entra lo stesso, ma solo per spegnerla.
        if isPro || isOn {
            NavigationLink {
                AutoReplySettingsView()
            } label: {
                row
            }
            .buttonStyle(.plain)
        } else {
            Button(action: onUpgradeTap) { row }
                .buttonStyle(.plain)
        }
    }

    private var row: some View {
        SettingsRow(
            icon: "arrowshape.turn.up.left.fill",
            iconColor: .brindooCoral,
            title: "Risposta automatica",
            subtitle: subtitle
        )
    }
}

// MARK: - Schermata

struct AutoReplySettingsView: View {

    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    static let maxLength = 500
    static let defaultMessage = "Ciao! In questo periodo non sono raggiungibile. Ti rispondo appena rientro, grazie per la pazienza."

    @State private var enabled = false
    @State private var message = ""
    @State private var hasFrom = false
    @State private var from = BrindooFormat.startOfDay()
    @State private var hasUntil = false
    @State private var until = BrindooFormat.startOfDay()
    @State private var isSaving = false
    @State private var errorText: String?
    @State private var didLoad = false

    private var isPro: Bool { session.currentProfile?.isPro ?? false }

    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var today: Date { BrindooFormat.startOfDay() }

    /// L'ultimo giorno non può venire prima del primo né essere già passato.
    private var firstUntilDay: Date {
        hasFrom ? max(from, today) : today
    }

    private var canSave: Bool {
        if isSaving { return false }
        // Senza Pro si può solo spegnere.
        if !enabled { return true }
        return isPro && !trimmedMessage.isEmpty && trimmedMessage.count <= Self.maxLength
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrindooSpacing.lg) {
                Text("Quando un cliente ti scrive, Brindoo risponde al posto tuo con questo messaggio, al massimo una volta al giorno per chat. In chat il cliente vede anche che sei assente.")
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooTextSecondary)

                Toggle(isOn: $enabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Invia risposte automatiche")
                            .font(BrindooFont.bodyMedium.weight(.semibold))
                        if !isPro {
                            Text("Pro scaduto: puoi solo spegnerla")
                                .font(BrindooFont.caption)
                                .foregroundStyle(Color.brindooTextSecondary)
                        }
                    }
                }
                .tint(Color.brindooCoral)
                .disabled(!isPro && !enabled)
                .padding(BrindooSpacing.md)
                .brindooSurfaceBackground()

                if enabled && isPro {
                    messageCard
                    periodCard
                }

                if let errorText {
                    Text(errorText)
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooError)
                }
            }
            .padding(BrindooSpacing.md)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            BrindooButton("Salva", isLoading: isSaving, isDisabled: !canSave) {
                Task { await save() }
            }
            .padding(.horizontal, BrindooSpacing.md)
            .padding(.vertical, BrindooSpacing.sm)
            .background(Color.brindooBackground.ignoresSafeArea(edges: .bottom))
        }
        .background(Color.brindooBackground)
        .navigationTitle("Risposta automatica")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
        .onChange(of: from) { _, newFrom in
            if until < newFrom { until = newFrom }
        }
    }

    private var messageCard: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
            Text("Messaggio")
                .font(BrindooFont.bodyMedium.weight(.semibold))
            TextEditor(text: $message)
                .font(BrindooFont.bodyMedium)
                .frame(minHeight: 120)
                .scrollContentBackground(.hidden)
                .padding(BrindooSpacing.xs)
                .background(Color.brindooBackground)
                .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
            Text("\(trimmedMessage.count)/\(Self.maxLength)")
                .font(BrindooFont.caption)
                .foregroundStyle(trimmedMessage.count > Self.maxLength ? Color.brindooError : Color.brindooTextSecondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(BrindooSpacing.md)
        .brindooSurfaceBackground()
    }

    private var periodCard: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
            Text("Periodo")
                .font(BrindooFont.bodyMedium.weight(.semibold))

            Toggle("Dal giorno", isOn: $hasFrom)
                .tint(Color.brindooCoral)
            if hasFrom {
                dayPicker("Primo giorno", selection: $from, from: today)
            }

            Divider()

            Toggle("Fino al giorno", isOn: $hasUntil)
                .tint(Color.brindooCoral)
            if hasUntil {
                dayPicker("Ultimo giorno (compreso)", selection: $until, from: firstUntilDay)
            }

            Text(periodFootnote)
                .font(BrindooFont.caption)
                .foregroundStyle(Color.brindooTextSecondary)
        }
        .font(BrindooFont.bodyMedium)
        .padding(BrindooSpacing.md)
        .brindooSurfaceBackground()
    }

    private var periodFootnote: String {
        switch (hasFrom, hasUntil) {
        case (false, false): return "Senza date resta attiva finché non la spegni."
        case (true, false): return "Parte dal primo giorno e resta attiva finché non la spegni."
        case (false, true): return "Attiva da subito, si ferma da sola dopo l'ultimo giorno."
        case (true, true): return "Attiva solo nei giorni scelti, estremi compresi."
        }
    }

    private func dayPicker(_ title: String, selection: Binding<Date>, from lowerBound: Date) -> some View {
        DatePicker(title, selection: selection, in: lowerBound..., displayedComponents: .date)
            .environment(\.locale, Locale(identifier: "it_IT"))
            .environment(\.timeZone, BrindooFormat.dayTimeZone)
    }

    // MARK: - Dati

    private func load() {
        guard !didLoad, let profile = session.currentProfile else { return }
        didLoad = true
        enabled = profile.autoReplyEnabled
        message = profile.autoReplyMessage ?? Self.defaultMessage
        if let savedFrom = profile.autoReplyFrom {
            hasFrom = true
            // Un inizio già passato vale come "da oggi": il DatePicker non
            // accetta giorni prima di oggi.
            from = max(BrindooFormat.startOfDay(savedFrom), today)
        }
        if let savedUntil = profile.autoReplyUntil {
            hasUntil = true
            until = max(BrindooFormat.startOfDay(savedUntil), firstUntilDay)
        } else {
            until = BrindooFormat.dayCalendar.date(byAdding: .day, value: 7, to: firstUntilDay) ?? firstUntilDay
        }
    }

    private func save() async {
        errorText = nil
        isSaving = true
        defer { isSaving = false }
        do {
            try await ProfileService.shared.updateAutoReply(
                enabled: enabled,
                message: trimmedMessage.isEmpty ? Self.defaultMessage : trimmedMessage,
                from: enabled && hasFrom ? from : nil,
                until: enabled && hasUntil ? until : nil
            )
            if let userId = session.userID,
               let profile = try? await ProfileService.shared.fetchProfile(userID: userId) {
                session.updateLocalProfile(profile)
            }
            BrindooHaptics.notify(.success)
            dismiss()
        } catch {
            BrindooLog.error("updateAutoReply: \(error)")
            errorText = BrindooErrorText.message(for: error, fallback: BrindooText.saveError("la risposta automatica"))
        }
    }
}
