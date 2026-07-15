//
//  OfferPackage.swift
//  Brindoo
//
//  Pacchetto prezzo di un'offerta (es. Base / Completo / Premium).
//  Fino a 3 per offerta; il cliente può accettare direttamente il
//  prezzo del pacchetto che preferisce.
//

import Foundation

struct OfferPackage: Identifiable, Codable, Hashable, Equatable {
    let id: UUID
    let offerId: UUID
    let name: String
    let description: String?
    let price: Double
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id
        case offerId = "offer_id"
        case name
        case description
        case price
        case sortOrder = "sort_order"
    }

    /// "350 €" — prezzo leggibile.
    var priceDisplay: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "it_IT")
        f.maximumFractionDigits = price.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
        return f.string(from: NSNumber(value: price)) ?? "\(Int(price)) €"
    }
}
