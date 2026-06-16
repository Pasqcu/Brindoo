//
//  NegotiationActivityAttributes.swift
//  Brindoo
//
//  Schema dati della Live Activity per le trattative attive su offerte.
//  - `Attributes` = dati IMMUTABILI per l'intera vita dell'attività (es. titolo offerta).
//  - `ContentState` = dati che si aggiornano nel tempo (prezzo corrente, stato, ecc.).
//
//  Questo file fa parte del target principale Brindoo.
//  Quando creerai il Widget Extension target, aggiungi anche questo file al
//  membership del target widget (Target Membership in Xcode Inspector).
//

import Foundation
import ActivityKit

struct NegotiationActivityAttributes: ActivityAttributes {

    public struct ContentState: Codable, Hashable {
        /// Prezzo corrente della trattativa, in euro.
        var currentPrice: Int
        /// Chi ha fatto l'ultima proposta.
        var lastProposer: Proposer
        /// Stato della trattativa.
        var status: NegotiationStatus

        public enum Proposer: String, Codable, Hashable {
            case client
            case organizer
        }

        public enum NegotiationStatus: String, Codable, Hashable {
            case pending
            case accepted
            case rejected
            case withdrawn
        }
    }

    /// Identificativo della trattativa (UUID stringato), utile per fare
    /// match lato server quando arrivano push update.
    var proposalId: String

    /// Titolo dell'offerta in trattativa (es. "Pacchetto matrimonio").
    var offerTitle: String

    /// Nome della controparte (es. "Mario Rossi").
    var counterpartyName: String

    /// Ruolo dell'utente corrente: serve solo per scegliere copy in Widget.
    var viewerRole: ContentState.Proposer
}
