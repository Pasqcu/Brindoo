//
//  GoogleSignInButton.swift
//  Brindoo
//
//  Bottone "Continua con Google". Aderisce alle linee guida di Google:
//  fondo bianco, bordo grigio, testo scuro, logo a sinistra.
//
//  Il logo ufficiale va messo negli Asset con nome "GoogleLogo" (Google lo
//  distribuisce nel suo kit di branding, non è ridisegnabile a mano). Se
//  l'immagine non c'è il bottone resta corretto e leggibile, solo senza
//  marchio: meglio un bottone senza logo che un logo sbagliato.
//

import SwiftUI

struct GoogleSignInButton: View {

    var onSuccess: () -> Void = {}
    var onError: (BrindooAuthError) -> Void = { _ in }

    @State private var isLoading: Bool = false

    /// Il logo ufficiale è presente negli Asset?
    private var hasOfficialLogo: Bool {
        UIImage(named: "GoogleLogo") != nil
    }

    var body: some View {
        Button {
            Task { await signIn() }
        } label: {
            HStack(spacing: BrindooSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(.black)
                } else {
                    logo
                    Text("Continua con Google")
                        .font(BrindooFont.button)
                        .foregroundStyle(Color(white: 0.15))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: BrindooRadius.md)
                    .strokeBorder(Color(white: 0.85), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .opacity(isLoading ? 0.6 : 1)
        .accessibilityLabel("Continua con Google")
    }

    @ViewBuilder
    private var logo: some View {
        if hasOfficialLogo {
            Image("GoogleLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
        } else {
            // Segnaposto neutro: nessuna imitazione del marchio.
            Image(systemName: "person.crop.circle")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(Color(white: 0.35))
        }
    }

    private func signIn() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AuthService.shared.signInWithGoogle()
            onSuccess()
        } catch let error as BrindooAuthError {
            onError(error)
        } catch {
            onError(.googleSignInFailed)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        GoogleSignInButton()
        AppleSignInButton(style: .black)
    }
    .padding()
}
