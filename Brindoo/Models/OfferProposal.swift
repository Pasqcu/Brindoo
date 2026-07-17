//
//  OfferProposal.swift
//  Brindoo
//
//  Modelli per la trattativa stile Vinted tra cliente e organizzatore
//  su un'offerta di servizio (service_offer).
//

import Foundation

/// Stato di una trattativa.
enum OfferProposalStatus: String, Codable, CaseIterable {
    case pending     // in attesa di risposta dell'altra parte
    case accepted    // accettata dall'altra parte (deal chiuso)
    case rejected    // rifiutata
    case withdrawn   // ritirata dal cliente

    var displayName: String {
        switch self {
        case .pending:   return "In attesa"
        case .accepted:  return "Accettata"
        case .rejected:  return "Rifiutata"
        case .withdrawn: return "Ritirata"
        }
    }

    var iconName: String {
        switch self {
        case .pending:   return "clock.fill"
        case .accepted:  return "checkmark.circle.fill"
        case .rejected:  return "xmark.circle.fill"
        case .withdrawn: return "arrow.uturn.backward.circle.fill"
        }
    }
}

/// Ruolo che ha emesso l'ultima proposta della trattativa.
enum ProposerRole: String, Codable {
    case client
    case organizer
}

/// Stato dell'appuntamento dopo che la trattativa è stata accettata.
enum BookingStatus: String, Codable, CaseIterable {
    case confirmed   // accordo confermato, evento da svolgere
    case completed   // evento svolto
    case cancelled   // appuntamento annullato

    var displayName: String {
        switch self {
        case .confirmed: return "Confermato"
        case .completed: return "Svolto"
        case .cancelled: return "Annullato"
        }
    }

    var iconName: String {
        switch self {
        case .confirmed: return "calendar.badge.checkmark"
        case .completed: return "checkmark.seal.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }
}

/// Trattativa attiva (una per coppia offerta + cliente, attiva).
struct OfferProposal: Identifiable, Codable, Hashable, Equatable {
    let id: UUID
    let offerId: UUID
    let clientId: UUID
    let organizerId: UUID
    let currentPrice: Double
    let lastProposer: ProposerRole
    let lastMessage: String?
    let status: OfferProposalStatus
    /// Data dell'evento concordata (facoltativa), formato "yyyy-MM-dd".
    let eventDate: String?
    /// Stato dell'appuntamento dopo l'accettazione (facoltativo).
    let bookingStatus: BookingStatus?
    /// True se le parti hanno registrato il versamento dell'acconto.
    var depositPaid: Bool? = nil
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case offerId = "offer_id"
        case clientId = "client_id"
        case organizerId = "organizer_id"
        case currentPrice = "current_price"
        case lastProposer = "last_proposer"
        case lastMessage = "last_message"
        case status
        case eventDate = "event_date"
        case bookingStatus = "booking_status"
        case depositPaid = "deposit_paid"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var isDepositPaid: Bool { depositPaid ?? false }

    /// Stato effettivo dell'appuntamento (default: confermato se accettata).
    var effectiveBooking: BookingStatus {
        bookingStatus ?? (status == .accepted ? .confirmed : .confirmed)
    }

    /// True se l'evento ha una data già passata.
    var isEventPast: Bool {
        guard let eventDate, !eventDate.isEmpty else { return false }
        guard let d = BrindooFormat.day(from: eventDate) else { return false }
        return d < Calendar.current.startOfDay(for: Date())
    }

    /// "21 maggio 2026" oppure nil se non impostata.
    var eventDateDisplay: String? {
        guard let eventDate, !eventDate.isEmpty else { return nil }
        return BrindooFormat.italianDate(fromDay: eventDate)
    }

    var currentPriceDisplay: String {
        BrindooFormat.euro(currentPrice)
    }

    var updatedAtDisplay: String {
        BrindooFormat.timeAgoShort(updatedAt)
    }

    /// True se l'utente passato deve rispondere (la palla è dalla sua parte).
    func awaitingAction(by userId: UUID) -> Bool {
        guard status == .pending else { return false }
        switch lastProposer {
        case .client:    return userId == organizerId
        case .organizer: return userId == clientId
        }
    }
}

/// Round della trattativa: ogni controproposta o proposta iniziale è un round.
struct OfferProposalRound: Identifiable, Codable, Hashable, Equatable {
    let id: UUID
    let proposalId: UUID
    let proposerRole: ProposerRole
    let price: Double
    let message: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case proposalId = "proposal_id"
        case proposerRole = "proposer_role"
        case price
        case message
        case createdAt = "created_at"
    }

    var priceDisplay: String {
        BrindooFormat.euro(price)
    }
}
