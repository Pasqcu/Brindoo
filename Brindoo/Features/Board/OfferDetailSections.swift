//
//  OfferDetailSections.swift
//  Brindoo
//
//  Pezzi riusabili del dettaglio offerta: pill di stato, righe appuntamento,
//  azioni post-accordo, sezione "Proposte ricevute" (lato organizzatore)
//  e pannello "Sposta data". (Estratti da OfferDetailView.)
//

import SwiftUI

// MARK: - Pill stato trattativa

struct ProposalStatusPill: View {
    let status: OfferProposalStatus

    var body: some View {
        let color: Color = {
            switch status {
            case .pending:   return .brindooWarning
            case .accepted:  return .brindooSuccess
            case .rejected:  return .brindooError
            case .withdrawn: return .brindooTextSecondary
            }
        }()
        HStack(spacing: 4) {
            Image(systemName: status.iconName)
                .font(.system(size: 9))
            Text(status.displayName)
                .font(BrindooFont.caption.weight(.medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}

// MARK: - Riga stato appuntamento

struct BookingStatusRow: View {
    let proposal: OfferProposal

    var body: some View {
        let booking = proposal.effectiveBooking
        let color: Color = {
            switch booking {
            case .confirmed: return .brindooSuccess
            case .completed: return .brindooCoral
            case .cancelled: return .brindooError
            }
        }()
        HStack(spacing: BrindooSpacing.xs) {
            Image(systemName: booking.iconName)
                .font(.system(size: 13, weight: .semibold))
            Text("Appuntamento: \(booking.displayName)")
                .font(BrindooFont.bodySmall.weight(.semibold))
            Spacer()
        }
        .foregroundStyle(color)
        .padding(.vertical, BrindooSpacing.xxs)
        .padding(.horizontal, BrindooSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
    }
}

// MARK: - Riga data evento

struct EventDateRow: View {
    let dateText: String

    var body: some View {
        HStack(spacing: BrindooSpacing.xs) {
            Image(systemName: "calendar")
                .font(.system(size: 13, weight: .medium))
            Text("Data evento: \(dateText)")
                .font(BrindooFont.bodySmall.weight(.medium))
            Spacer()
        }
        .foregroundStyle(Color.brindooCoral)
        .padding(.vertical, BrindooSpacing.xxs)
        .padding(.horizontal, BrindooSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brindooCoral.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
    }
}

// MARK: - Azioni sull'appuntamento confermato

/// Segna svolto / Annulla + Sposta data + Aggiungi al calendario.
struct BookingActionButtons: View {
    let proposal: OfferProposal
    let onMark: (BookingStatus) -> Void
    let onMoveDate: () -> Void
    let onAddToCalendar: (() -> Void)?

    var body: some View {
        if proposal.effectiveBooking == .confirmed {
            VStack(spacing: BrindooSpacing.xs) {
                HStack(spacing: BrindooSpacing.sm) {
                    Button { onMark(.completed) } label: {
                        Label("Segna svolto", systemImage: "checkmark.seal")
                            .font(BrindooFont.bodySmall.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(Color.brindooSuccess)
                            .background(Color.brindooSuccess.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
                    }
                    .buttonStyle(.plain)

                    Button { onMark(.cancelled) } label: {
                        Label("Annulla", systemImage: "calendar.badge.minus")
                            .font(BrindooFont.bodySmall.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(Color.brindooError)
                            .background(Color.brindooError.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: BrindooSpacing.sm) {
                    Button { onMoveDate() } label: {
                        Label(proposal.eventDate == nil ? "Fissa una data" : "Sposta data",
                              systemImage: "calendar.badge.clock")
                            .font(BrindooFont.bodySmall.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(Color.brindooCoral)
                            .background(Color.brindooCoral.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
                    }
                    .buttonStyle(.plain)

                    if let onAddToCalendar {
                        Button { onAddToCalendar() } label: {
                            Label("Nel calendario", systemImage: "calendar.badge.plus")
                                .font(BrindooFont.bodySmall.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .foregroundStyle(Color.brindooTextPrimary)
                                .background(Color.brindooSurface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: BrindooRadius.sm)
                                        .strokeBorder(Color.brindooBorder, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - Pannello "Sposta data"

struct MoveEventDateSheet: View {
    let proposal: OfferProposal
    let onConfirm: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate: Date = Date()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: BrindooSpacing.lg) {
                Text("L'altra parte riceverà un messaggio automatico in chat con la nuova data.")
                    .font(BrindooFont.bodySmall)
                    .foregroundStyle(Color.brindooTextSecondary)

                DatePicker(
                    "Nuova data",
                    selection: $selectedDate,
                    in: Calendar.current.startOfDay(for: Date())...,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .environment(\.locale, Locale(identifier: "it_IT"))
                .tint(Color.brindooCoral)

                Spacer()
            }
            .padding(BrindooSpacing.lg)
            .background(Color.brindooBackground)
            .navigationTitle(proposal.eventDate == nil ? "Fissa la data" : "Sposta la data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Conferma") {
                        onConfirm(Self.dayFormatter.string(from: selectedDate))
                        dismiss()
                    }
                    .font(BrindooFont.bodyMedium.weight(.semibold))
                }
            }
            .onAppear {
                if let current = proposal.eventDate,
                   let d = Self.dayFormatter.date(from: current), d > Date() {
                    selectedDate = d
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Proposte ricevute (lato organizzatore proprietario)

struct ReceivedProposalsSection: View {
    let offer: ServiceOffer
    let proposals: [OfferProposal]
    let clientProfiles: [UUID: Profile]

    let onAccept: (OfferProposal) -> Void
    let onReject: (OfferProposal) -> Void
    let onCounter: (OfferProposal) -> Void
    let onOpenChat: (Profile) -> Void
    let onMarkBooking: (OfferProposal, BookingStatus) -> Void
    let onMoveDate: (OfferProposal) -> Void
    let onAddToCalendar: (OfferProposal) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
            HStack {
                Text("Proposte ricevute")
                    .font(BrindooFont.titleSmall)
                Spacer()
                if !proposals.isEmpty {
                    Text("\(proposals.count)")
                        .font(BrindooFont.caption.weight(.semibold))
                        .padding(.horizontal, BrindooSpacing.xs)
                        .padding(.vertical, 3)
                        .background(Color.brindooCoral)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }

            if proposals.isEmpty {
                Text("Nessuna proposta ancora. Quando un cliente farà una proposta apparirà qui.")
                    .font(BrindooFont.bodySmall)
                    .foregroundStyle(Color.brindooTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(BrindooSpacing.md)
                    .background(Color.brindooSurface)
                    .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
            } else {
                ForEach(proposals) { proposal in
                    card(proposal)
                }
            }
        }
    }

    @ViewBuilder
    private func card(_ proposal: OfferProposal) -> some View {
        let client = clientProfiles[proposal.clientId]
        VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
            HStack(spacing: BrindooSpacing.sm) {
                AvatarView(url: client?.avatarUrl, name: client?.fullName, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(client?.fullName ?? "Cliente")
                        .font(BrindooFont.bodyMedium.weight(.semibold))
                    Text(proposal.updatedAtDisplay)
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextSecondary)
                }
                Spacer()
                ProposalStatusPill(status: proposal.status)
            }

            HStack(spacing: BrindooSpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(proposal.lastProposer == .client ? "Proposta del cliente" : "Tua controproposta")
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextSecondary)
                    Text(proposal.currentPriceDisplay)
                        .font(BrindooFont.titleSmall)
                        .foregroundStyle(Color.brindooCoral)
                }
                Spacer()
            }

            if let eventDate = proposal.eventDateDisplay {
                EventDateRow(dateText: eventDate)
            }

            if let lastMessage = proposal.lastMessage, !lastMessage.isEmpty {
                Text("\"\(lastMessage)\"")
                    .font(BrindooFont.bodySmall)
                    .foregroundStyle(Color.brindooTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            actions(proposal, client: client)
        }
        .padding(BrindooSpacing.md)
        .background(Color.brindooSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
    }

    @ViewBuilder
    private func actions(_ proposal: OfferProposal, client: Profile?) -> some View {
        if proposal.status == .accepted, let client {
            VStack(spacing: BrindooSpacing.sm) {
                BookingStatusRow(proposal: proposal)
                BrindooButton("Apri chat", style: .primary, size: .medium, icon: "bubble.left.and.bubble.right.fill") {
                    onOpenChat(client)
                }
                BookingActionButtons(
                    proposal: proposal,
                    onMark: { onMarkBooking(proposal, $0) },
                    onMoveDate: { onMoveDate(proposal) },
                    onAddToCalendar: proposal.eventDate == nil ? nil : { onAddToCalendar(proposal) }
                )

                // Promemoria scritto dell'accordo anche per il professionista.
                ShareLink(item: AgreementSummary.text(
                    offer: offer,
                    organizerName: nil,
                    proposal: proposal
                )) {
                    Label("Condividi riepilogo accordo", systemImage: "doc.text")
                        .font(BrindooFont.bodySmall.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, BrindooSpacing.sm)
                        .foregroundStyle(Color.brindooCoral)
                }
            }
        } else if proposal.status == .pending, proposal.lastProposer == .client {
            VStack(spacing: BrindooSpacing.sm) {
                HStack(spacing: BrindooSpacing.sm) {
                    Button { onReject(proposal) } label: {
                        Label("Rifiuta", systemImage: "xmark")
                            .font(BrindooFont.bodySmall.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(Color.brindooError)
                            .background(Color.brindooError.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
                    }
                    .buttonStyle(.plain)

                    Button { onAccept(proposal) } label: {
                        Label("Accetta", systemImage: "checkmark")
                            .font(BrindooFont.bodySmall.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(.white)
                            .background(Color.brindooSuccess)
                            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
                    }
                    .buttonStyle(.plain)
                }
                BrindooButton(
                    "Controproponi",
                    style: .secondary,
                    size: .medium,
                    icon: "arrow.left.arrow.right"
                ) {
                    onCounter(proposal)
                }
            }
        } else if proposal.status == .pending && proposal.lastProposer == .organizer {
            Text("In attesa di risposta dal cliente.")
                .font(BrindooFont.bodySmall)
                .foregroundStyle(Color.brindooTextSecondary)
        }
    }
}
