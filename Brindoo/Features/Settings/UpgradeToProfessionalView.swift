//
//  UpgradeToProfessionalView.swift
//  Brindoo
//
//  Schermata di upgrade da Cliente a Professionista.
//  Il cambio è UNIDIREZIONALE: una volta diventato professionista non si torna
//  cliente tramite Impostazioni. L'utente può però annullare l'operazione
//  DURANTE la compilazione del profilo professionista (EditProfileView in
//  modalità post-upgrade), che fa rollback del ruolo a cliente.
//

import SwiftUI

struct UpgradeToProfessionalView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @EnvironmentObject private var toasts: BrindooToastCenter

    @State private var showFinalConfirm: Bool = false
    @State private var isLoading: Bool = false
    @State private var generalError: String?
    @State private var showCelebration: Bool = false
    @State private var showPostUpgradeEdit: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BrindooSpacing.lg) {

                    headerHero

                    benefitsSection

                    warningCard

                    if let generalError {
                        HStack(spacing: BrindooSpacing.xs) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(generalError).font(BrindooFont.bodySmall)
                        }
                        .foregroundStyle(Color.brindooError)
                        .padding(BrindooSpacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.brindooError.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
                    }

                    BrindooButton(
                        "Diventa Professionista",
                        style: .primary,
                        size: .large,
                        icon: "arrow.up.right",
                        isLoading: isLoading
                    ) {
                        showFinalConfirm = true
                    }
                    .padding(.top, BrindooSpacing.md)

                    Button("Annulla") { dismiss() }
                        .font(BrindooFont.bodyMedium.weight(.medium))
                        .foregroundStyle(Color.brindooTextSecondary)
                        .frame(maxWidth: .infinity)
                }
                .padding(BrindooSpacing.lg)
            }
            .background(Color.brindooBackground)
            .navigationTitle("Diventa Professionista")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chiudi") { dismiss() }
                        .disabled(isLoading)
                }
            }
            .confirmationDialog(
                "Confermi il passaggio a Professionista?",
                isPresented: $showFinalConfirm,
                titleVisibility: .visible
            ) {
                Button("Sì, diventa Professionista") {
                    Task { await performUpgrade() }
                }
                Button("Annulla", role: .cancel) {}
            } message: {
                Text("Dopo la conferma dovrai completare il profilo Professionista. Potrai ancora annullare l'operazione da lì se cambi idea.")
            }
            // Animazione celebrativa post-upgrade
            .fullScreenCover(isPresented: $showCelebration) {
                UpgradeCelebrationView {
                    showCelebration = false
                    showPostUpgradeEdit = true
                }
            }
            // Modalità post-upgrade: compila il profilo o annulla
            .fullScreenCover(isPresented: $showPostUpgradeEdit) {
                EditProfileView(isPostUpgrade: true) { didCancel in
                    // didCancel = true → user ha annullato l'operazione (rollback)
                    // didCancel = false → user ha completato il profilo
                    showPostUpgradeEdit = false
                    dismiss() // chiude anche la UpgradeToProfessionalView
                }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var headerHero: some View {
        VStack(spacing: BrindooSpacing.md) {
            ZStack {
                Circle()
                    .fill(Color.brindooCoral.opacity(0.15))
                    .frame(width: 120, height: 120)
                Image(systemName: "sparkles")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.brindooCoral)
            }
            .frame(maxWidth: .infinity)

            Text("Pubblica i tuoi servizi.\nFatti scegliere dai clienti.")
                .font(BrindooFont.titleLarge)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.brindooTextPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, BrindooSpacing.md)
    }

    @ViewBuilder
    private var benefitsSection: some View {
        VStack(spacing: BrindooSpacing.xs) {
            benefitRow(
                icon: "tag.fill",
                title: "Pubblica le tue offerte",
                subtitle: "Saranno visibili in bacheca a tutti i clienti del Lazio."
            )
            benefitRow(
                icon: "bubble.left.and.bubble.right.fill",
                title: "Ricevi richieste e trattative",
                subtitle: "I clienti possono accettare il prezzo o fare controproposte."
            )
            benefitRow(
                icon: "star.fill",
                title: "Costruisci la tua reputazione",
                subtitle: "Recensioni vere lasciate dai clienti dopo il servizio."
            )
            benefitRow(
                icon: "crown.fill",
                title: "Diventa Pro (opzionale)",
                subtitle: "Sblocca offerte illimitate, statistiche e modalità vacanza."
            )
        }
    }

    @ViewBuilder
    private func benefitRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: BrindooSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color.brindooCoral)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BrindooFont.bodyMedium.weight(.semibold))
                    .foregroundStyle(Color.brindooTextPrimary)
                Text(subtitle)
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooTextSecondary)
            }
            Spacer()
        }
        .padding(BrindooSpacing.sm)
        .background(Color.brindooSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
    }

    @ViewBuilder
    private var warningCard: some View {
        HStack(alignment: .top, spacing: BrindooSpacing.sm) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.brindooCoral)
            VStack(alignment: .leading, spacing: BrindooSpacing.xxs) {
                Text("Come funziona")
                    .font(BrindooFont.bodyMedium.weight(.semibold))
                Text("Dopo la conferma ti chiederemo categorie, descrizione e aree di copertura. Potrai annullare in qualsiasi momento durante la compilazione: tornerai cliente come prima.")
                    .font(BrindooFont.bodySmall)
                    .foregroundStyle(Color.brindooTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(BrindooSpacing.md)
        .background(Color.brindooCoral.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
    }

    // MARK: - Action

    private func performUpgrade() async {
        generalError = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let updatedProfile = try await ProfileService.shared.setRole(.organizer)
            session.updateLocalProfile(updatedProfile)
            ProfessionalOnboardingHint.markPendingCompletion()
            // Lancia animazione celebrativa → poi sheet di setup obbligatorio
            showCelebration = true
        } catch {
            generalError = "Impossibile completare il passaggio. Riprova."
            print("❌ Upgrade: \(error)")
        }
    }
}
