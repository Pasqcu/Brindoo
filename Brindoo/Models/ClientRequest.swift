//
//  ClientRequest.swift
//  Brindoo
//
//  Richiesta pubblicata da un cliente (bacheca inversa):
//  "Cerco fotografo per matrimonio il 20/9 a Latina, budget 800€".
//  I professionisti la sfogliano e contattano il cliente in chat.
//

import Foundation

/// Stato di una richiesta cliente.
enum ClientRequestStatus: String, Codable, CaseIterable {
    case open
    case closed

    var displayName: String {
        switch self {
        case .open:   return "Aperta"
        case .closed: return "Chiusa"
        }
    }
}

struct ClientRequest: Identifiable, Codable, Hashable, Equatable {
    let id: UUID
    let clientId: UUID
    let title: String
    let description: String?
    /// Zona/comune dell'evento (testo libero).
    let area: String
    /// Data dell'evento (facoltativa), formato "yyyy-MM-dd".
    let eventDate: String?
    /// Budget indicativo in euro (facoltativo).
    let budget: Double?
    let categoryId: UUID?
    let status: ClientRequestStatus
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case clientId = "client_id"
        case title
        case description
        case area
        case eventDate = "event_date"
        case budget
        case categoryId = "category_id"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// "20 settembre 2026" — data dell'evento leggibile, se presente.
    var eventDateDisplay: String? {
        guard let eventDate else { return nil }
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.timeZone = TimeZone(identifier: "UTC")
        guard let date = parser.date(from: eventDate) else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "d MMMM yyyy"
        return f.string(from: date)
    }

    /// "800 €" — budget leggibile, se presente.
    var budgetDisplay: String? {
        guard let budget else { return nil }
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "it_IT")
        f.maximumFractionDigits = budget.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
        return f.string(from: NSNumber(value: budget))
    }
}
