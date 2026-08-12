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
    /// Segue il tema: pieno scuro col tema chiaro, pieno chiaro col tema scuro.
    /// È lo stile che tiene il bottone Apple e quello Google identici.
    case automatic
    case black
    case white
    case whiteOutline

    fileprivate func apple(for scheme: ColorScheme) -> SignInWithAppleButton.Style {
        switch self {
        case .automatic: return scheme == .dark ? .white : .black
        case .black: return .black
        case .white: return .white
        case .whiteOutline: return .whiteOutline
        }
    }

    fileprivate func progressTint(for scheme: ColorScheme) -> Color {
        switch self {
        case .automatic: return scheme == .dark ? .black : .white
        case .black: return .white
        case .white, .whiteOutline: return .black
        }
    }
}

struct AppleSignInButton: View {
    
    var onSuccess: () -> Void = {}
    var onError: (BrindooAuthError) -> Void = { _ in }
    var style: BrindooAppleButtonStyle = .automatic
    
    @State private var currentNonce: String?
    @State private var isLoading: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    
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
            .signInWithAppleButtonStyle(style.apple(for: colorScheme))
            // Il bottone di sistema legge lo stile solo quando nasce: al cambio
            // di tema non si ridipinge da solo e resterebbe bianco su chiaro
            // (o nero su scuro), cioè invisibile. L'id lo fa ricreare.
            .id(colorScheme)
            .frame(height: BrindooLayout.socialButtonHeight)
            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
            .disabled(isLoading)
            .opacity(isLoading ? 0.6 : 1.0)

            if isLoading {
                ProgressView()
                    .tint(style.progressTint(for: colorScheme))
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
            BrindooLog.error("Nessun nonce disponibile, flusso compromesso")
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
