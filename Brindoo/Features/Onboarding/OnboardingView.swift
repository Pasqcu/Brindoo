//
//  OnboardingView.swift
//  Brindoo
//
//  3 slide intro mostrate ai nuovi utenti.
//  Navigazione: swipe orizzontale o tap sui dots indicatori in basso.
//

import SwiftUI

struct OnboardingView: View {

    @State private var currentSlide: Int = 0
    @State private var navigateToLogin: Bool = false
    @State private var navigateToSignUp: Bool = false

    /// Persistito in UserDefaults una volta accettato. Una volta che l'utente
    /// accetta, i bottoni di proseguimento si abilitano e l'accettazione resta
    /// valida finché non disinstalla l'app o resetta il dispositivo.
    @AppStorage("brindoo.legal.acceptedTermsAt") private var acceptedTermsAt: String = ""

    /// Stato visivo della checkbox. Sincronizzato con AppStorage.
    @State private var acceptedTermsAndAge: Bool = false
    @State private var showTerms: Bool = false
    @State private var showPrivacy: Bool = false

    private var isLastSlide: Bool {
        currentSlide >= slides.count - 1
    }

    private let slides: [OnboardingSlide] = [
        OnboardingSlide(
            icon: "party.popper.fill",
            title: "Benvenuto in Brindoo",
            description: "Il marketplace per organizzare feste ed eventi memorabili."
        ),
        OnboardingSlide(
            icon: "magnifyingglass.circle.fill",
            title: "Trova il professionista giusto",
            description: "Animatori, fotografi, catering, location: tutto a portata di tap."
        ),
        OnboardingSlide(
            icon: "sparkles",
            title: "O fatti trovare",
            description: "Sei un organizzatore? Crea il tuo profilo e ricevi richieste dai clienti."
        )
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brindooBackground.ignoresSafeArea()
                
                VStack {
                    // Skip button in alto a destra (tranne ultima slide)
                    HStack {
                        Spacer()
                        if currentSlide < slides.count - 1 {
                            Button("Salta") {
                                withAnimation {
                                    currentSlide = slides.count - 1
                                }
                            }
                            .font(BrindooFont.bodyMedium.weight(.medium))
                            .foregroundStyle(Color.brindooTextSecondary)
                            .padding()
                        } else {
                            // Placeholder per mantenere altezza
                            Text(" ")
                                .padding()
                        }
                    }
                    
                    Spacer()
                    
                    // TabView con le slide
                    TabView(selection: $currentSlide) {
                        ForEach(slides.indices, id: \.self) { index in
                            slideView(slides[index])
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    
                    // Pagination dots — cliccabili per saltare a una slide
                    HStack(spacing: BrindooSpacing.xs) {
                        ForEach(slides.indices, id: \.self) { index in
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    currentSlide = index
                                }
                            } label: {
                                Capsule()
                                    .fill(currentSlide == index ? Color.brindooCoral : Color.brindooBorder)
                                    .frame(width: currentSlide == index ? 24 : 8, height: 8)
                                    .animation(.easeInOut(duration: 0.2), value: currentSlide)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Vai alla slide \(index + 1)")
                        }
                    }
                    .padding(.vertical, BrindooSpacing.lg)
                    
                    // Bottoni: layout fisso per evitare sfasamento tra slide
                    VStack(spacing: BrindooSpacing.sm) {
                        // Checkbox di accettazione visibile solo nell'ultima slide.
                        // Mantiene comunque spazio per non far saltare il layout.
                        consentCheckbox
                            .opacity(isLastSlide ? 1 : 0)
                            .animation(.easeInOut(duration: 0.2), value: isLastSlide)

                        BrindooButton(
                            isLastSlide ? "Inizia ora" : "Continua",
                            style: .primary,
                            size: .large,
                            isDisabled: isLastSlide && !acceptedTermsAndAge
                        ) {
                            if isLastSlide {
                                navigateToSignUp = true
                            } else {
                                withAnimation {
                                    currentSlide += 1
                                }
                            }
                        }

                        // "Hai già un account?" sempre presente per mantenere altezza
                        // costante; visibile solo nell'ultima slide.
                        HStack(spacing: BrindooSpacing.xxs) {
                            Text("Hai già un account?")
                                .font(BrindooFont.bodyMedium)
                                .foregroundStyle(Color.brindooTextSecondary)

                            Button {
                                navigateToLogin = true
                            } label: {
                                Text("Accedi")
                                    .font(BrindooFont.bodyMedium.weight(.semibold))
                                    .foregroundStyle(Color.brindooCoral)
                            }
                            .disabled(!isLastSlide || !acceptedTermsAndAge)
                            .opacity(acceptedTermsAndAge ? 1 : 0.4)
                        }
                        .opacity(isLastSlide ? 1 : 0)
                        .animation(.easeInOut(duration: 0.2), value: isLastSlide)
                    }
                    .padding(.horizontal, BrindooSpacing.lg)
                    .padding(.bottom, BrindooSpacing.xl)
                }
                
            }
            .navigationDestination(isPresented: $navigateToLogin) {
                LoginView()
            }
            .navigationDestination(isPresented: $navigateToSignUp) {
                SignUpView()
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
            .onAppear {
                // Ripristina lo stato della checkbox dall'AppStorage
                acceptedTermsAndAge = !acceptedTermsAt.isEmpty
            }
            .onChange(of: acceptedTermsAndAge) { _, newValue in
                acceptedTermsAt = newValue
                    ? ISO8601DateFormatter().string(from: Date())
                    : ""
            }
        }
    }

