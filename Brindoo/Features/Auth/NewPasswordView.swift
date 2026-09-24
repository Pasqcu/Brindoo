//
//  NewPasswordView.swift
//  Brindoo
//
//  Si apre dal link "Password dimenticata". Il link ha già fatto entrare
//  l'utente: qui sceglie la nuova password, altrimenti resterebbe dentro
//  senza conoscerla e al prossimo accesso sarebbe di nuovo bloccato.
//

import SwiftUI

struct NewPasswordView: View {

    let recovery: PasswordRecovery

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var toastCenter: BrindooToastCenter

    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var passwordError: String?
    @State private var confirmError: String?
    @State private var generalError: String?
    @State private var isSaving = false

    private var validation: PasswordValidation {
        AuthService.shared.validatePassword(password)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BrindooSpacing.lg) {
                    switch recovery {
                    case .ready: form
                    case .linkInvalid: invalidLink
                    }
                }
                .padding(BrindooSpacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.brindooBackground)
            .navigationTitle(recovery == .ready ? "Nuova password" : "Link non valido")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(recovery == .ready ? BrindooText.cancel : BrindooText.close) { dismiss() }
                        .disabled(isSaving)
                }
            }
        }
        // Scegliere la password è il motivo per cui l'utente è qui: niente
        // chiusura per sbaglio con un trascinamento.
        .interactiveDismissDisabled(recovery == .ready)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.md) {
            Text("Scegli la nuova password per il tuo account.")
                .font(BrindooFont.bodyLarge)
                .foregroundStyle(Color.brindooTextSecondary)

            BrindooTextField(
                title: "Nuova password",
                placeholder: "Almeno 8 caratteri",
                text: $password,
                icon: "lock",
                isSecure: true,
                textContentType: .newPassword,
                autocapitalization: .never,
                errorMessage: passwordError,
                isDisabled: isSaving,
                showPasswordToggle: true
            )

            if !password.isEmpty {
                PasswordStrengthView(validation: validation)
            }

            BrindooTextField(
                title: "Conferma password",
                placeholder: "Ripeti la password",
                text: $confirmPassword,
                icon: "lock.shield",
                isSecure: true,
                textContentType: .newPassword,
                autocapitalization: .never,
                errorMessage: confirmError,
                isDisabled: isSaving,
                showPasswordToggle: true
            )

            if let generalError {
                BrindooInlineError(generalError)
            }

            BrindooButton("Salva password", size: .large, isLoading: isSaving, isDisabled: password.isEmpty || confirmPassword.isEmpty) {
                Task { await save() }
            }
            .padding(.top, BrindooSpacing.sm)
        }
    }

    private var invalidLink: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.md) {
            Image(systemName: "link.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(Color.brindooWarning)
            Text("Questo link per reimpostare la password non è più valido.")
                .font(BrindooFont.titleSmall)
            // PKCE: il codice del link si scambia solo con il segreto rimasto
            // sul telefono che ha fatto la richiesta.
            Text("Il link vale un'ora e si apre solo sull'iPhone da cui hai chiesto il reset. Torna su \"Password dimenticata\" e richiedine uno nuovo.")
                .font(BrindooFont.bodyMedium)
                .foregroundStyle(Color.brindooTextSecondary)
        }
    }

    private func save() async {
        passwordError = nil
        confirmError = nil
        generalError = nil

        guard validation.isValid else {
            passwordError = "La password non rispetta tutti i requisiti"
            return
        }
        guard password == confirmPassword else {
            confirmError = "Le password non coincidono"
            return
        }

        isSaving = true
        defer { isSaving = false }
        do {
            try await AuthService.shared.updatePassword(password)
            BrindooHaptics.notify(.success)
            toastCenter.show(BrindooToast("Password aggiornata", style: .success))
            dismiss()
        } catch let error as BrindooAuthError {
            generalError = error.errorDescription
        } catch {
            generalError = BrindooErrorText.message(for: error, fallback: BrindooText.saveError("la nuova password"))
        }
    }
}
