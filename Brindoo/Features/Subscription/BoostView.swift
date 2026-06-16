//
//  BoostView.swift
//  Brindoo
//
//  Schermata di acquisto Boost (consumable).
//  Per gli organizzatori: spinge il proprio profilo in cima alle ricerche.
//

import SwiftUI
import StoreKit

struct BoostView: View {
    
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    
    @State private var purchaseService = PurchaseService.shared
    @State private var selectedProductId: String = BrindooProduct.boostWeek
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showSuccessToast: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BrindooSpacing.xl) {
                    
                    // Header
                    VStack(spacing: BrindooSpacing.md) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.orange, Color.brindooCoral],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        
                        Text("Boost")
                            .font(BrindooFont.displayLarge)
                        
                        Text("Spingi il tuo profilo in cima alle ricerche")
                            .font(BrindooFont.bodyLarge)
                            .foregroundStyle(Color.brindooTextSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, BrindooSpacing.xl)
                    
                    // Come funziona
                    VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
                        howItWorksRow(
                            icon: "1.circle.fill",
                            text: "Acquisti il Boost con un singolo pagamento"
                        )
                        howItWorksRow(
                            icon: "2.circle.fill",
                            text: "Il tuo profilo appare in cima ai risultati per la durata scelta"
                        )
                        howItWorksRow(
                            icon: "3.circle.fill",
                            text: "Più visibilità = più clienti che ti contattano"
                        )
                    }
                    .padding(BrindooSpacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.brindooSurface)
                    .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.lg))
                    
                    // Stato boost attivo
                    if isCurrentlyBoosted {
                        currentBoostCard
                    }
                    
                    // Selezione durata
                    VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
                        Text("Scegli la durata")
                            .font(BrindooFont.titleMedium)
                        
                        if purchaseService.products.isEmpty {
                            ProgressView()
                                .tint(.brindooCoral)
                                .padding(.vertical, BrindooSpacing.lg)
                                .frame(maxWidth: .infinity)
                        } else {
                            VStack(spacing: BrindooSpacing.sm) {
                                if let dayProduct = purchaseService.product(for: BrindooProduct.boostDay) {
                                    boostOption(
                                        product: dayProduct,
                                        title: "1 Giorno",
                                        subtitle: "24 ore di visibilità top",
                                        icon: "clock.fill"
                                    )
                                }
                                
                                if let weekProduct = purchaseService.product(for: BrindooProduct.boostWeek) {
                                    boostOption(
                                        product: weekProduct,
                                        title: "1 Settimana",
                                        subtitle: "7 giorni — più conveniente",
                                        icon: "calendar",
                                        isRecommended: true
                                    )
                                }
                            }
                        }
                    }
                    
                    if let errorMessage {
                        Text(errorMessage)
                            .font(BrindooFont.bodySmall)
                            .foregroundStyle(Color.brindooError)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.brindooError.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
                    }
                    
                    // Footer info
                    Text("Pagamento singolo, nessun rinnovo automatico. Il Boost si attiva immediatamente dopo l'acquisto.")
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, BrindooSpacing.md)
                }
                .padding(.horizontal, BrindooSpacing.lg)
                .padding(.bottom, BrindooSpacing.xl)
            }
            .background(Color.brindooBackground)
            .navigationTitle("Boost")
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
    
    // MARK: - Components
    
    @ViewBuilder
    private func howItWorksRow(icon: String, text: String) -> some View {
        HStack(spacing: BrindooSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(Color.brindooCoral)
            Text(text)
                .font(BrindooFont.bodyMedium)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    @ViewBuilder
    private func boostOption(
        product: Product,
        title: String,
        subtitle: String,
        icon: String,
        isRecommended: Bool = false
    ) -> some View {
        let isSelected = selectedProductId == product.id
        
        Button {
            selectedProductId = product.id
            Task { await purchase(product) }
        } label: {
            HStack(spacing: BrindooSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [.orange, Color.brindooCoral],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: BrindooSpacing.xs) {
                        Text(title)
                            .font(BrindooFont.titleMedium)
                        
                        if isRecommended {
                            Text("CONSIGLIATO")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.brindooSuccess)
                                .clipShape(Capsule())
                        }
                    }
                    Text(subtitle)
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextSecondary)
                }
                
                Spacer()
                
                Text(product.displayPrice)
                    .font(BrindooFont.titleMedium)
                    .foregroundStyle(Color.brindooCoral)
            }
            .padding(BrindooSpacing.md)
            .frame(maxWidth: .infinity)
            .background(Color.brindooBackground)
            .overlay(
                RoundedRectangle(cornerRadius: BrindooRadius.lg)
                    .strokeBorder(
                        isRecommended ? Color.brindooCoral : Color.brindooBorder,
                        lineWidth: isRecommended ? 2 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.lg))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .opacity((isLoading && isSelected) ? 0.6 : 1.0)
        .overlay {
            if isLoading && isSelected {
                ProgressView().tint(.brindooCoral)
            }
        }
    }
    
    @ViewBuilder
    private var currentBoostCard: some View {
        HStack(spacing: BrindooSpacing.md) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 24))
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Boost attivo")
                    .font(BrindooFont.titleSmall)
                Text("Il tuo profilo è in cima ai risultati")
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooTextSecondary)
            }
            
            Spacer()
        }
        .padding(BrindooSpacing.md)
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
    }
    
    @ViewBuilder
    private var successToast: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: BrindooSpacing.sm) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)
                Text("Boost attivato!")
                    .font(BrindooFont.titleMedium)
                Text("Il tuo profilo è ora in cima")
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
    
    private var isCurrentlyBoosted: Bool {
        // Per ora basato sul profilo. Se aggiungiamo il campo boost_expires_at al modello
        // Profile, possiamo controllare la scadenza.
        // Versione semplice: false
        return false
    }
    
    // MARK: - Actions
    
    private func purchase(_ product: Product) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        let result = await purchaseService.purchase(product)
        
        switch result {
        case .success:
            withAnimation { showSuccessToast = true }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation { showSuccessToast = false }
            try? await Task.sleep(nanoseconds: 300_000_000)
            dismiss()
            
        case .userCancelled:
            break
            
        case .pending:
            errorMessage = "Acquisto in attesa di approvazione"
            
        case .failed(let error):
            errorMessage = "Acquisto fallito: \(error.localizedDescription)"
        }
    }
}
