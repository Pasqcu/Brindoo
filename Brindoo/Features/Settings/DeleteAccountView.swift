//
//  DeleteAccountView.swift
//  Brindoo
//
//  Schermata di conferma cancellazione account.
//  Richiesta da Apple per la pubblicazione su App Store: gli utenti devono
//  poter eliminare i propri dati direttamente dall'app.
//

import SwiftUI

struct DeleteAccountView: View {
    
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    
    @State private var confirmText: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showFinalConfirm: Bool = false
    
    private let confirmationKeyword = "ELIMINA"
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrindooSpacing.lg) {
                
                // Icona warning
                ZStack {
                    Circle()
                        .fill(Color.brindooError.opacity(0.1))
                        .frame(width: 100, height: 100)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.brindooError)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, BrindooSpacing.lg)
                
                Text("Elimina il tuo account")
                    .font(BrindooFont.displayMedium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("Questa azione è **definitiva e non reversibile**. Tutti i tuoi dati saranno cancellati.")
                    .font(BrindooFont.bodyLarge)
                    .foregroundStyle(Color.brindooTextPrimary)
                
                // Cosa verrà cancellato
                VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
                    Text("Verranno eliminati:")
                        .font(BrindooFont.titleSmall)
                        .padding(.top, BrindooSpacing.sm)
                    
                    deletionItem(icon: "person.crop.circle.fill", text: "Il tuo profilo (nome, foto, bio)")
                    deletionItem(icon: "bubble.left.and.bubble.right.fill", text: "Tutte le conversazioni e i messaggi")
                    
                    if isOrganizer {
                        deletionItem(icon: "photo.on.rectangle.angled", text: "Tutte le foto del tuo portfolio")
                        deletionItem(icon: "tag.fill", text: "Le tue offerte e trattative")
                    } else {
                        deletionItem(icon: "arrow.left.arrow.right", text: "Le tue trattative e offerte salvate")
                    }
                    
                    deletionItem(icon: "star.fill", text: "Tutte le recensioni che hai scritto")
                    deletionItem(icon: "envelope", text: "L'accesso a questa email")
                }
                .padding(BrindooSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.brindooSurface)
                .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
                
                // Conferma testuale
                VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
                    Text("Per confermare scrivi **\(confirmationKeyword)** qui sotto:")
                        .font(BrindooFont.bodyMedium)
                        .padding(.top, BrindooSpacing.md)
                    
                    TextField(confirmationKeyword, text: $confirmText)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(BrindooFont.bodyLarge.weight(.semibold))
                        .padding(BrindooSpacing.md)
                        .background(Color.brindooSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: BrindooRadius.md)
                                .strokeBorder(
                                    isConfirmed ? Color.brindooError : Color.brindooBorder,
                                    lineWidth: isConfirmed ? 2 : 1
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
                        .disabled(isLoading)
                }
                
                if let errorMessage {
                    HStack(spacing: BrindooSpacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(errorMessage)
                            .font(BrindooFont.bodySmall)
                    }
                    .foregroundStyle(Color.brindooError)
                    .padding(BrindooSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.brindooError.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
                }
            }
            .padding(BrindooSpacing.lg)
            .padding(.bottom, BrindooSpacing.xl)
        }
        .background(Color.brindooBackground)
        .navigationTitle("Eliminazione account")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: BrindooSpacing.sm) {
                BrindooButton(
                    "Elimina definitivamente",
                    style: .destructive,
                    size: .large,
                    icon: "trash.fill",
                    isLoading: isLoading,
                    isDisabled: !isConfirmed
                ) {
                    showFinalConfirm = true
                }
                
                Button("Annulla") {
                    dismiss()
                }
                .font(BrindooFont.bodyMedium.weight(.medium))
                .foregroundStyle(Color.brindooTextSecondary)
                .disabled(isLoading)
            }
            .padding(.horizontal, BrindooSpacing.lg)
            .padding(.vertical, BrindooSpacing.sm)
            .background(
                Color.brindooBackground
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: -2)
            )
        }
        .alert("Sei davvero sicuro?", isPresented: $showFinalConfirm) {
            Button("Annulla", role: .cancel) {}
            Button("Sì, elimina tutto", role: .destructive) {
                Task { await performDeletion() }
            }
        } message: {
            Text("Quest'azione non può essere annullata. Una volta eliminato l'account dovrai registrarti di nuovo per usare Brindoo.")
        }
    }
    
    @ViewBuilder
    private func deletionItem(icon: String, text: String) -> some View {
        HStack(spacing: BrindooSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.brindooError)
                .frame(width: 20)
            Text(text)
                .font(BrindooFont.bodyMedium)
                .foregroundStyle(Color.brindooTextPrimary)
        }
    }
    
    private var isOrganizer: Bool {
        session.currentProfile?.role == .organizer
    }
    
    private var isConfirmed: Bool {
        confirmText.trimmingCharacters(in: .whitespaces).uppercased() == confirmationKeyword
    }
    
    private func performDeletion() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await AccountService.shared.deleteMyAccount()
            // Il SessionStore rileverà il signOut e tornerà a OnboardingView automaticamente
        } catch {
            errorMessage = "Impossibile eliminare l'account. Riprova più tardi o contatta il supporto."
            print("❌ \(error)")
        }
    }
}
