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

    var errorDescription: String? {
        switch self {
        case .maxOffersReached:
            return "Con il piano gratuito puoi avere 1 offerta attiva. Passa a Brindoo Pro per offerte illimitate."
        case .maxPortfolioReached(let max):
            return "Il piano gratuito permette \(max) foto nel portfolio. Passa a Brindoo Pro per fino a 50 foto."
        }
    }
}
