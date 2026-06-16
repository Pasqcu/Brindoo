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
    @State private var showTerms: Bool = false
    @State private var showPrivacy: Bool = false

    private var hasAcceptedTerms: Bool {
        !acceptedTermsAt.isEmpty
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrindooSpacing.lg) {
                
                VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
                    Text("Bentornato")
                        .font(BrindooFont.displayMedium)
                    Text("Accedi al tuo account Brindoo")
                        .font(BrindooFont.bodyLarge)
                        .foregroundStyle(Color.brindooTextSecondary)
                }
                .padding(.top, BrindooSpacing.lg)
                
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
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.brindooTextPrimary)
                }
            }
        }
        .navigationDestination(isPresented: $navigateToSignUp) {
            SignUpView()
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
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
    private var consentCheckbox: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                acceptedTermsAt = hasAcceptedTerms
                    ? ""
                    : ISO8601DateFormatter().string(from: Date())
            }
        } label: {
            HStack(alignment: .top, spacing: BrindooSpacing.sm) {
                Image(systemName: hasAcceptedTerms ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundStyle(
                        hasAcceptedTerms ? Color.brindooCoral : Color.brindooBorder
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Confermo di avere almeno 18 anni e di accettare i Termini e la Privacy Policy di Brindoo.")
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: BrindooSpacing.xs) {
                        Button("Termini") { showTerms = true }
                            .font(BrindooFont.caption.weight(.semibold))
                            .foregroundStyle(Color.brindooCoral)
                        Text("•").foregroundStyle(Color.brindooTextSecondary)
                        Button("Privacy") { showPrivacy = true }
                            .font(BrindooFont.caption.weight(.semibold))
                            .foregroundStyle(Color.brindooCoral)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(BrindooSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.brindooSurface)
            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
        }
        .buttonStyle(.plain)
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
