//
//  SignUpView.swift
//

import SwiftUI

struct SignUpView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""

    /// Conferma di avere 18+ anni e di accettare ToS/PP.
    /// Richiesto da Apple App Store Guideline 1.2 e dai nostri Termini (punto 3).
    /// Persistito in UserDefaults così è condiviso tra SignUpView, LoginView,
    /// OnboardingView e sopravvive a riavvii dell'app.
    @AppStorage("brindoo.legal.acceptedTermsAt") private var acceptedTermsAt: String = ""
    @State private var showTerms: Bool = false
    @State private var showPrivacy: Bool = false

    private var acceptedTermsAndAge: Bool {
        !acceptedTermsAt.isEmpty
    }

    @State private var emailError: String?
    @State private var passwordError: String?
    @State private var confirmPasswordError: String?
    @State private var generalError: String?
    @State private var isLoading: Bool = false
    @State private var showSuccessMessage: Bool = false

    private var passwordValidation: PasswordValidation {
        AuthService.shared.validatePassword(password)
    }

    /// Le password si sbloccano solo se l'email è completa
    private var arePasswordsEnabled: Bool {
        email.trimmingCharacters(in: .whitespaces).isCompleteEmail
    }

    /// Il bottone "Crea account" è abilitato solo se:
    /// - email valida
    /// - checkbox accettata
    private var canSubmit: Bool {
        arePasswordsEnabled && acceptedTermsAndAge
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrindooSpacing.lg) {

                BrindooAuthHero(subtitle: "Crea il tuo account gratuito")
                    .frame(maxWidth: .infinity)
                    .padding(.top, BrindooSpacing.md)

                if showSuccessMessage {
                    successView
                } else {
                    formView
                }

                Spacer(minLength: BrindooSpacing.xl)
            }
            .padding(.horizontal, BrindooSpacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.brindooBackground)
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.brindooTextPrimary)
                }
            }
        }
        .sheet(isPresented: $showTerms) {
            NavigationStack {
                TermsOfServiceView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Chiudi") { showTerms = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showPrivacy) {
            NavigationStack {
                PrivacyPolicyView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Chiudi") { showPrivacy = false }
                        }
                    }
            }
        }
    }
    
    @ViewBuilder
    private var formView: some View {
        VStack(spacing: BrindooSpacing.md) {

            // Sign in with Apple — richiede T&C come l'email/password.
            // La checkbox di accettazione è in fondo al form: finché non viene
            // spuntata, il bottone Apple resta visibile ma disabilitato.
            AppleSignInButton { } onError: { error in
                if error != .appleSignInCancelled {
                    generalError = error.errorDescription
                }
            }
            .disabled(!acceptedTermsAndAge || isLoading)
            .opacity(acceptedTermsAndAge ? 1 : 0.4)
            .allowsHitTesting(acceptedTermsAndAge && !isLoading)

            HStack {
                Rectangle().fill(Color.brindooBorder).frame(height: 1)
                Text("oppure")
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooTextSecondary)
                    .padding(.horizontal, BrindooSpacing.sm)
                Rectangle().fill(Color.brindooBorder).frame(height: 1)
            }
            .padding(.vertical, BrindooSpacing.xs)

            BrindooTextField(
                title: "Email",
                placeholder: "tuo@email.it",
                text: $email,
                icon: "envelope",
                keyboardType: .emailAddress,
                textContentType: .emailAddress,
                autocapitalization: .never,
                errorMessage: emailError,
                isDisabled: isLoading
            )
            
            // Banner che spiega perché le password sono bloccate
            if !arePasswordsEnabled && !email.isEmpty {
                HStack(spacing: BrindooSpacing.xs) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(Color.brindooTextSecondary)
                    Text("Completa prima l'email per impostare la password")
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextSecondary)
                    Spacer()
                }
            }
            
            VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
                BrindooTextField(
                    title: "Password",
                    placeholder: arePasswordsEnabled ? "Almeno 8 caratteri" : "Inserisci prima l'email",
                    text: $password,
                    icon: "lock",
                    isSecure: true,
                    textContentType: .newPassword,
                    autocapitalization: .never,
                    errorMessage: passwordError,
                    isDisabled: isLoading || !arePasswordsEnabled,
                    showPasswordToggle: arePasswordsEnabled
                )
                
                if !password.isEmpty && arePasswordsEnabled {
                    passwordStrengthIndicator
                }
            }
            
            BrindooTextField(
                title: "Conferma password",
                placeholder: "Ripeti la password",
                text: $confirmPassword,
                icon: "lock.shield",
                isSecure: true,
                textContentType: .newPassword,
                autocapitalization: .never,
                errorMessage: confirmPasswordError,
                isDisabled: isLoading || !arePasswordsEnabled,
                showPasswordToggle: arePasswordsEnabled
            )
            
            if let generalError {
                HStack(spacing: BrindooSpacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(generalError)
                        .font(BrindooFont.bodySmall)
                }
                .foregroundStyle(Color.brindooError)
                .padding(BrindooSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.brindooError.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
            }
            
            consentCheckbox
                .padding(.top, BrindooSpacing.sm)

            BrindooButton(
                "Crea account",
                style: .primary,
                size: .large,
                isLoading: isLoading,
                isDisabled: !canSubmit
            ) {
                Task { await performSignUp() }
            }
            .padding(.top, BrindooSpacing.sm)
        }
    }

    @ViewBuilder
    private var consentCheckbox: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                acceptedTermsAt = acceptedTermsAndAge
                    ? ""
                    : ISO8601DateFormatter().string(from: Date())
            }
        } label: {
            HStack(alignment: .top, spacing: BrindooSpacing.sm) {
                Image(systemName: acceptedTermsAndAge ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22))
                    .foregroundStyle(
                        acceptedTermsAndAge ? Color.brindooCoral : Color.brindooBorder
                    )
                    .frame(width: 24, height: 24)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: BrindooSpacing.xxs) {
                    Text("Confermo di avere almeno 18 anni e accetto i Termini di Servizio e la Privacy Policy di Brindoo.")
                        .font(BrindooFont.bodySmall)
                        .foregroundStyle(Color.brindooTextPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: BrindooSpacing.sm) {
                        Button("Leggi i Termini") {
                            showTerms = true
                        }
                        .font(BrindooFont.caption.weight(.semibold))
                        .foregroundStyle(Color.brindooCoral)

                        Text("•")
                            .foregroundStyle(Color.brindooTextSecondary)

                        Button("Leggi la Privacy Policy") {
                            showPrivacy = true
                        }
                        .font(BrindooFont.caption.weight(.semibold))
                        .foregroundStyle(Color.brindooCoral)
                    }
                }
            }
            .padding(BrindooSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.brindooSurface)
            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
    
    @ViewBuilder
    private var passwordStrengthIndicator: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Rectangle()
                        .fill(index < passwordValidation.strengthLevel ? strengthColor : Color.brindooBorder)
                        .frame(height: 4)
                        .clipShape(Capsule())
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                requirementRow(text: "Almeno 8 caratteri", met: passwordValidation.hasMinLength)
                requirementRow(text: "Almeno un numero", met: passwordValidation.hasNumber)
                requirementRow(text: "Almeno un carattere speciale (es. !@#$)", met: passwordValidation.hasSpecialChar)
            }
        }
        .padding(BrindooSpacing.sm)
        .background(Color.brindooSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
    }
    
    private var strengthColor: Color {
        switch passwordValidation.strengthLevel {
        case 0, 1: return .brindooError
        case 2: return .brindooWarning
        case 3: return .brindooSuccess
        default: return .brindooBorder
        }
    }
    
    @ViewBuilder
    private func requirementRow(text: String, met: Bool) -> some View {
        HStack(spacing: BrindooSpacing.xxs) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 12))
                .foregroundStyle(met ? Color.brindooSuccess : Color.brindooTextSecondary)
            Text(text)
                .font(BrindooFont.caption)
                .foregroundStyle(met ? Color.brindooTextPrimary : Color.brindooTextSecondary)
        }
    }
    
    @ViewBuilder
    private var successView: some View {
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
            
            Text("Ti abbiamo inviato un link di conferma a:\n\(email)\n\nClicca sul link per attivare il tuo account.")
                .font(BrindooFont.bodyLarge)
                .foregroundStyle(Color.brindooTextSecondary)
                .multilineTextAlignment(.center)
            
            BrindooButton("Torna al login", style: .secondary, size: .large) {
                dismiss()
            }
            .padding(.top, BrindooSpacing.lg)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func performSignUp() async {
        emailError = nil
        passwordError = nil
        confirmPasswordError = nil
        generalError = nil

        guard acceptedTermsAndAge else {
            generalError = "Devi confermare di avere 18+ anni e accettare i Termini per registrarti."
            return
        }

        if email.isEmpty {
            emailError = "Inserisci la tua email"
            return
        }
        guard email.isCompleteEmail else {
            emailError = "Inserisci un'email valida"
            return
        }
        
        if password.isEmpty {
            passwordError = "Inserisci una password"
            return
        }
        
        let validation = passwordValidation
        if !validation.hasMinLength { passwordError = "Almeno 8 caratteri"; return }
        if !validation.hasNumber { passwordError = "Manca un numero"; return }
        if !validation.hasSpecialChar { passwordError = "Manca un carattere speciale"; return }
        
        if confirmPassword.isEmpty {
            confirmPasswordError = "Conferma la password"
            return
        }
        guard password == confirmPassword else {
            confirmPasswordError = "Le password non coincidono"
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await AuthService.shared.signUp(email: email, password: password)
            showSuccessMessage = true
        } catch let error as BrindooAuthError {
            generalError = error.errorDescription
        } catch {
            generalError = error.localizedDescription
        }
    }
}
