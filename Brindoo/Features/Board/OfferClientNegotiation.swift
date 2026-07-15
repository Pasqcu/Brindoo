//
//  OfferClientNegotiation.swift
//  Brindoo
//
//  Sezione trattativa lato CLIENTE nel dettaglio offerta:
//  - nessuna trattativa: 3 azioni iniziali (accetta / proponi / nascondi)
//  - trattativa in corso: stato, ultima proposta e azioni coerenti col turno.
//

import SwiftUI

struct ClientNegotiationSection: View {
    let offer: ServiceOffer
    let proposal: OfferProposal?
    let organizerProfile: Profile?

    var onAcceptAtPrice: () -> Void
    var onProposeNew: () -> Void
    var onHide: () -> Void
    var onAccept: (OfferProposal) -> Void
    var onReject: (OfferProposal) -> Void
    var onCounter: (OfferProposal) -> Void
    var onWithdraw: (OfferProposal) -> Void
    var onOpenChat: (Profile) -> Void
    var onMarkBooking: (OfferProposal, BookingStatus) -> Void
    var onMoveDate: (OfferProposal) -> Void
    var onAddToCalendar: (OfferProposal) -> Void
    /// Chiamata dopo l'invio di una recensione (per ricaricare i dati).
    var onReviewSubmitted: () -> Void

    @State private var showWriteReview: Bool = false

    var body: some View {
        if let proposal {
            existingProposalCard(proposal)
        } else {
            initialClientActions
        }
    }

    // MARK: - Nessuna trattativa: azioni iniziali

    @ViewBuilder
    private var initialClientActions: some View {
        VStack(spacing: BrindooSpacing.sm) {
            Text("Cosa vuoi fare?")
                .font(BrindooFont.titleSmall)
                .frame(maxWidth: .infinity, alignment: .leading)

            BrindooButton(
                "Accetta a \(offer.priceDisplay)",
                style: .primary,
                size: .large,
                icon: "checkmark"
            ) {
                onAcceptAtPrice()
            }

            BrindooButton(
                "Fai una proposta",
                style: .secondary,
                size: .medium,
                icon: "arrow.left.arrow.right"
            ) {
                onProposeNew()
            }

            Button {
                onHide()
            } label: {
                Label("Nascondi questa offerta", systemImage: "eye.slash")
                    .font(BrindooFont.bodySmall.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, BrindooSpacing.sm)
                    .foregroundStyle(Color.brindooTextSecondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Trattativa in corso

    @ViewBuilder
    private func existingProposalCard(_ proposal: OfferProposal) -> some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
            HStack {
                Text("Trattativa in corso")
                    .font(BrindooFont.titleSmall)
                Spacer()
                ProposalStatusPill(status: proposal.status)
            }

            // Mostra "ultima controproposta" — chi ha proposto cosa.
            HStack(spacing: BrindooSpacing.sm) {
                Image(systemName: proposal.lastProposer == .organizer ? "person.badge.shield.checkmark" : "person.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.brindooCoral)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(proposal.lastProposer == .organizer ? "Controproposta organizzatore" : "La tua proposta")
                        .font(BrindooFont.bodySmall.weight(.semibold))
                    Text(proposal.currentPriceDisplay)
                        .font(BrindooFont.titleMedium)
                        .foregroundStyle(Color.brindooCoral)
                }
                Spacer()
                Text(proposal.updatedAtDisplay)
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooTextSecondary)
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

            proposalActions(proposal)
        }
        .padding(BrindooSpacing.md)
        .background(Color.brindooSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
    }

    @ViewBuilder
    private func proposalActions(_ proposal: OfferProposal) -> some View {
        if proposal.status == .accepted, let org = organizerProfile {
            VStack(spacing: BrindooSpacing.sm) {
                BookingStatusRow(proposal: proposal)

                BrindooButton("Apri chat", style: .primary, size: .medium, icon: "bubble.left.and.bubble.right.fill") {
                    onOpenChat(org)
                }

                if proposal.effectiveBooking == .completed {
                    BrindooButton("Lascia una recensione", style: .secondary, size: .medium, icon: "star.fill") {
                        showWriteReview = true
                    }
                }

                BookingActionButtons(
                    proposal: proposal,
                    onMark: { status in onMarkBooking(proposal, status) },
                    onMoveDate: { onMoveDate(proposal) },
                    onAddToCalendar: proposal.eventDate == nil ? nil : { onAddToCalendar(proposal) }
                )
            }
            .sheet(isPresented: $showWriteReview) {
                WriteReviewView(organizer: org, existingReview: nil) {
                    onReviewSubmitted()
                }
            }
        } else if proposal.status == .pending {
            if proposal.lastProposer == .organizer {
                // Palla al cliente: può accettare, controproporre o rifiutare la controproposta.
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
            } else {
                // L'utente sta aspettando una risposta dall'organizzatore.
                Text("In attesa di risposta dall'organizzatore.")
                    .font(BrindooFont.bodySmall)
                    .foregroundStyle(Color.brindooTextSecondary)

                BrindooButton(
                    "Ritira proposta",
                    style: .tertiary,
                    size: .medium
                ) {
                    onWithdraw(proposal)
                }
            }
        }
    }
}
