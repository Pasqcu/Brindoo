//
//  SuggestCategorySheet.swift
//  Brindoo
//
//  Sheet per proporre una nuova categoria di servizio.
//  Le proposte vengono salvate in `category_suggestions` e revisionate manualmente.
//

import SwiftUI

struct SuggestCategorySheet: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var toasts: BrindooToastCenter

    @State private var name: String = ""
    @State private var description: String = ""

    @State private var nameError: String?
    @State private var generalError: String?
    @State private var isLoading: Bool = false
    @State private var success: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BrindooSpacing.lg) {

                    if success {
                        successView
                    } else {
                        formView
                    }
                }
                .padding(BrindooSpacing.lg)
            }
            .background(Color.brindooBackground)
            .navigationTitle("Proponi categoria")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chiudi") { dismiss() }
                        .disabled(isLoading)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    // MARK: - Form

    @ViewBuilder
    private var formView: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.md) {

            HStack(alignment: .top, spacing: BrindooSpacing.sm) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.brindooWarning)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Non trovi la tua categoria?")
                        .font(BrindooFont.bodyMedium.weight(.semibold))
                    Text("Proponici di aggiungerne una nuova. La valuteremo e — se in linea con Brindoo — la aggiungeremo al catalogo.")
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(BrindooSpacing.md)
            .background(Color.brindooWarning.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))

            BrindooTextField(
                title: "Nome categoria",
                placeholder: "Es. Wedding planner, Bartender, …",
                text: $name,
                icon: "tag",
                autocapitalization: .words,
                errorMessage: nameError,
                isDisabled: isLoading
            )

            VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
                Text("Descrizione (opzionale)")
                    .font(BrindooFont.bodySmall.weight(.medium))
                    .foregroundStyle(Color.brindooTextSecondary)
                TextField(
                    "Cosa fa chi opera in questa categoria?",
                    text: $description,
                    axis: .vertical
                )
                .lineLimit(3...6)
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
                    Text("\(description.count)/280")
                        .font(BrindooFont.caption)
                        .foregroundStyle(description.count > 280 ? Color.brindooError : Color.brindooTextSecondary)
                }
            }

            if let generalError {
                HStack(spacing: BrindooSpacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(generalError).font(BrindooFont.bodySmall)
                }
                .foregroundStyle(Color.brindooError)
                .padding(BrindooSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.brindooError.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
            }

            BrindooButton(
                "Invia proposta",
                style: .primary,
                size: .large,
                isLoading: isLoading
            ) {
                Task { await submit() }
            }
        }
    }

    @ViewBuilder
    private var successView: some View {
        VStack(spacing: BrindooSpacing.lg) {
            ZStack {
                Circle()
                    .fill(Color.brindooSuccess.opacity(0.15))
                    .frame(width: 100, height: 100)
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.brindooSuccess)
            }
            .padding(.top, BrindooSpacing.xl)

            Text("Proposta inviata!")
                .font(BrindooFont.titleLarge)

            Text("Grazie per il suggerimento. La valuteremo e ti faremo sapere se aggiungeremo «\(name)» al catalogo.")
                .font(BrindooFont.bodyLarge)
                .foregroundStyle(Color.brindooTextSecondary)
                .multilineTextAlignment(.center)

            BrindooButton("Chiudi", style: .secondary, size: .large) { dismiss() }
                .padding(.top, BrindooSpacing.lg)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Submit

    private func submit() async {
        nameError = nil
        generalError = nil

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard trimmedName.count >= 2 else {
            nameError = "Nome troppo corto (min 2 caratteri)"
            return
        }
        guard trimmedName.count <= 60 else {
            nameError = "Nome troppo lungo (max 60 caratteri)"
            return
        }
        guard description.count <= 280 else {
            generalError = "Descrizione troppo lunga (max 280 caratteri)"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await CategoryService.shared.proposeCategorySuggestion(
                name: trimmedName,
                description: description.isEmpty ? nil : description
            )
            success = true
        } catch {
            generalError = "Impossibile inviare la proposta. Riprova."
            print("❌ \(error)")
        }
    }
}
