//
//  LiveActivityManager.swift
//  Brindoo
//
//  Helper singleton per gestire il ciclo di vita delle Live Activity di
//  Brindoo (start / update / end). Tutti i metodi sono no-op su iOS < 16.2
//  o quando le Live Activity sono disattivate dall'utente in Impostazioni.
//
//  Le Live Activity vengono aggiornate quando lo stato della trattativa cambia
//  (nuova proposta, controproposta, accettata, rifiutata, ritirata).
//

import Foundation
import ActivityKit

@MainActor
final class LiveActivityManager {

    static let shared = LiveActivityManager()
    private init() {}

    // MARK: - Public API

    /// Avvia una nuova Live Activity per una trattativa. Se già esiste un'attività
    /// per lo stesso `proposalId`, viene aggiornata invece di crearne una nuova.
    func startOrUpdateNegotiation(
        proposalId: UUID,
        offerTitle: String,
        counterpartyName: String,
        viewerRole: NegotiationActivityAttributes.ContentState.Proposer,
        currentPrice: Int,
        lastProposer: NegotiationActivityAttributes.ContentState.Proposer,
        status: NegotiationActivityAttributes.ContentState.NegotiationStatus
    ) async {
        guard #available(iOS 16.2, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = NegotiationActivityAttributes(
            proposalId: proposalId.uuidString,
            offerTitle: offerTitle,
            counterpartyName: counterpartyName,
            viewerRole: viewerRole
        )
        let state = NegotiationActivityAttributes.ContentState(
            currentPrice: currentPrice,
            lastProposer: lastProposer,
            status: status
        )

        // Se esiste già un'attività per questo proposalId, aggiornala.
        if let existing = Activity<NegotiationActivityAttributes>.activities
            .first(where: { $0.attributes.proposalId == proposalId.uuidString })
        {
            let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(60 * 60))
            await existing.update(content)
            return
        }

        do {
            let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(60 * 60))
            _ = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil // server-side push: aggiungere quando avremo l'edge function
            )
        } catch {
            BrindooLog.error("LiveActivity start failed: \(error)")
        }
    }

    /// Termina l'attività relativa a una trattativa (es. accettata o rifiutata).
    func endNegotiation(proposalId: UUID, finalStatus: NegotiationActivityAttributes.ContentState.NegotiationStatus, currentPrice: Int, lastProposer: NegotiationActivityAttributes.ContentState.Proposer) async {
        guard #available(iOS 16.2, *) else { return }

        guard let activity = Activity<NegotiationActivityAttributes>.activities
            .first(where: { $0.attributes.proposalId == proposalId.uuidString })
        else { return }

        let finalState = NegotiationActivityAttributes.ContentState(
            currentPrice: currentPrice,
            lastProposer: lastProposer,
            status: finalStatus
        )
        let content = ActivityContent(state: finalState, staleDate: nil)
        // L'attività resta visibile in Dynamic Island/Lock Screen ancora qualche
        // minuto dopo la fine — poi viene rimossa dal sistema.
        await activity.end(content, dismissalPolicy: .after(Date().addingTimeInterval(60 * 5)))
    }

    /// Termina tutte le Live Activity attive (es. al logout).
    func endAll() async {
        guard #available(iOS 16.2, *) else { return }
        for activity in Activity<NegotiationActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
