//
//  LegalConsent.swift
//  Brindoo
//
//  Consenso legale con prova sul server (GDPR):
//  - versione corrente dei Termini (alzarla ripropone l'accettazione a tutti)
//  - schermata di accettazione Termini + scarico di responsabilità
//  - schermata con la dichiarazione del professionista
//
//  NOTA: i testi sono bozze da far validare a un legale prima del rilascio.
//

import SwiftUI

enum LegalVersion {
    /// Versione dei Termini in vigore. Alzarla (es. "1.1") fa riapparire
    /// la schermata di accettazione a tutti gli utenti, una volta sola.
    static let current = "1.0"
}

// MARK: - Accettazione Termini (tutti gli utenti)

/// Schermata bloccante mostrata quando manca (o è vecchia) l'accettazione
/// registrata sul server. Registra data e versione sul profilo.
struct LegalConsentGate: View {

    @Environment(SessionStore.self) private var session

    @State private var accepted = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showTerms = false
    @State private var showPrivacy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BrindooSpacing.md) {
                    Label("Termini e responsabilità", systemImage: "checkmark.shield")
                        .font(BrindooFont.titleMedium)
                        .foregroundStyle(Color.brindooCoral)

                    Text("Prima di continuare, conferma di accettare le condizioni d'uso di Brindoo.")
                        .font(BrindooFont.bodyMedium)
                        .foregroundStyle(Color.brindooTextSecondary)

                    VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
                        bullet("Brindoo mette in contatto clienti e professionisti: accordi, pagamenti e qualità dei servizi restano tra le parti.")
                        bullet("Brindoo non è parte dei contratti conclusi tramite l'app e non risponde delle prestazioni dei professionisti.")
                        bullet("I contenuti pubblicati (foto, descrizioni, recensioni) devono essere veritieri e di tua proprietà.")
                        bullet("I tuoi dati sono trattati come descritto nella Privacy Policy; puoi scaricarli o eliminare l'account dalle Impostazioni.")
                    }
                    .padding(BrindooSpacing.md)
                    .background(Color.brindooSurface)
                    .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))

                    HStack(spacing: BrindooSpacing.xs) {
                        Button("Leggi i Termini") { showTerms = true }
                        Text("·").foregroundStyle(Color.brindooTextSecondary)
                        Button("Privacy Policy") { showPrivacy = true }
                    }
                    .font(BrindooFont.bodySmall.weight(.medium))
                    .tint(Color.brindooCoral)

                    Toggle(isOn: $accepted) {
                        Text("Ho letto e accetto i Termini di servizio e la Privacy Policy.")
                            .font(BrindooFont.bodySmall)
                    }
                    .tint(Color.brindooCoral)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(BrindooFont.bodySmall)
                            .foregroundStyle(Color.brindooError)
                    }

                    BrindooButton("Accetta e continua", style: .primary, size: .large, isLoading: isSaving, isDisabled: !accepted) {
                        Task { await save() }
                    }
                }
                .padding(BrindooSpacing.md)
            }
            .background(Color.brindooBackground)
            .navigationTitle("Condizioni d'uso")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled()
            .sheet(isPresented: $showTerms) {
                NavigationStack { TermsOfServiceView() }
            }
            .sheet(isPresented: $showPrivacy) {
                NavigationStack { PrivacyPolicyView() }
            }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: BrindooSpacing.xs) {
            Text("•")
            Text(text)
        }
        .font(BrindooFont.bodySmall)
        .foregroundStyle(Color.brindooTextSecondary)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let updated = try await ProfileService.shared.recordTermsAcceptance()
            session.updateLocalProfile(updated)
        } catch {
            errorMessage = "Impossibile salvare. Controlla la connessione e riprova."
            BrindooLog.error("recordTermsAcceptance: \(error)")
        }
    }
}

// MARK: - Dichiarazione del professionista

/// Testo unico della dichiarazione, riusato nella schermata di upgrade
/// e nella schermata bloccante per i professionisti esistenti.
enum ProfessionalDeclaration {
    static let points: [String] = [
        "Opero nel rispetto delle norme fiscali, assicurative e di sicurezza applicabili alla mia attività.",
        "Sono l'unico responsabile dei servizi che offro e degli accordi presi con i clienti.",
        "Le informazioni e le foto che pubblico sono veritiere e ne possiedo i diritti.",
        "Emetterò regolare documento fiscale quando richiesto dalla legge."
    ]
}

/// Schermata bloccante per professionisti senza dichiarazione registrata.
struct ProfessionalDeclarationGate: View {

    @Environment(SessionStore.self) private var session

    @State private var accepted = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BrindooSpacing.md) {
                    Label("Dichiarazione del professionista", systemImage: "person.badge.shield.checkmark")
                        .font(BrindooFont.titleMedium)
                        .foregroundStyle(Color.brindooCoral)

                    Text("Per offrire servizi su Brindoo devi confermare quanto segue.")
                        .font(BrindooFont.bodyMedium)
                        .foregroundStyle(Color.brindooTextSecondary)

                    VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
                        ForEach(ProfessionalDeclaration.points, id: \.self) { point in
                            HStack(alignment: .top, spacing: BrindooSpacing.xs) {
                                Text("•")
                                Text(point)
                            }
                            .font(BrindooFont.bodySmall)
                            .foregroundStyle(Color.brindooTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(BrindooSpacing.md)
                    .background(Color.brindooSurface)
                    .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))

                    Toggle(isOn: $accepted) {
                        Text("Confermo tutti i punti della dichiarazione.")
                            .font(BrindooFont.bodySmall)
                    }
                    .tint(Color.brindooCoral)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(BrindooFont.bodySmall)
                            .foregroundStyle(Color.brindooError)
                    }

                    BrindooButton("Confermo", style: .primary, size: .large, isLoading: isSaving, isDisabled: !accepted) {
                        Task { await save() }
                    }
                }
                .padding(BrindooSpacing.md)
            }
            .background(Color.brindooBackground)
            .navigationTitle("Professionisti")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled()
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let updated = try await ProfileService.shared.recordProfessionalDeclaration()
            session.updateLocalProfile(updated)
        } catch {
            errorMessage = "Impossibile salvare. Controlla la connessione e riprova."
            BrindooLog.error("recordProfessionalDeclaration: \(error)")
        }
    }
}