    // MARK: - Checkbox accettazione

    @ViewBuilder
    private var consentCheckbox: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                acceptedTermsAndAge.toggle()
            }
        } label: {
            HStack(alignment: .top, spacing: BrindooSpacing.sm) {
                Image(systemName: acceptedTermsAndAge ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundStyle(
                        acceptedTermsAndAge ? Color.brindooCoral : Color.brindooBorder
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Confermo di avere almeno 18 anni e di accettare i Termini e la Privacy Policy.")
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
            .background(Color.brindooSurface.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Slide
    
    @ViewBuilder
    private func slideView(_ slide: OnboardingSlide) -> some View {
        VStack(spacing: BrindooSpacing.xl) {
            Spacer()

            // Icona grande con cerchio corallo sfumato
            ZStack {
                Circle()
                    .fill(Color.brindooCoral.opacity(0.10))
                    .frame(width: 200, height: 200)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.brindooCoral, Color.brindooCoralDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 150, height: 150)
                    .shadow(color: Color.brindooCoral.opacity(0.35), radius: 18, x: 0, y: 10)

                Image(systemName: slide.icon)
                    .font(.system(size: 70, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: BrindooSpacing.md) {
                Text(slide.title)
                    .font(BrindooFont.displayLarge)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.brindooTextPrimary)

                Text(slide.description)
                    .font(BrindooFont.bodyLarge)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.brindooTextSecondary)
                    .padding(.horizontal, BrindooSpacing.xl)
            }

            // Hint swipe solo sulla prima slide
            if currentSlide == 0 && slide.icon == slides[0].icon {
                swipeHint
            }

            Spacer()
        }
    }

    @State private var swipeHintOffset: CGFloat = 0

    @ViewBuilder
    private var swipeHint: some View {
        HStack(spacing: BrindooSpacing.xxs) {
            Text("Scorri")
                .font(BrindooFont.bodySmall.weight(.medium))
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .opacity(0.5)
        }
        .foregroundStyle(Color.brindooCoral)
        .offset(x: swipeHintOffset)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                swipeHintOffset = 12
            }
        }
        .onDisappear { swipeHintOffset = 0 }
    }
    
}

// MARK: - Modello Slide

private struct OnboardingSlide {
    let icon: String
    let title: String
    let description: String
}

#Preview {
    OnboardingView()
}
