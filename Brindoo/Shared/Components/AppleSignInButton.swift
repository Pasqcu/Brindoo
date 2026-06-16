//
//  AppleSignInButton.swift
//  Brindoo
//
//  Bottone "Accedi con account Apple" con gestione completa del flusso.
//  Il testo viene localizzato automaticamente in italiano se l'app è in italiano.
//

import SwiftUI
import AuthenticationServices

/// Stile del bottone Apple
enum BrindooAppleButtonStyle {
    case black
    case white
    case whiteOutline
    
    fileprivate var apple: SignInWithAppleButton.Style {
        switch self {
        case .black: return .black
        case .white: return .white
        case .whiteOutline: return .whiteOutline
        }
    }
    
    fileprivate var progressTint: Color {
        switch self {
        case .black: return .white
        case .white, .whiteOutline: return .black
        }
    }
}

struct AppleSignInButton: View {
    
    var onSuccess: () -> Void = {}
    var onError: (BrindooAuthError) -> Void = { _ in }
    var style: BrindooAppleButtonStyle = .black
    
    @State private var currentNonce: String?
    @State private var isLoading: Bool = false
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Bottone Apple nativo (testo localizzato da iOS in base a CFBundleDevelopmentRegion)
            SignInWithAppleButton(
                .continue,
                onRequest: { request in
                    let nonce = AppleSignInHelper.randomNonceString()
                    currentNonce = nonce
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = AppleSignInHelper.sha256(nonce)
                },
                onCompletion: { result in
                    Task { await handleResult(result) }
                }
            )
            .signInWithAppleButtonStyle(style.apple)
            .frame(height: 56)
            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
            // Bordo corallo lampeggiante per attirare l'attenzione
            .overlay(
                RoundedRectangle(cornerRadius: BrindooRadius.md)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.brindooCoral, Color.brindooCoralDark, Color.brindooCoral],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 2.5
                    )
                    .scaleEffect(pulseScale)
                    .opacity(2.0 - pulseScale)
            )
            .disabled(isLoading)
            .opacity(isLoading ? 0.6 : 1.0)
            .onAppear {
                // Animazione "pulse" del bordo per attirare l'attenzione
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                    pulseScale = 1.06
                }
            }
            
            if isLoading {
                ProgressView()
                    .tint(style.progressTint)
            }
        }
    }
    
    // MARK: - Gestione risultato
    
    private func handleResult(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            await processAuthorization(authorization)
            
        case .failure(let error):
            if let asError = error as? ASAuthorizationError {
                switch asError.code {
                case .canceled:
                    onError(.appleSignInCancelled)
                default:
                    onError(.appleSignInFailed)
                }
            } else {
                onError(.appleSignInFailed)
            }
        }
    }
    
    private func processAuthorization(_ authorization: ASAuthorization) async {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            onError(.appleSignInFailed)
            return
        }
        
        guard let nonce = currentNonce else {
            print("⚠️ Nessun nonce disponibile, flusso compromesso")
            onError(.appleSignInFailed)
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await AuthService.shared.signInWithApple(credential: credential, nonce: nonce)
            onSuccess()
        } catch let error as BrindooAuthError {
            onError(error)
        } catch {
            onError(.appleSignInFailed)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        AppleSignInButton(style: .black)
        AppleSignInButton(style: .white)
    }
    .padding()
}
