//
//  BrindooLimitError.swift
//  Brindoo
//
//  Errori "limite raggiunto" che le view intercettano per mostrare la paywall.
//

import Foundation

enum BrindooLimitError: LocalizedError {
    case maxOffersReached
    case maxPortfolioReached(max: Int)
    case maxClientRequestsReached(max: Int)

    var errorDescription: String? {
        switch self {
        case .maxOffersReached:
            return "Con il piano gratuito puoi avere 1 offerta attiva. Passa a Brindoo Pro per offerte illimitate."
        case .maxPortfolioReached(let max):
            return "Il piano gratuito permette \(max) foto nel portfolio. Passa a Brindoo Pro per fino a 50 foto."
        case .maxClientRequestsReached(let max):
            return "Con il piano gratuito puoi tenere aperte \(max) richieste. Chiudine una, oppure passa a Brindoo Pro per averne quante vuoi."
        }
    }
}

extension BrindooLimitError {

    /// Traduce il rifiuto che arriva dal database.
    ///
    /// Gli stessi tetti vivono anche nei trigger Postgres, che sollevano un
    /// errore `42501` con il testo del limite. Senza questa traduzione l'utente
    /// vedrebbe "riprova più tardi" davanti a un muro definitivo, oppure —
    /// riaprendo una richiesta — nessun messaggio.
    static func fromServer(_ error: Error) -> BrindooLimitError? {
        let text = "\(error)".lowercased()
        guard text.contains("piano gratuito") else { return nil }
        if text.contains("offerta attiva") { return .maxOffersReached }
        if text.contains("richieste aperte") {
            return .maxClientRequestsReached(max: ClientRequestService.maxOpenRequestsFree)
        }
        if text.contains("foto") { return .maxPortfolioReached(max: PortfolioService.maxPhotosFree) }
        return nil
    }

    /// Rilancia l'errore originale, ma se è un limite del database lo rende
    /// riconoscibile alle view.
    static func mapping(_ error: Error) -> Error {
        fromServer(error) ?? error
    }
}
