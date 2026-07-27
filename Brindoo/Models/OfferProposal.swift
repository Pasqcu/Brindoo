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
    /// Come si è deciso di pagare acconto e saldo.
    var depositMethod: PaymentMethod? = nil
    var balanceMethod: PaymentMethod? = nil
    /// Importo dell'acconto dichiarato da chi incassa.
    var depositAmount: Double? = nil
    var depositNote: String? = nil
    /// Chi ha dichiarato di aver ricevuto l'acconto, e quando.
    var depositDeclaredBy: UUID? = nil
    var depositDeclaredAt: Date? = nil
    /// Conferma dell'altra parte: è questa che chiude il cerchio.
    var depositConfirmedBy: UUID? = nil
    var depositConfirmedAt: Date? = nil
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
        case depositMethod = "deposit_method"
        case balanceMethod = "balance_method"
        case depositAmount = "deposit_amount"
        case depositNote = "deposit_note"
        case depositDeclaredBy = "deposit_declared_by"
        case depositDeclaredAt = "deposit_declared_at"
        case depositConfirmedBy = "deposit_confirmed_by"
        case depositConfirmedAt = "deposit_confirmed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// L'acconto è "versato" solo quando anche l'altra parte ha confermato.
    var isDepositPaid: Bool { depositConfirmedAt != nil || (depositPaid ?? false) }

    /// Acconto dichiarato ma non ancora confermato dall'altra parte.
    var isDepositAwaitingConfirmation: Bool {
        depositDeclaredAt != nil && depositConfirmedAt == nil
    }

    /// Chi deve confermare adesso (nil se non c'è nulla in sospeso).
    var depositConfirmationPending: Bool { isDepositAwaitingConfirmation }

    /// True se tocca a questo utente confermare l'acconto dichiarato dall'altro.
    func canConfirmDeposit(as userId: UUID) -> Bool {
        isDepositAwaitingConfirmation && depositDeclaredBy != userId
    }

    /// Importo dell'acconto leggibile, o nil se non dichiarato.
    var depositAmountDisplay: String? {
        guard let depositAmount else { return nil }
        return BrindooFormat.euro(depositAmount)
    }

    /// Quanto resta da saldare dopo l'acconto.
    var balanceDueDisplay: String? {
        guard let depositAmount, depositAmount > 0, depositAmount < currentPrice else { return nil }
        return BrindooFormat.euro(currentPrice - depositAmount)
    }

    /// Stato effettivo dell'appuntamento (default: confermato se accettata).
    var effectiveBooking: BookingStatus {
        bookingStatus ?? (status == .accepted ? .confirmed : .confirmed)
    }

    /// Descrizione dell'impegno ancora aperto con questa persona, se c'è.
    /// Serve ad avvisare prima di gesti che tagliano i ponti (blocco,
    /// cancellazione della chat): "prima di bloccare, sappi che...".
    /// Vive qui e non nella schermata perché è una regola dell'accordo,
    /// non un dettaglio della chat.
    var pendingAgreementWarning: String? {
        guard status == .accepted,
              effectiveBooking == .confirmed,
              !isEventPast else { return nil }
        if let date = eventDateDisplay {
            return "avete un evento concordato il \(date) per \(currentPriceDisplay)"
        }
        return "avete un accordo chiuso per \(currentPriceDisplay), con data ancora da fissare"
    }

    /// True se l'evento ha una data già passata.
    var isEventPast: Bool {
        guard let eventDate, !eventDate.isEmpty else { return false }
        return BrindooFormat.isPastDay(eventDate)
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

// MARK: - Come si paga

/// Modo di pagamento concordato fra le parti. I soldi non passano dentro
/// Brindoo: l'app registra solo l'accordo e la conferma di chi riceve.
enum PaymentMethod: String, Codable, CaseIterable, Identifiable, Hashable {
    case cash      // contanti, di persona
    case transfer  // bonifico o altro mezzo tracciabile
    case other     // da concordare

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cash:     return "Contanti"
        case .transfer: return "Bonifico o pagamento tracciato"
        case .other:    return "Da concordare"
        }
    }

    var shortLabel: String {
        switch self {
        case .cash:     return "Contanti"
        case .transfer: return "Bonifico"
        case .other:    return "Da concordare"
        }
    }

    var icon: String {
        switch self {
        case .cash:     return "banknote"
        case .transfer: return "building.columns"
        case .other:    return "questionmark.circle"
        }
    }

    /// Nota mostrata sotto la scelta: dice chiaro cosa comporta.
    var hint: String {
        switch self {
        case .cash:
            return "Si paga di persona. Chi riceve lo dichiara nell'app e l'altra parte conferma: resta traccia della data."
        case .transfer:
            return "Si paga con bonifico o altro mezzo tracciabile, direttamente fra voi. Brindoo non incassa nulla."
        case .other:
            return "Deciderete i dettagli in chat. Potrete indicare il modo scelto anche più avanti."
        }
    }
}
