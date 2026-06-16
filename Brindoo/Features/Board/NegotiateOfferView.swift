//
//  NegotiateOfferView.swift
//  Brindoo
//
//  Form sheet usato per:
//   - Aprire una nuova trattativa (cliente che propone un prezzo diverso)
//   - Contropropore (cliente o organizzatore, su una trattativa esistente)
//

import SwiftUI

struct NegotiateOfferView: View {

    enum Mode {
        /// Cliente apre la trattativa su un'offerta.
        case openAsClient(offer: ServiceOffer)
        /// Controproposta da parte di cliente/organizzatore su trattativa esistente.
        case counter(proposal: OfferProposal, role: ProposerRole, offer: ServiceOffer)
    }

    let mode: Mode
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var price: String = ""
    @State private var message: String = ""

    @State private var includeEventDate: Bool = false
    @State private var eventDate: Date = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()

    @State private var priceError: String?
    @State private var generalError: String?
    @State private var isLoading: Bool = false

    private var isOpening: Bool {
        if case .openAsClient = mode { return true }
        return false
    }

    private var title: String {
        switch mode {
        case .openAsClient: return "Fai una proposta"
        case .counter:      return "Controproposta"
        }
    }

    private var ctaTitle: String {
        switch mode {
        case .openAsClient: return "Invia proposta"
        case .counter:      return "Invia controproposta"
        }
    }

    private var contextOffer: ServiceOffer {
        switch mode {
        case .openAsClient(let offer):       return offer
        case .counter(_, _, let offer):      return offer
        }
    }

    private var referencePriceLabel: String {
        switch mode {
        case .openAsClient(let offer):
            return "Prezzo richiesto: \(offer.priceDisplay)"
        case .counter(let proposal, _, _):
            return "Ultima offerta: \(proposal.currentPriceDisplay)"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BrindooSpacing.lg) {

                    VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
                        Text(contextOffer.title)
                            .font(BrindooFont.titleMedium)
                            .lineLimit(2)
                        Text(referencePriceLabel)
                            .font(BrindooFont.bodySmall)
                            .foregroundStyle(Color.brindooTextSecondary)
                    }
                    .padding(BrindooSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.brindooSurface)
                    .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))

                    BrindooTextField(
                        title: "Il tuo prezzo (€)",
                        placeholder: "Es. 250",
                        text: $price,
                        icon: "eurosign",
                        keyboardType: .numberPad,
                        errorMessage: priceError,
                        isDisabled: isLoading
                    )

                    VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
                        Text("Messaggio (opzionale)")
                            .font(BrindooFont.bodySmall.weight(.medium))
                            .foregroundStyle(Color.brindooTextSecondary)
                        TextField("Spiega la tua proposta…", text: $message, axis: .vertical)
                            .lineLimit(3...8)
                            .font(BrindooFont.bodyLarge)
                            .padding(BrindooSpacing.md)
                            .background(Color.brindooSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: BrindooRadius.md)
                                    .strokeBorder(Color.brindooBorder, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
                            .disabled(isLoading)
                    }

                    if isOpening {
                        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
                            Toggle(isOn: $includeEventDate) {
                                HStack(spacing: BrindooSpacing.xs) {
                                    Image(systemName: "calendar")
                                        .foregroundStyle(Color.brindooCoral)
                                    Text("Indica la data dell'evento")
                                        .font(BrindooFont.bodyMedium.weight(.medium))
                                }
                            }
                            .tint(Color.brindooCoral)
                            .disabled(isLoading)

                            if includeEventDate {
                                DatePicker(
                                    "Data evento",
                                    selection: $eventDate,
                                    in: Date()...,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.compact)
                                .environment(\.locale, Locale(identifier: "it_IT"))
                                .disabled(isLoading)
                            }
                        }
                        .padding(BrindooSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.brindooSurface)
                        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
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
                }
                .padding(BrindooSpacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.brindooBackground)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annulla") { dismiss() }
                        .disabled(isLoading)
                }
            }
            .safeAreaInset(edge: .bottom) {
                BrindooButton(ctaTitle, style: .primary, size: .large, isLoading: isLoading) {
                    Task { await submit() }
                }
                .padding(.horizontal, BrindooSpacing.lg)
                .padding(.vertical, BrindooSpacing.sm)
                .background(
                    Color.brindooBackground
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: -2)
                )
            }
        }
    }

    private func submit() async {
        priceError = nil; generalError = nil

        guard let priceVal = Double(price.replacingOccurrences(of: ",", with: ".")),
              priceVal > 0 else {
            priceError = "Inserisci un prezzo valido"
            return
        }

        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let messageVal: String? = trimmedMessage.isEmpty ? nil : trimmedMessage

        isLoading = true
        defer { isLoading = false }

        var eventDateString: String? = nil
        if includeEventDate {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.timeZone = TimeZone(identifier: "UTC")
            eventDateString = f.string(from: eventDate)
        }

        do {
            switch mode {
            case .openAsClient(let offer):
                _ = try await OfferProposalService.shared.openProposal(
                    offer: offer,
                    price: priceVal,
                    message: messageVal,
                    eventDate: eventDateString
                )
            case .counter(let proposal, let role, _):
                try await OfferProposalService.shared.counterProposal(
                    proposal: proposal,
                    role: role,
                    price: priceVal,
                    message: messageVal
                )
            }
            onDone()
            dismiss()
        } catch {
            generalError = "Impossibile inviare la proposta. Riprova."
            print("❌ \(error)")
        }
    }
}
