//
//  OfferClientNegotiation.swift
//  Brindoo
//
//  Sezione trattativa lato CLIENTE nel dettaglio offerta:
//  - nessuna trattativa: 3 azioni iniziali (accetta / proponi / nascondi)
//  - trattativa in corso: stato, ultima proposta e azioni coerenti col turno.
//

import SwiftUI

// MARK: - Conto alla rovescia evento

/// "Mancano 12 giorni all'evento" + suggerimento contestuale.
/// Non mostra nulla per date passate o non valide.
struct EventCountdownRow: View {
    /// Data dell'evento, formato "yyyy-MM-dd".
    let eventDay: String

    var body: some View {
        if let days = Self.daysUntil(eventDay), days >= 0 {
            HStack(alignment: .top, spacing: BrindooSpacing.xs) {
                Image(systemName: days == 0 ? "party.popper.fill" : "hourglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.brindooCoral)
                VStack(alignment: .leading, spacing: 2) {
                    Text(countdownText(days: days))
                        .font(BrindooFont.bodySmall.weight(.semibold))
                        .foregroundStyle(Color.brindooCoral)
                    Text(tip(days: days))
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(BrindooSpacing.sm)
            .background(Color.brindooCoral.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
        }
    }

    private func countdownText(days: Int) -> String {
        switch days {
        case 0:  return "L'evento è oggi!"
        case 1:  return "Manca 1 giorno all'evento"
        default: return "Mancano \(days) giorni all'evento"
        }
    }

    private func tip(days: Int) -> String {
        switch days {
        case 0:       return "In bocca al lupo! Dopo l'evento potrai lasciare una recensione."
        case 1...7:   return "Manca poco: conferma orari e ultimi dettagli in chat."
        case 8...30:  return "Definisci per tempo orari, luogo e dettagli in chat."
        default:      return "Tutto con calma: tieni d'occhio i dettagli man mano che si avvicina."
        }
    }

    /// Giorni da oggi alla data (nil se il formato non è valido).
    static func daysUntil(_ day: String, from now: Date = Date()) -> Int? {
        guard let target = BrindooFormat.day(from: day) else { return nil }
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "UTC") ?? calendar.timeZone
        let start = calendar.startOfDay(for: now)
        return calendar.dateComponents([.day], from: start, to: target).day
    }
}

struct ClientNegotiationSection: View {
    let offer: ServiceOffer
    let proposal: OfferProposal?
    let organizerProfile: Profile?
    /// Pacchetti prezzo dell'offerta (se presenti il cliente può sceglierne uno).
    var packages: [OfferPackage] = []

    /// Accetta al prezzo dato; l'etichetta (es. "Pacchetto Base") finisce
    /// nel messaggio della proposta, se presente.
    var onAcceptAtPrice: (Double, String?) -> Void
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
    @State private var selectedPackageId: UUID?

    private var selectedPackage: OfferPackage? {
        packages.first { $0.id == selectedPackageId }
    }

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

            // Con i pacchetti il cliente sceglie la versione del servizio;
            // senza selezione si accetta il prezzo base dell'offerta.
            if !packages.isEmpty {
                OfferPackagesDisplay(packages: packages, selectedId: $selectedPackageId)
            }

            BrindooButton(
                selectedPackage.map { "Accetta \($0.name) a \($0.priceDisplay)" }
                    ?? "Accetta a \(offer.priceDisplay)",
                style: .primary,
                size: .large,
                icon: "checkmark"
            ) {
                if let package = selectedPackage {
                    onAcceptAtPrice(package.price, "Pacchetto \(package.name)")
                } else {
                    onAcceptAtPrice(offer.price, nil)
                }
            }

            BrindooButton(
                "Fai una proposta",
                style: .secondary,
                size: .medium,
                icon: "arrow.left.arrow.right"
            ) {
                onProposeNew()
            }

            // Il cliente conosce le condizioni PRIMA di impegnarsi.
            CancellationPolicyRow()

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

            // Accordo chiuso con data futura: conto alla rovescia + suggerimento.
            if proposal.status == .accepted, let day = proposal.eventDate {
                EventCountdownRow(eventDay: day)
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

                // Promemoria scritto dell'accordo: prezzo, data, acconto e regole.
                ShareLink(item: AgreementSummary.text(
                    offer: offer,
                    organizerName: org.displayName,
                    proposal: proposal
                )) {
                    Label("Condividi riepilogo accordo", systemImage: "doc.text")
                        .font(BrindooFont.bodySmall.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, BrindooSpacing.sm)
                        .foregroundStyle(Color.brindooCoral)
                }

                CancellationPolicyRow()

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

                    CancellationPolicyRow()
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
