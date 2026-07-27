//
//  LoginView.swift
//

import SwiftUI

struct LoginView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var email: String = ""
    @State private var password: String = ""

    @State private var emailError: String?
    @State private var passwordError: String?
    @State private var generalError: String?
    @State private var isLoading: Bool = false
    @State private var showForgotPassword: Bool = false
    @State private var navigateToSignUp: Bool = false

    /// Accettazione persistita. Se vuota significa che l'utente non l'ha ancora
    /// accettata su questo dispositivo (es. dopo reinstallazione): mostriamo
    /// comunque la checkbox prima di consentire Apple Sign In o login.
    @AppStorage("brindoo.legal.acceptedTermsAt") private var acceptedTermsAt: String = ""
    @State private var legalDocument: LegalDocument?

    private var hasAcceptedTerms: Bool {
        !acceptedTermsAt.isEmpty
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrindooSpacing.lg) {

                BrindooAuthHero(subtitle: "Bentornato! Accedi al tuo account")
                    .frame(maxWidth: .infinity)
                    .padding(.top, BrindooSpacing.md)
                
                if !hasAcceptedTerms {
                    consentCheckbox
                        .padding(.top, BrindooSpacing.md)
                }

                // Sign in with Apple
                AppleSignInButton { } onError: { error in
                    if error != .appleSignInCancelled {
                        generalError = error.errorDescription
                    }
                }
                .padding(.top, BrindooSpacing.md)
                .disabled(!hasAcceptedTerms)
                .opacity(hasAcceptedTerms ? 1 : 0.4)
                .allowsHitTesting(hasAcceptedTerms)

                // Accesso con Google, alle stesse condizioni di quello Apple.
                GoogleSignInButton { } onError: { error in
                    if error != .googleSignInCancelled {
                        generalError = error.errorDescription
                    }
                }
                .padding(.top, BrindooSpacing.xs)
                .disabled(!hasAcceptedTerms)
                .opacity(hasAcceptedTerms ? 1 : 0.4)
                .allowsHitTesting(hasAcceptedTerms)
                
                HStack {
                    Rectangle().fill(Color.brindooBorder).frame(height: 1)
                    Text("oppure")
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextSecondary)
                        .padding(.horizontal, BrindooSpacing.sm)
                    Rectangle().fill(Color.brindooBorder).frame(height: 1)
                }
                .padding(.vertical, BrindooSpacing.sm)
                
                VStack(spacing: BrindooSpacing.md) {
                    BrindooEmailField(
                        text: $email,
                        errorMessage: emailError,
                        isDisabled: isLoading
                    )
                    
                    BrindooTextField(
                        title: "Password",
                        placeholder: "La tua password",
                        text: $password,
                        icon: "lock",
                        isSecure: true,
                        textContentType: .password,
                        autocapitalization: .never,
                        errorMessage: passwordError,
                        isDisabled: isLoading,
                        showPasswordToggle: true
                    )
                    
                    HStack {
                        Spacer()
                        Button("Password dimenticata?") {
                            showForgotPassword = true
                        }
                        .font(BrindooFont.bodySmall.weight(.medium))
                        .foregroundStyle(Color.brindooCoral)
                    }
                    
                    if let generalError {
                        BrindooInlineError(generalError)
                    }
                    
                    BrindooButton(
                        "Accedi",
                        style: .primary,
                        size: .large,
                        isLoading: isLoading,
                        isDisabled: !hasAcceptedTerms
                    ) {
                        Task { await performLogin() }
                    }
                    .padding(.top, BrindooSpacing.sm)
                }
                
                HStack(spacing: BrindooSpacing.xxs) {
                    Text("Non hai un account?")
                        .font(BrindooFont.bodyMedium)
                        .foregroundStyle(Color.brindooTextSecondary)
                    Button {
                        navigateToSignUp = true
                    } label: {
                        Text("Registrati")
                            .font(BrindooFont.bodyMedium.weight(.semibold))
                            .foregroundStyle(Color.brindooCoral)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, BrindooSpacing.lg)
                
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
                    Image(systemName: BrindooIcon.back)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.brindooTextPrimary)
                }
                .accessibilityLabel("Indietro")
            }
        }
        .navigationDestination(isPresented: $navigateToSignUp) {
            SignUpView()
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
        .sheet(item: $legalDocument) { LegalDocumentSheet(document: $0) }
    }

    @ViewBuilder
    private var consentCheckbox: some View {
        // I link ai documenti stanno fuori dal pulsante della spunta: dentro il suo
        // label il tocco verrebbe intercettato e non si aprirebbero mai.
        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
            Button {
                withAnimation(BrindooAnimation.quickEase) {
                    acceptedTermsAt = hasAcceptedTerms
                        ? ""
                        : BrindooFormat.isoNow
                }
            } label: {
                HStack(alignment: .top, spacing: BrindooSpacing.sm) {
                    Image(systemName: hasAcceptedTerms ? "checkmark.square.fill" : "square")
                        .font(.system(size: 20))
                        .foregroundStyle(
                            hasAcceptedTerms ? Color.brindooCoral : Color.brindooBorder
                        )

                    Text("Confermo di avere almeno 18 anni e di accettare i Termini e la Privacy Policy di Brindoo.")
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(hasAcceptedTerms ? [.isSelected] : [])

            HStack(spacing: BrindooSpacing.xs) {
                Button("Termini") { legalDocument = .terms }
                    .font(BrindooFont.caption.weight(.semibold))
                    .foregroundStyle(Color.brindooCoral)
                Text("•").foregroundStyle(Color.brindooTextSecondary)
                Button("Privacy") { legalDocument = .privacy }
                    .font(BrindooFont.caption.weight(.semibold))
                    .foregroundStyle(Color.brindooCoral)
            }
            .buttonStyle(.plain)
            .padding(.leading, 20 + BrindooSpacing.sm)
        }
        .padding(BrindooSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brindooSurfaceBackground()
    }
    
    private func performLogin() async {
        emailError = nil
        passwordError = nil
        generalError = nil
        
        if email.isEmpty {
            emailError = "Inserisci la tua email"
            return
        }
        if password.isEmpty {
            passwordError = "Inserisci la password"
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await AuthService.shared.signIn(email: email, password: password)
        } catch let error as BrindooAuthError {
            generalError = error.errorDescription
        } catch {
            generalError = error.localizedDescription
        }
    }
}

// MARK: - Forgot Password

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email: String = ""
    @State private var emailError: String?
    @State private var generalError: String?
    @State private var isLoading: Bool = false
    @State private var showSuccess: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BrindooSpacing.lg) {
                    if showSuccess {
                        VStack(spacing: BrindooSpacing.lg) {
                            Image(systemName: "envelope.badge.fill")
                                .font(.system(size: 64))
                                .foregroundStyle(Color.brindooSuccess)
                            Text("Email inviata")
                                .font(BrindooFont.titleLarge)
                            Text("Controlla la tua casella per il link di reset.")
                                .font(BrindooFont.bodyLarge)
                                .foregroundStyle(Color.brindooTextSecondary)
                                .multilineTextAlignment(.center)
                            BrindooButton("Chiudi", style: .primary, size: .large) {
                                dismiss()
                            }
                            .padding(.top, BrindooSpacing.lg)
                        }
                        .padding(.top, BrindooSpacing.xl)
                    } else {
                        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
                            Text("Recupera password")
                                .font(BrindooFont.displayMedium)
                            Text("Ti invieremo un link per impostare una nuova password")
                                .font(BrindooFont.bodyLarge)
                                .foregroundStyle(Color.brindooTextSecondary)
                        }
                        
                        BrindooEmailField(
                            text: $email,
                            errorMessage: emailError,
                            isDisabled: isLoading
                        )
                        
                        if let generalError {
                            Text(generalError)
                                .font(BrindooFont.bodySmall)
                                .foregroundStyle(Color.brindooError)
                        }
                        
                        BrindooButton("Invia link di recupero", style: .primary, size: .large, isLoading: isLoading) {
                            Task { await sendReset() }
                        }
                    }
                }
                .padding(BrindooSpacing.lg)
            }
            .background(Color.brindooBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }
    
    private func sendReset() async {
        emailError = nil
        generalError = nil
        
        guard !email.isEmpty else {
            emailError = "Inserisci la tua email"
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await AuthService.shared.resetPassword(email: email)
            showSuccess = true
        } catch let error as BrindooAuthError {
            generalError = error.errorDescription
        } catch {
            generalError = error.localizedDescription
        }
    }
}
