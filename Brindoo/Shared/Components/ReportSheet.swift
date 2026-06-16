//
//  ReportSheet.swift
//  Brindoo
//
//  Sheet riutilizzabile per segnalare contenuti UGC (utenti, recensioni,
//  messaggi, foto portfolio, offerte). Mostrato da:
//  - ChatView (segnala utente, segnala messaggio)
//  - ReviewsListView (segnala recensione)
//  - OrganizerDetailView (segnala profilo)
//  - PortfolioGalleryView (segnala foto)
//  - OfferDetailView (segnala offerta)
//

import SwiftUI

struct ReportSheet: View {

    let targetType: ReportTargetType
    let targetId: UUID
    /// Nome leggibile del target (utente, "questa recensione", ...) — solo UI.
    let targetLabel: String

    @Environment(\.dismiss) private var dismiss

    @State private var selectedReason: ReportReason?
    @State private var description: String = ""
    @State private var isSending: Bool = false
    @State private var errorMessage: String?
    @State private var showSuccess: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                if showSuccess {
                    successView
                } else {
                    formView
                }
            }
            .background(Color.brindooBackground)
            .navigationTitle("Segnala")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annulla") { dismiss() }
                        .disabled(isSending)
                }
            }
        }
    }

    // MARK: - Form

    @ViewBuilder
    private var formView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrindooSpacing.lg) {

                VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
                    Text("Segnala \(targetLabel)")
                        .font(BrindooFont.titleLarge)

                    Text("Le segnalazioni sono riservate. Il team di moderazione "
                         + "risponderà entro 24 ore. Per violazioni gravi "
                         + "(minacce, attività illegali) contatta anche le autorità competenti.")
                        .font(BrindooFont.bodySmall)
                        .foregroundStyle(Color.brindooTextSecondary)
                }
                .padding(.top, BrindooSpacing.md)

                Text("Motivo della segnalazione")
                    .font(BrindooFont.titleSmall)
                    .padding(.top, BrindooSpacing.sm)

                VStack(spacing: BrindooSpacing.xs) {
                    ForEach(ReportReason.allCases) { reason in
                        reasonRow(reason)
                    }
                }

                if selectedReason != nil {
                    Text("Dettagli (opzionale)")
                        .font(BrindooFont.titleSmall)
                        .padding(.top, BrindooSpacing.sm)

                    TextField(
                        "Descrivi brevemente cosa è successo…",
                        text: $description,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                    .font(BrindooFont.bodyMedium)
                    .padding(BrindooSpacing.md)
                    .background(Color.brindooSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: BrindooRadius.md)
                            .strokeBorder(Color.brindooBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
                    .disabled(isSending)

                    HStack {
                        Spacer()
                        Text("\(description.count)/1000")
                            .font(BrindooFont.caption)
                            .foregroundStyle(
                                description.count > 1000
                                    ? Color.brindooError
                                    : Color.brindooTextSecondary
                            )
                    }
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
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            BrindooButton(
                "Invia segnalazione",
                style: .primary,
                size: .large,
                icon: "paperplane.fill",
                isLoading: isSending,
                isDisabled: selectedReason == nil || description.count > 1000
            ) {
                Task { await send() }
            }
            .padding(.horizontal, BrindooSpacing.lg)
            .padding(.vertical, BrindooSpacing.sm)
            .background(
                Color.brindooBackground
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: -2)
            )
        }
    }

    @ViewBuilder
    private func reasonRow(_ reason: ReportReason) -> some View {
        let isSelected = selectedReason == reason

        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedReason = reason
            }
        } label: {
            HStack(spacing: BrindooSpacing.sm) {
                Image(systemName: reason.systemIcon)
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? .white : Color.brindooCoral)
                    .frame(width: 32, height: 32)
                    .background(
                        isSelected ? Color.brindooCoral : Color.brindooCoral.opacity(0.12)
                    )
                    .clipShape(Circle())

                Text(reason.displayName)
                    .font(BrindooFont.bodyMedium)
                    .foregroundStyle(Color.brindooTextPrimary)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Color.brindooCoral : Color.brindooBorder)
            }
            .padding(BrindooSpacing.sm)
            .background(
                isSelected ? Color.brindooCoral.opacity(0.05) : Color.brindooSurface
            )
            .overlay(
                RoundedRectangle(cornerRadius: BrindooRadius.md)
                    .strokeBorder(
                        isSelected ? Color.brindooCoral : Color.clear,
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
        }
        .buttonStyle(.plain)
        .disabled(isSending)
    }

    // MARK: - Success

    @ViewBuilder
    private var successView: some View {
        VStack(spacing: BrindooSpacing.lg) {
            ZStack {
                Circle()
                    .fill(Color.brindooSuccess.opacity(0.15))
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.brindooSuccess)
            }
            .padding(.top, BrindooSpacing.xl)

            Text("Segnalazione ricevuta")
                .font(BrindooFont.titleLarge)

            Text("Grazie per averci aiutato a mantenere Brindoo sicuro. "
                 + "Il nostro team la esaminerà entro 24 ore.")
                .font(BrindooFont.bodyLarge)
                .foregroundStyle(Color.brindooTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, BrindooSpacing.lg)

            BrindooButton("Chiudi", style: .primary, size: .large) {
                dismiss()
            }
            .padding(.horizontal, BrindooSpacing.lg)
            .padding(.top, BrindooSpacing.md)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(BrindooSpacing.lg)
    }

    // MARK: - Actions

    private func send() async {
        guard let reason = selectedReason else { return }

        errorMessage = nil
        isSending = true
        defer { isSending = false }

        do {
            try await ReportService.shared.report(
                targetType: targetType,
                targetId: targetId,
                reason: reason,
                description: description
            )
            withAnimation { showSuccess = true }
        } catch {
            errorMessage = "Impossibile inviare la segnalazione. Riprova più tardi."
        }
    }
}
