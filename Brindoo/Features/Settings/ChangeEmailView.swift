//
//  ChangeEmailView.swift
//  Brindoo
//
//  Schermata per cambiare l'email associata all'account. Supabase invia un
//  link di conferma al nuovo indirizzo: il cambio è effettivo solo dopo il tap.
//

import SwiftUI

struct ChangeEmailView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session

    @State private var newEmail: String = ""
    @State private var emailError: String?
    @State private var generalError: String?
    @State private var isLoading: Bool = false
    @State private var showConfirm: Bool = false
    @State private var success: Bool = false

    private var currentEmail: String {
        session.userEmail ?? "—"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BrindooSpacing.lg) {

                    if success {
                        successCard
                    } else {
                        formCard
                    }
                }
                .padding(BrindooSpacing.lg)
            }
            .background(Color.brindooBackground)
            .navigationTitle("Cambia email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chiudi") { dismiss() }
                        .disabled(isLoading)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    // MARK: - Form

    @ViewBuilder
    private var formCard: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.md) {

            VStack(alignment: .leading, spacing: 4) {
                Text("Email attuale")
                    .font(BrindooFont.caption.weight(.medium))
                    .foregroundStyle(Color.brindooTextSecondary)
                Text(currentEmail)
                    .font(BrindooFont.bodyLarge)
                    .foregroundStyle(Color.brindooTextPrimary)
            }
            .padding(BrindooSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.brindooSurface)
            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))

            BrindooTextField(
                title: "Nuova email",
                placeholder: "nuova@email.it",
                text: $newEmail,
                icon: "envelope",
                keyboardType: .emailAddress,
                textContentType: .emailAddress,
                autocapitalization: .never,
                errorMessage: emailError,
                isDisabled: isLoading
            )

            HStack(alignment: .top, spacing: BrindooSpacing.xs) {
                Image(systemName: "info.circle")
                    .foregroundStyle(Color.brindooCoral)
                Text("Ti invieremo un link di conferma al nuovo indirizzo. Il cambio sarà effettivo solo dopo aver cliccato sul link.")
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooTextSecondary)
            }

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
                "Invia link di conferma",
                style: .primary,
                size: .large,
                isLoading: isLoading,
                isDisabled: newEmail.trimmingCharacters(in: .whitespaces).isEmpty
            ) {
                showConfirm = true
            }
            .padding(.top, BrindooSpacing.sm)
        }
        .confirmationDialog(
            "Confermi il cambio email?",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button("Invia conferma") {
                Task { await performUpdate() }
            }
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("Riceverai un'email a \(newEmail.trimmingCharacters(in: .whitespaces).lowercased()). Il cambio sarà effettivo solo dopo aver cliccato sul link.")
        }
    }

    @ViewBuilder
    private var successCard: some View {
        VStack(spacing: BrindooSpacing.lg) {
            ZStack {
                Circle()
                    .fill(Color.brindooSuccess.opacity(0.15))
                    .frame(width: 100, height: 100)
                Image(systemName: "envelope.badge.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.brindooSuccess)
            }
            .padding(.top, BrindooSpacing.xl)

            Text("Controlla la tua email")
                .font(BrindooFont.titleLarge)

            Text("Ti abbiamo inviato un link di conferma a:\n\(newEmail)\n\nClicca sul link per attivare il cambio.")
                .font(BrindooFont.bodyLarge)
                .foregroundStyle(Color.brindooTextSecondary)
                .multilineTextAlignment(.center)

            BrindooButton("Chiudi", style: .secondary, size: .large) {
                dismiss()
            }
            .padding(.top, BrindooSpacing.lg)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Action

    private func performUpdate() async {
        emailError = nil
        generalError = nil

        let trimmed = newEmail.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            emailError = "Inserisci la nuova email"
            return
        }
        guard trimmed.lowercased() != currentEmail.lowercased() else {
            emailError = "La nuova email è uguale a quella attuale"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await AuthService.shared.updateEmail(trimmed)
            success = true
        } catch let error as BrindooAuthError {
            generalError = error.errorDescription
        } catch {
            generalError = "Impossibile inviare il link di conferma. Riprova."
        }
    }
}
