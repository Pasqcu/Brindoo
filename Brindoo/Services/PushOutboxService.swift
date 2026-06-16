//
//  PushOutboxService.swift
//  Brindoo
//
//  Inserisce notifiche nella tabella `notifications_outbox` di Supabase.
//  La Edge Function `send-push-notifications` (schedulata via pg_cron)
//  legge l'outbox e invia gli APNs.
//
//  Tipi di evento principali:
//   - newProposal          (client → organizer dell'offerta)
//   - proposalCounter      (client/organizer → controparte)
//   - proposalAccepted     (controparte → l'altro)
//   - newMessage           (qualsiasi → controparte)
//

import Foundation
import Supabase

@MainActor
final class PushOutboxService {

    static let shared = PushOutboxService()
    private init() {}

    private var client: SupabaseClient {
        SupabaseManager.shared.client
    }

    /// Inserisce una riga nell'outbox. Best-effort: se fallisce non blocca l'azione.
    func enqueue(
        recipientId: UUID,
        title: String,
        body: String,
        payload: [String: String]? = nil
    ) async {
        // Non spedire push a se stessi.
        if recipientId == SupabaseManager.shared.currentUserID { return }

        struct Row: Encodable {
            let recipient_id: UUID
            let title: String
            let body: String
            let payload: [String: String]?
        }

        do {
            try await client
                .from("notifications_outbox")
                .insert(Row(
                    recipient_id: recipientId,
                    title: title,
                    body: body,
                    payload: payload
                ))
                .execute()
        } catch {
            // Tracciato ma non rilanciato — il flusso utente deve continuare.
            print("⚠️ Push outbox: \(error)")
        }
    }

    // MARK: - Helpers tipizzati

    func notifyNewProposal(to organizerId: UUID, clientName: String, offerTitle: String, offerId: UUID) async {
        await enqueue(
            recipientId: organizerId,
            title: "Nuova proposta su \(offerTitle)",
            body: "\(clientName) ha inviato una proposta",
            payload: ["type": "new_proposal", "offer_id": offerId.uuidString]
        )
    }

    func notifyProposalCounter(to recipientId: UUID, fromName: String, offerTitle: String, offerId: UUID) async {
        await enqueue(
            recipientId: recipientId,
            title: "Controproposta da \(fromName)",
            body: "Nuova controproposta su \"\(offerTitle)\"",
            payload: ["type": "proposal_counter", "offer_id": offerId.uuidString]
        )
    }

    func notifyProposalAccepted(to recipientId: UUID, offerTitle: String, offerId: UUID) async {
        await enqueue(
            recipientId: recipientId,
            title: "Proposta accettata 🎉",
            body: "La trattativa su \"\(offerTitle)\" è andata in porto",
            payload: ["type": "proposal_accepted", "offer_id": offerId.uuidString]
        )
    }
}
