//
//  WriteReviewView.swift
//  Brindoo
//
//  Sheet per scrivere una nuova recensione o modificare la propria esistente.
//

import SwiftUI
import StoreKit
import PhotosUI

struct WriteReviewView: View {
    
    let organizer: Profile
    /// Recensione esistente (se l'utente l'ha già scritta) → modalità modifica
    let existingReview: Review?
    /// Callback quando salva con successo
    let onSuccess: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview

    @State private var rating: Int = 0
    @State private var comment: String = ""

    // Foto dell'evento (opzionale)
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var photoImage: UIImage?
    @State private var existingPhotoUrl: String?

    @State private var isLoading: Bool = false
    @State private var generalError: String?
    @State private var showDeleteConfirm: Bool = false
    
    private var isEditMode: Bool {
        existingReview != nil
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BrindooSpacing.xl) {
                    
                    // Organizzatore recensito
                    VStack(spacing: BrindooSpacing.sm) {
                        AvatarView(
                            url: organizer.avatarUrl,
                            name: organizer.fullName,
                            size: 80
                        )
                        
                        VStack(spacing: BrindooSpacing.xxs) {
                            Text(organizer.fullName ?? "Organizzatore")
                                .font(BrindooFont.titleMedium)
                            
                            if let city = organizer.city {
                                Text(city)
                                    .font(BrindooFont.bodySmall)
                                    .foregroundStyle(Color.brindooTextSecondary)
                            }
                        }
                    }
                    .padding(.top, BrindooSpacing.lg)
                    
                    // Stelle
                    VStack(spacing: BrindooSpacing.sm) {
                        Text("Quanti stelle daresti?")
                            .font(BrindooFont.titleSmall)
                            .foregroundStyle(Color.brindooTextSecondary)
                        
                        StarRatingView(
                            rating: Double(rating),
                            mode: .input,
                            size: 40,
                            spacing: 8
                        ) { newValue in
                            withAnimation(.easeInOut(duration: 0.15)) {
                                rating = newValue
                            }
                        }
                        
                        if rating > 0 {
                            Text(ratingDescription)
                                .font(BrindooFont.bodySmall.weight(.medium))
                                .foregroundStyle(Color.brindooCoral)
                                .transition(.opacity)
                        } else {
                            Text("Tocca le stelle per votare")
                                .font(BrindooFont.bodySmall)
                                .foregroundStyle(Color.brindooTextSecondary)
                        }
                    }
                    .padding(BrindooSpacing.lg)
                    .frame(maxWidth: .infinity)
                    .background(Color.brindooSurface)
                    .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
                    
                    // Commento
                    VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
                        Text("Lascia un commento (opzionale)")
                            .font(BrindooFont.bodySmall.weight(.medium))
                            .foregroundStyle(Color.brindooTextSecondary)
                        
                        TextField(
                            "Racconta la tua esperienza per aiutare altri clienti",
                            text: $comment,
                            axis: .vertical
                        )
                        .lineLimit(4...10)
                        .font(BrindooFont.bodyLarge)
                        .padding(BrindooSpacing.md)
                        .background(Color.brindooSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: BrindooRadius.md)
                                .strokeBorder(Color.brindooBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
                        .disabled(isLoading)
                        
                        HStack {
                            Spacer()
                            Text("\(comment.count)/1000")
                                .font(BrindooFont.caption)
                                .foregroundStyle(comment.count > 1000 ? Color.brindooError : Color.brindooTextSecondary)
                        }
                    }

                    photoSection

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
                    
                    // Elimina (solo in edit mode)
                    if isEditMode {
                        BrindooButton(
                            "Elimina recensione",
                            style: .destructive,
                            size: .medium,
                            icon: "trash"
                        ) {
                            showDeleteConfirm = true
                        }
                        .padding(.top, BrindooSpacing.md)
                    }
                }
                .padding(.horizontal, BrindooSpacing.lg)
                .padding(.bottom, BrindooSpacing.lg)
            }
            .background(Color.brindooBackground)
            .navigationTitle(isEditMode ? "Modifica recensione" : "Scrivi recensione")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annulla") { dismiss() }
                        .disabled(isLoading)
                }
            }
            .safeAreaInset(edge: .bottom) {
                BrindooButton(
                    isEditMode ? "Salva modifiche" : "Pubblica recensione",
                    style: .primary,
                    size: .large,
                    isLoading: isLoading,
                    isDisabled: rating == 0
                ) {
                    Task { await submit() }
                }
                .padding(.horizontal, BrindooSpacing.lg)
                .padding(.vertical, BrindooSpacing.sm)
                .background(
                    Color.brindooBackground
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: -2)
                )
            }
            .onAppear {
                // Pre-popola se edit mode
                if let existing = existingReview {
                    rating = existing.rating
                    comment = existing.comment ?? ""
                    existingPhotoUrl = existing.photoUrl
                }
            }
            .onChange(of: photoPickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        photoImage = img
                    }
                }
            }
            .alert("Eliminare recensione?", isPresented: $showDeleteConfirm) {
                Button("Annulla", role: .cancel) {}
                Button("Elimina", role: .destructive) {
                    Task { await deleteReview() }
                }
            } message: {
                Text("Questa azione non può essere annullata.")
            }
        }
    }
    
    // MARK: - Foto dell'evento

    @ViewBuilder
    private var photoSection: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
            Text("Foto dell'evento (opzionale)")
                .font(BrindooFont.bodySmall.weight(.medium))
                .foregroundStyle(Color.brindooTextSecondary)

            PhotosPicker(selection: $photoPickerItem, matching: .images) {
                ZStack {
                    if let photoImage {
                        Image(uiImage: photoImage)
                            .resizable()
                            .scaledToFill()
                    } else if let existingPhotoUrl, let url = URL(string: existingPhotoUrl) {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            BrindooSkeleton(cornerRadius: BrindooRadius.md)
                        }
                    } else {
                        VStack(spacing: BrindooSpacing.xs) {
                            Image(systemName: "camera.badge.clock")
                                .font(.system(size: 26))
                                .foregroundStyle(Color.brindooCoral)
                            Text("Una foto dell'evento rende la recensione più credibile")
                                .font(BrindooFont.caption)
                                .foregroundStyle(Color.brindooTextSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(BrindooSpacing.md)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .background(Color.brindooSurface)
                .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: BrindooRadius.md)
                        .strokeBorder(Color.brindooBorder, lineWidth: 1)
                )
            }
            .disabled(isLoading)

            if photoImage != nil || existingPhotoUrl != nil {
                Button {
                    photoImage = nil
                    photoPickerItem = nil
                    existingPhotoUrl = nil
                } label: {
                    Label("Rimuovi foto", systemImage: "trash")
                        .font(BrindooFont.caption.weight(.medium))
                        .foregroundStyle(Color.brindooError)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var ratingDescription: String {
        switch rating {
        case 1: return "Pessima"
        case 2: return "Scarsa"
        case 3: return "Buona"
        case 4: return "Ottima"
        case 5: return "Eccellente"
        default: return ""
        }
    }
    
    // MARK: - Logica
    
    private func submit() async {
        generalError = nil
        
        guard rating > 0 else {
            generalError = "Seleziona un voto"
            return
        }
        
        guard comment.count <= 1000 else {
            generalError = "Il commento è troppo lungo"
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Foto: carica quella nuova, oppure conserva l'esistente (nil = nessuna).
            var photoUrl: String? = existingPhotoUrl
            if let photoImage {
                photoUrl = try await StorageService.shared.uploadReviewImage(photoImage)
            }

            if let existing = existingReview {
                _ = try await ReviewService.shared.updateReview(
                    reviewId: existing.id,
                    rating: rating,
                    comment: comment,
                    photoUrl: photoUrl
                )
            } else {
                _ = try await ReviewService.shared.createReview(
                    organizerId: organizer.id,
                    rating: rating,
                    comment: comment,
                    photoUrl: photoUrl
                )
                // Dopo una recensione positiva, proponi la valutazione dell'app.
                if rating >= 4 { requestReview() }
            }
            onSuccess()
            dismiss()
        } catch {
            let msg = error.localizedDescription.lowercased()
            if msg.contains("duplicate") || msg.contains("unique") {
                generalError = "Hai già recensito questo organizzatore"
            } else {
                generalError = "Impossibile salvare la recensione. Riprova."
            }
            BrindooLog.error("\(error)")
        }
    }
    
    private func deleteReview() async {
        guard let existing = existingReview else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await ReviewService.shared.deleteReview(reviewId: existing.id)
            onSuccess()
            dismiss()
        } catch {
            generalError = "Impossibile eliminare la recensione"
            BrindooLog.error("\(error)")
        }
    }
}
