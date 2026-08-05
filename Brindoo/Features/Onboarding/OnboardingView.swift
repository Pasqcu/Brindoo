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
    @State private var legalDocument: LegalDocument?

    private var isLastSlide: Bool {
        currentSlide >= slides.count - 1
    }

    // L'introduzione racconta entrambi i percorsi senza chiedere nulla:
    // la scelta cliente/professionista si fa una volta sola, nella
    // creazione del profilo, subito dopo la registrazione.
    private let slides: [OnboardingSlide] = [
        OnboardingSlide(
            icon: "party.popper.fill",
            title: "Benvenuto in Brindoo",
            description: "Feste ed eventi nel Lazio: qui chi organizza e chi lavora si incontrano."
        ),
        OnboardingSlide(
            icon: "magnifyingglass.circle.fill",
            title: "Trova e tratta il prezzo",
            description: "Cerca per categoria e zona, confronta le offerte e fai la tua proposta: il prezzo si concorda in chat."
        ),
        OnboardingSlide(
            icon: "sparkles",
            title: "Oppure fatti trovare",
            description: "Sei un professionista? Pubblica le tue offerte, indica le zone che copri e ricevi richieste dai clienti."
        )
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.brindooBackground.ignoresSafeArea()
                
                VStack {
                    // "Salta" resta sempre montato: farlo sparire dalla
                    // gerarchia sull'ultima slide faceva scattare il layout
                    // proprio mentre lo swipe stava finendo.
                    HStack {
                        Spacer()
                        Button("Salta") {
                            withAnimation(BrindooAnimation.standardEase) {
                                currentSlide = slides.count - 1
                            }
                        }
                        .font(BrindooFont.bodyMedium.weight(.medium))
                        .foregroundStyle(Color.brindooTextSecondary)
                        .padding()
                        .opacity(isLastSlide ? 0 : 1)
                        .allowsHitTesting(!isLastSlide)
                        .animation(BrindooAnimation.standardEase, value: isLastSlide)
                    }

                    // TabView con le slide (occupa lo spazio verticale disponibile;
                    // il contenuto interno di ogni slide è centrato/scorrevole).
                    TabView(selection: $currentSlide) {
                        ForEach(slides.indices, id: \.self) { index in
                            OnboardingSlideView(
                                slide: slides[index],
                                showsSwipeHint: index == 0
                            )
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    
                    // Pagination dots — cliccabili per saltare a una slide
                    HStack(spacing: BrindooSpacing.xs) {
                        ForEach(slides.indices, id: \.self) { index in
                            Button {
                                withAnimation(BrindooAnimation.standardEase) {
                                    currentSlide = index
                                }
                            } label: {
                                Capsule()
                                    .fill(currentSlide == index ? Color.brindooCoral : Color.brindooBorder)
                                    .frame(width: currentSlide == index ? 24 : 8, height: 8)
                                    .animation(BrindooAnimation.quickEase, value: currentSlide)
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
                            .allowsHitTesting(isLastSlide)
                            .animation(BrindooAnimation.standardEase, value: isLastSlide)

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
                        .allowsHitTesting(isLastSlide)
                        .animation(BrindooAnimation.standardEase, value: isLastSlide)
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
            .sheet(item: $legalDocument) { LegalDocumentSheet(document: $0) }
            .onAppear {
                // Ripristina lo stato della checkbox dall'AppStorage
                acceptedTermsAndAge = !acceptedTermsAt.isEmpty
            }
            .onChange(of: acceptedTermsAndAge) { _, newValue in
                acceptedTermsAt = newValue
                    ? BrindooFormat.isoNow
                    : ""
            }
        }
    }

    // MARK: - Checkbox accettazione

    @ViewBuilder
    private var consentCheckbox: some View {
        // I link ai documenti stanno fuori dal pulsante della spunta: dentro il suo
        // label il tocco verrebbe intercettato e non si aprirebbero mai.
        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
            Button {
                withAnimation(BrindooAnimation.quickEase) {
                    acceptedTermsAndAge.toggle()
                }
            } label: {
                HStack(alignment: .top, spacing: BrindooSpacing.sm) {
                    Image(systemName: acceptedTermsAndAge ? "checkmark.square.fill" : "square")
                        .font(.system(size: 20))
                        .foregroundStyle(
                            acceptedTermsAndAge ? Color.brindooCoral : Color.brindooBorder
                        )

                    Text("Confermo di avere almeno 18 anni e di accettare i Termini e la Privacy Policy.")
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(acceptedTermsAndAge ? [.isSelected] : [])

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
        .background(Color.brindooSurface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
    }

}

// MARK: - Slide

// Vista a sé: così ogni pagina dipende solo dai suoi dati e cambiare
// slide non costringe SwiftUI a ricostruire anche le altre due.
private struct OnboardingSlideView: View {

    let slide: OnboardingSlide
    let showsSwipeHint: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var swipeHintOffset: CGFloat = 0

    var body: some View {
        // A dimensioni di testo Accessibilità il contenuto può eccedere
        // l'altezza: solo in quel caso serve la ScrollView. Alle taglie
        // normali resta un semplice VStack centrato, senza GeometryReader
        // che rimisuri a ogni frame dello swipe.
        if dynamicTypeSize.isAccessibilitySize {
            GeometryReader { geo in
                ScrollView(.vertical, showsIndicators: false) {
                    content
                        .frame(maxWidth: .infinity, minHeight: geo.size.height)
                }
            }
        } else {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var content: some View {
        VStack(spacing: BrindooSpacing.xl) {
            Spacer(minLength: 0)

            icon

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

            // Hint swipe solo sulla prima slide. Resta sempre montato
            // (opacità a zero altrove) per non alterare l'altezza.
            swipeHint
                .opacity(showsSwipeHint ? 1 : 0)

            Spacer(minLength: 0)
        }
    }

    /// Icona grande con cerchio corallo sfumato. A dimensioni di testo
    /// Accessibilità la rimpiccioliamo per lasciare spazio a titolo e
    /// descrizione (che invece crescono col Dynamic Type).
    private var icon: some View {
        let iconScale: CGFloat = dynamicTypeSize.isAccessibilitySize ? 0.6 : 1.0
        return ZStack {
            Circle()
                .fill(Color.brindooCoral.opacity(0.10))
                .frame(width: 200 * iconScale, height: 200 * iconScale)

            Circle()
                .fill(BrindooGradient.coral)
                .frame(width: 150 * iconScale, height: 150 * iconScale)
                .shadow(color: Color.brindooCoral.opacity(0.35), radius: 18, x: 0, y: 10)

            Image(systemName: slide.icon)
                .font(.system(size: 70 * iconScale, weight: .semibold))
                .foregroundStyle(.white)
        }
        // L'ombra sfumata verrebbe ricalcolata a ogni frame dello swipe:
        // rasterizzata una volta, la transizione resta fluida.
        .drawingGroup()
    }

    private var swipeHint: some View {
        HStack(spacing: BrindooSpacing.xxs) {
            Text("Scorri")
                .font(BrindooFont.bodySmall.weight(.medium))
            Image(systemName: BrindooIcon.forward)
                .font(.system(size: 14, weight: .semibold))
            Image(systemName: BrindooIcon.forward)
                .font(.system(size: 14, weight: .semibold))
                .opacity(0.5)
        }
        .foregroundStyle(Color.brindooCoral)
        .offset(x: swipeHintOffset)
        .onAppear {
            guard showsSwipeHint, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                swipeHintOffset = 12
            }
        }
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
