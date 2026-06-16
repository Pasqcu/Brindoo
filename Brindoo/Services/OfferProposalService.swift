//
//  OfferProposalService.swift
//  Brindoo
//
//  Service per il flusso di trattativa sulle offerte di servizio:
//  - cliente propone (al prezzo dell'organizzatore o con controproposta)
//  - organizzatore accetta / rifiuta / contropropone
//  - cliente accetta controproposta / rifiuta / contropropone di nuovo / ritira
//

import Foundation
import Supabase

@MainActor
final class OfferProposalService {

    static let shared = OfferProposalService()
    private init() {}

    private var client: SupabaseClient {
        SupabaseManager.shared.client
    }

    // MARK: - Trattativa attiva per un'offerta (lato cliente corrente)

    /// La trattativa attiva del cliente corrente su una specifica offerta (se esiste).
    /// "Attiva" = non `withdrawn` e non `rejected`.
    func fetchMyActiveProposal(forOffer offerId: UUID) async throws -> OfferProposal? {
        guard let userId = SupabaseManager.shared.currentUserID else { return nil }
        let rows: [OfferProposal] = try await client
            .from("offer_proposals")
            .select()
            .eq("offer_id", value: offerId)
            .eq("client_id", value: userId)
            .in("status", values: [OfferProposalStatus.pending.rawValue,
                                   OfferProposalStatus.accepted.rawValue])
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    // MARK: - Trattative ricevute da un'offerta (lato organizzatore proprietario)

    /// Tutte le trattative su una specifica offerta — visibile all'organizzatore
    /// proprietario (le policy RLS filtrano comunque).
    func fetchProposals(forOffer offerId: UUID) async throws -> [OfferProposal] {
        try await client
            .from("offer_proposals")
            .select()
            .eq("offer_id", value: offerId)
            .order("updated_at", ascending: false)
            .execute()
            .value
    }

    // MARK: - Hub "Trattative attive" (cliente + organizzatore)

    /// Tutte le trattative pendenti o accettate in cui l'utente corrente è coinvolto.
    func fetchMyOngoingProposals() async throws -> [OfferProposal] {
        guard let userId = SupabaseManager.shared.currentUserID else { return [] }
        return try await client
            .from("offer_proposals")
            .select()
            .or("client_id.eq.\(userId.uuidString),organizer_id.eq.\(userId.uuidString)")
            .in("status", values: [OfferProposalStatus.pending.rawValue,
                                   OfferProposalStatus.accepted.rawValue])
            .order("updated_at", ascending: false)
            .execute()
            .value
    }

    // MARK: - Round (cronologia)

    /// Ultimo round della trattativa (per UI "ultima controproposta").
    func fetchLastRound(proposalId: UUID) async throws -> OfferProposalRound? {
        let rows: [OfferProposalRound] = try await client
            .from("offer_proposal_rounds")
            .select()
            .eq("proposal_id", value: proposalId)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    // MARK: - Apertura trattativa (cliente)

    /// Apre una nuova trattativa sull'offerta. Crea anche il round iniziale.
    @discardableResult
    func openProposal(
        offer: ServiceOffer,
        price: Double,
        message: String?,
        eventDate: String? = nil
    ) async throws -> OfferProposal {
        guard let userId = SupabaseManager.shared.currentUserID else {
            throw NSError(domain: "OfferProposal", code: 401)
        }

        // Prima verifica che non ce ne sia già una attiva.
        if let existing = try await fetchMyActiveProposal(forOffer: offer.id) {
            return existing
        }

        struct Payload: Encodable {
            let offer_id: UUID
            let client_id: UUID
            let organizer_id: UUID
            let current_price: Double
            let last_proposer: String
            let last_message: String?
            let status: String
            let event_date: String?
        }

        let payload = Payload(
            offer_id: offer.id,
            client_id: userId,
            organizer_id: offer.organizerId,
            current_price: price,
            last_proposer: ProposerRole.client.rawValue,
            last_message: message,
            status: OfferProposalStatus.pending.rawValue,
            event_date: eventDate
        )

        let created: OfferProposal = try await client
            .from("offer_proposals")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        try await insertRound(
            proposalId: created.id,
            role: .client,
            price: price,
            message: message
        )

        // Push all'organizzatore
        Task {
            let me = try? await ProfileService.shared.fetchProfile(userID: userId)
            await PushOutboxService.shared.notifyNewProposal(
                to: offer.organizerId,
                clientName: me?.fullName ?? "Un cliente",
                offerTitle: offer.title,
                offerId: offer.id
            )
        }

        // Live Activity sul Lock Screen / Dynamic Island
        Task { @MainActor in
            let organizer = try? await ProfileService.shared.fetchProfile(userID: offer.organizerId)
            await LiveActivityManager.shared.startOrUpdateNegotiation(
                proposalId: created.id,
                offerTitle: offer.title,
                counterpartyName: organizer?.fullName ?? "Organizzatore",
                viewerRole: .client,
                currentPrice: Int(price),
                lastProposer: .client,
                status: .pending
            )
        }

        return created
    }

    // MARK: - Controproposta

    /// L'utente corrente fa una controproposta sulla trattativa.
    /// Il `role` deve combaciare con l'utente corrente (la policy lo verifica).
    func counterProposal(
        proposal: OfferProposal,
        role: ProposerRole,
        price: Double,
        message: String?
    ) async throws {
        struct U: Encodable {
            let current_price: Double
            let last_proposer: String
            let last_message: String?
            let status: String
        }

        let payload = U(
            current_price: price,
            last_proposer: role.rawValue,
            last_message: message,
            status: OfferProposalStatus.pending.rawValue
        )

        try await client
            .from("offer_proposals")
            .update(payload)
            .eq("id", value: proposal.id)
            .execute()

        try await insertRound(
            proposalId: proposal.id,
            role: role,
            price: price,
            message: message
        )

        // Push alla controparte
        Task {
            var meName: String? = nil
            if let userId = SupabaseManager.shared.currentUserID,
               let me = try? await ProfileService.shared.fetchProfile(userID: userId) {
                meName = me.fullName
            }
            let recipientId: UUID = (role == .client) ? proposal.organizerId : proposal.clientId
            let offerTitle: String = (try? await ServiceOfferService.shared.fetchOffer(id: proposal.offerId))?.title ?? "Offerta"
            await PushOutboxService.shared.notifyProposalCounter(
                to: recipientId,
                fromName: meName ?? "Utente",
                offerTitle: offerTitle,
                offerId: proposal.offerId
            )

            // Aggiorna la Live Activity con il nuovo prezzo e l'autore della proposta
            let offerTitleResolved: String = (try? await ServiceOfferService.shared.fetchOffer(id: proposal.offerId))?.title ?? "Offerta"
            await LiveActivityManager.shared.startOrUpdateNegotiation(
                proposalId: proposal.id,
                offerTitle: offerTitleResolved,
                counterpartyName: (role == .client ? "Organizzatore" : "Cliente"),
                viewerRole: (role == .client ? .client : .organizer),
                currentPrice: Int(price),
                lastProposer: (role == .client ? .client : .organizer),
                status: .pending
            )
        }
    }

    // MARK: - Accetta / Rifiuta / Ritira

    /// Accetta la trattativa al prezzo corrente. Crea conversation per la chat.
    @discardableResult
    func accept(proposal: OfferProposal) async throws -> Conversation? {
        try await updateStatus(proposalId: proposal.id, status: .accepted)

        // Notifica la controparte
        Task {
            let userId = SupabaseManager.shared.currentUserID
            let recipientId: UUID = (userId == proposal.clientId) ? proposal.organizerId : proposal.clientId
            let offerTitle: String = (try? await ServiceOfferService.shared.fetchOffer(id: proposal.offerId))?.title ?? "Offerta"
            await PushOutboxService.shared.notifyProposalAccepted(
                to: recipientId,
                offerTitle: offerTitle,
                offerId: proposal.offerId
            )
        }

        await LiveActivityManager.shared.endNegotiation(
            proposalId: proposal.id,
            finalStatus: .accepted,
            currentPrice: Int(proposal.currentPrice),
            lastProposer: proposal.lastProposer == .client ? .client : .organizer
        )

        // Crea/recupera la conversation tra cliente e organizzatore.
        guard let userId = SupabaseManager.shared.currentUserID else { return nil }
        if userId == proposal.clientId {
            return try? await ConversationService.shared
                .findOrCreateConversationAsClient(organizerId: proposal.organizerId)
        } else if userId == proposal.organizerId {
            return try? await ConversationService.shared
                .findOrCreateConversationAsOrganizer(clientId: proposal.clientId)
        }
        return nil
    }

    func reject(proposal: OfferProposal) async throws {
        try await updateStatus(proposalId: proposal.id, status: .rejected)
        await LiveActivityManager.shared.endNegotiation(
            proposalId: proposal.id,
            finalStatus: .rejected,
            currentPrice: Int(proposal.currentPrice),
            lastProposer: proposal.lastProposer == .client ? .client : .organizer
        )
    }

    /// Solo il cliente può ritirare la sua trattativa.
    func withdraw(proposal: OfferProposal) async throws {
        try await updateStatus(proposalId: proposal.id, status: .withdrawn)
        await LiveActivityManager.shared.endNegotiation(
            proposalId: proposal.id,
            finalStatus: .withdrawn,
            currentPrice: Int(proposal.currentPrice),
            lastProposer: proposal.lastProposer == .client ? .client : .organizer
        )
    }

    private func updateStatus(proposalId: UUID, status: OfferProposalStatus) async throws {
        struct U: Encodable { let status: String }
        try await client
            .from("offer_proposals")
            .update(U(status: status.rawValue))
            .eq("id", value: proposalId)
            .execute()
    }

    private func insertRound(
        proposalId: UUID,
        role: ProposerRole,
        price: Double,
        message: String?
    ) async throws {
        struct Row: Encodable {
            let proposal_id: UUID
            let proposer_role: String
            let price: Double
            let message: String?
        }
        let row = Row(
            proposal_id: proposalId,
            proposer_role: role.rawValue,
            price: price,
            message: message
        )
        try await client
            .from("offer_proposal_rounds")
            .insert(row)
            .execute()
    }
}
