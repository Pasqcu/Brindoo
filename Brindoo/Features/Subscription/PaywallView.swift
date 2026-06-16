//
//  PaywallView.swift
//  Brindoo
//
//  Schermata di sottoscrizione Pro.
//  Mostra benefici, prezzo, bottone "Iscriviti", restore.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    
    @State private var purchaseService = PurchaseService.shared
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showSuccessToast: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BrindooSpacing.xl) {
                    
                    // Header brand
                    VStack(spacing: BrindooSpacing.md) {
                        ZStack {
                            Circle()
                                .fill(BrindooGradient.pro)
                                .frame(width: 80, height: 80)
                                .shadow(color: Color(red: 0.93, green: 0.50, blue: 0.20).opacity(0.4), radius: 10, x: 0, y: 4)

                            Image(systemName: "crown.fill")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        
                        Text("Brindoo Pro")
                            .font(BrindooFont.displayLarge)
                        
                        Text("Sblocca il massimo da Brindoo")
                            .font(BrindooFont.bodyLarge)
                            .foregroundStyle(Color.brindooTextSecondary)
                    }
                    .padding(.top, BrindooSpacing.xl)
                    
                    // Lista benefici
                    VStack(alignment: .leading, spacing: BrindooSpacing.md) {
                        benefitRow(
                            icon: "checkmark.seal.fill",
                            title: "Badge Pro",
                            description: "Sigillo di trust accanto al tuo nome ovunque"
                        )

                        benefitRow(
                            icon: "infinity",
                            title: "Offerte illimitate",
                            description: "Pubblica tutti i pacchetti che vuoi (free: max 1)"
                        )

                        benefitRow(
                            icon: "star.bubble.fill",
                            title: "Priorità in bacheca",
                            description: "Il tuo profilo e le tue offerte appaiono prima dei non-Pro"
                        )

                        benefitRow(
                            icon: "beach.umbrella.fill",
                            title: "Modalità vacanza",
                            description: "Metti in pausa le offerte mantenendo il profilo"
                        )

                        benefitRow(
                            icon: "chart.bar.fill",
                            title: "Statistiche dettagliate",
                            description: "Visite profilo, offerte, proposte e tempo medio risposta"
                        )

                        benefitRow(
                            icon: "photo.on.rectangle.angled",
                            title: "Portfolio fino a 50 foto",
                            description: "Free: 5 foto. Pro: 50 foto."
                        )
                    }
                    .padding(BrindooSpacing.lg)
                    .background(Color.brindooSurface)
                    .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.lg))
                    
                    // Status corrente
                    if isCurrentlyPro {
                        currentStatusCard
                    }
                    
                    // Prodotto / bottone
                    if let product = purchaseService.product(for: BrindooProduct.proMonthly) {
                        productCard(product)
                    } else if purchaseService.isLoading {
                        ProgressView()
                            .tint(.brindooCoral)
                            .padding(.vertical, BrindooSpacing.lg)
                    } else {
                        Text("Caricamento prodotti non riuscito")
                            .font(BrindooFont.bodyMedium)
                            .foregroundStyle(Color.brindooTextSecondary)
                    }
                    
                    // Footer info legali
                    footerSection
                    
                    if let errorMessage {
                        Text(errorMessage)
                            .font(BrindooFont.bodySmall)
                            .foregroundStyle(Color.brindooError)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.brindooError.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
                    }
                }
                .padding(.horizontal, BrindooSpacing.lg)
                .padding(.bottom, BrindooSpacing.xl)
            }
            .background(Color.brindooBackground)
            .navigationTitle("Brindoo Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.brindooTextPrimary)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await restore() }
                    } label: {
                        Text("Ripristina")
                            .font(BrindooFont.bodySmall.weight(.medium))
                            .foregroundStyle(Color.brindooCoral)
                    }
                    .disabled(isLoading)
                }
            }
            .task {
                await purchaseService.loadProducts()
            }
            .overlay {
                if showSuccessToast {
                    successToast
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }
    
    // MARK: - Benefit row
    
    @ViewBuilder
    private func benefitRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: BrindooSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.brindooCoral.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.brindooCoral)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BrindooFont.titleSmall)
                Text(description)
                    .font(BrindooFont.bodySmall)
                    .foregroundStyle(Color.brindooTextSecondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Stato attuale Pro
    
    @ViewBuilder
    private var currentStatusCard: some View {
        HStack(spacing: BrindooSpacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(Color.brindooSuccess)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Sei già Pro!")
                    .font(BrindooFont.titleSmall)
                Text("La sottoscrizione si rinnova automaticamente")
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooTextSecondary)
            }
            
            Spacer()
        }
        .padding(BrindooSpacing.md)
        .frame(maxWidth: .infinity)
        .background(Color.brindooSuccess.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
    }
    
    // MARK: - Card prodotto
    
    @ViewBuilder
    private func productCard(_ product: Product) -> some View {
        VStack(spacing: BrindooSpacing.md) {
            VStack(spacing: BrindooSpacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(product.displayPrice)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    Text("/mese")
                        .font(BrindooFont.bodyLarge)
                        .foregroundStyle(Color.brindooTextSecondary)
                }
                
                Text("Cancellabile in qualsiasi momento")
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooTextSecondary)
            }
            
            BrindooButton(
                isCurrentlyPro ? "Già attivo" : "Iscriviti a Pro",
                style: .primary,
                size: .large,
                isLoading: isLoading,
                isDisabled: isCurrentlyPro
            ) {
                Task { await purchase(product) }
            }
        }
        .padding(BrindooSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color.brindooCoral.opacity(0.1),
                    Color.brindooCoral.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: BrindooRadius.lg)
                .strokeBorder(Color.brindooCoral.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.lg))
    }
    
    // MARK: - Footer
    
    @ViewBuilder
    private var footerSection: some View {
        VStack(spacing: BrindooSpacing.xs) {
            Text("Il pagamento sarà addebitato sul tuo account Apple alla conferma. La sottoscrizione si rinnova automaticamente a meno che non venga annullata almeno 24 ore prima della scadenza.")
                .font(BrindooFont.caption)
                .foregroundStyle(Color.brindooTextSecondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: BrindooSpacing.md) {
                NavigationLink("Termini") {
                    TermsOfServiceView()
                }
                Text("•")
                NavigationLink("Privacy") {
                    PrivacyPolicyView()
                }
            }
            .font(BrindooFont.caption.weight(.medium))
            .foregroundStyle(Color.brindooCoral)
        }
        .padding(.top, BrindooSpacing.md)
    }
    
    // MARK: - Toast
    
    @ViewBuilder
    private var successToast: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: BrindooSpacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.brindooSuccess)
                Text("Benvenuto Pro!")
                    .font(BrindooFont.titleMedium)
                Text("Ora hai tutte le funzionalità avanzate")
                    .font(BrindooFont.bodySmall)
                    .foregroundStyle(Color.brindooTextSecondary)
            }
            .padding(BrindooSpacing.xl)
            .background(Color.brindooBackground)
            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.lg))
            .shadow(color: .black.opacity(0.2), radius: 16)
        }
    }
    
    // MARK: - Helpers
    
    private var isCurrentlyPro: Bool {
        session.currentProfile?.isPro == true
    }
    
    // MARK: - Actions
    
    private func purchase(_ product: Product) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        let result = await purchaseService.purchase(product)
        
        switch result {
        case .success:
            // Aggiorna il profilo locale (entitlement appena scritto su DB)
            try? await Task.sleep(nanoseconds: 500_000_000)
            if let userId = session.userID,
               let profile = try? await ProfileService.shared.fetchProfile(userID: userId) {
                session.updateLocalProfile(profile)
            }
            
            withAnimation { showSuccessToast = true }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation { showSuccessToast = false }
            try? await Task.sleep(nanoseconds: 300_000_000)
            dismiss()
            
        case .userCancelled:
            // Niente
            break
            
        case .pending:
            errorMessage = "Acquisto in attesa di approvazione (es. parental controls)"
            
        case .failed(let error):
            errorMessage = "Acquisto fallito: \(error.localizedDescription)"
        }
    }
    
    private func restore() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        await purchaseService.restorePurchases()
        
        // Ricarica profilo
        if let userId = session.userID,
           let profile = try? await ProfileService.shared.fetchProfile(userID: userId) {
            session.updateLocalProfile(profile)
        }
    }
}
