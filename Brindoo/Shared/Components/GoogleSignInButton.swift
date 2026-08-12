//
//  GoogleSignInButton.swift
//  Brindoo
//
//  Bottone "Continua con Google". Ricalca il bottone Apple nativo, che è
//  l'unico dei due a non essere personalizzabile: pieno scuro col tema chiaro,
//  pieno chiaro col tema scuro, stessa altezza, stesso raggio, stesso corpo del
//  testo. Google ammette entrambe le varianti (chiara e scura) purché il logo
//  resti il suo e il testo dica "Continua con Google".
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

    @Environment(\.colorScheme) private var colorScheme

    /// Il bottone Apple nativo è pieno nero col tema chiaro e pieno bianco con
    /// quello scuro: qui si copiano quei due fondi, senza bordo, così affiancati
    /// non si distingue quale sia quello di sistema.
    private var background: Color {
        colorScheme == .dark ? .white : .black
    }

    private var foreground: Color {
        colorScheme == .dark ? .black : .white
    }

    var body: some View {
        Button {
            Task { await signIn() }
        } label: {
            HStack(spacing: BrindooSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(foreground)
                } else {
                    logo
                    Text("Continua con Google")
                        .font(.system(size: BrindooLayout.socialButtonTitleSize, weight: .medium))
                        .foregroundStyle(foreground)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: BrindooLayout.socialButtonHeight)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
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
                .frame(
                    width: BrindooLayout.socialButtonTitleSize,
                    height: BrindooLayout.socialButtonTitleSize
                )
        } else {
            // Segnaposto neutro: nessuna imitazione del marchio.
            Image(systemName: "person.crop.circle")
                .font(.system(size: BrindooLayout.socialButtonTitleSize - 2, weight: .medium))
                .foregroundStyle(foreground.opacity(0.8))
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
