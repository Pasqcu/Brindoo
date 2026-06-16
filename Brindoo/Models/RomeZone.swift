//
//  RomeZone.swift
//  Brindoo
//
//  Macro-zone geografiche di Roma usate per filtrare offerte/professionisti.
//  Le offerte memorizzano un array di slug (`service_offers.zones`).
//

import Foundation

struct RomeZone: Identifiable, Hashable, Equatable, Codable {
    /// Slug usato come valore stored nel DB (snake_case, senza accenti).
    let slug: String
    let name: String

    var id: String { slug }
}

extension RomeZone {

    /// Lista canonica delle macro-zone romane. L'ordine è quello visualizzato in UI.
    static let allCases: [RomeZone] = [
        .init(slug: "centro_storico",        name: "Centro Storico"),
        .init(slug: "prati_flaminio",        name: "Prati / Flaminio"),
        .init(slug: "parioli_salario",       name: "Parioli / Salario"),
        .init(slug: "nomentano_san_lorenzo", name: "Nomentano / San Lorenzo"),
        .init(slug: "tiburtino_pigneto",     name: "Tiburtino / Pigneto"),
        .init(slug: "san_giovanni_tuscolano", name: "San Giovanni / Tuscolano"),
        .init(slug: "eur_ostiense",          name: "EUR / Ostiense"),
        .init(slug: "trastevere_gianicolense", name: "Trastevere / Gianicolense"),
        .init(slug: "aurelio_monte_mario",   name: "Aurelio / Monte Mario"),
        .init(slug: "trionfale_cassia",      name: "Trionfale / Cassia"),
        .init(slug: "ostia_litorale",        name: "Ostia / Litorale"),
        .init(slug: "provincia_roma",        name: "Provincia di Roma")
    ]

    /// Lookup per slug.
    static func zone(forSlug slug: String) -> RomeZone? {
        allCases.first { $0.slug == slug }
    }

    /// Etichetta human-readable per una lista di slug, gestendo i casi limite.
    static func displayLabel(forSlugs slugs: [String]) -> String {
        guard !slugs.isEmpty else { return "Tutta Roma" }
        let names = slugs.compactMap { zone(forSlug: $0)?.name }
        switch names.count {
        case 0:  return "Tutta Roma"
        case 1:  return names[0]
        case 2:  return names.joined(separator: " · ")
        default: return "\(names[0]) +\(names.count - 1)"
        }
    }
}
