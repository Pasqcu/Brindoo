//
//  LazioArea.swift
//  Brindoo
//
//  Lista canonica delle "aree di copertura" disponibili nel Lazio.
//  Mix di quartieri romani (allineati con `RomeZone`) e principali comuni del Lazio.
//  Lo `slug` è il valore stored nei campi DB `profiles.coverage_areas`.
//

import Foundation

struct LazioArea: Identifiable, Hashable, Equatable, Codable {
    /// Sigla provincia laziale a cui appartiene l'area.
    let province: LazioProvince
    /// Slug unico, salvato nel DB.
    let slug: String
    /// Etichetta visualizzata in UI.
    let name: String
    /// True se l'area è "intera provincia" (cattura tutta la provincia).
    let isWholeProvince: Bool

    var id: String { slug }
}

extension LazioArea {

    /// Quartieri di Roma — corrispondenti a `RomeZone.allCases`.
    /// Lo slug è preceduto da `roma_` per essere distinguibile dalle aree extra-Roma.
    static let romeNeighborhoods: [LazioArea] = RomeZone.allCases.map { zone in
        LazioArea(
            province: .roma,
            slug: "roma_\(zone.slug)",
            name: zone.name,
            isWholeProvince: false
        )
    }

    /// Principali comuni del Lazio (non quartieri di Roma).
    static let majorMunicipalities: [LazioArea] = [
        // Provincia di Roma (escluso il comune di Roma, già coperto dai quartieri)
        .init(province: .roma, slug: "tivoli",         name: "Tivoli",         isWholeProvince: false),
        .init(province: .roma, slug: "frascati",       name: "Frascati",       isWholeProvince: false),
        .init(province: .roma, slug: "anzio",          name: "Anzio",          isWholeProvince: false),
        .init(province: .roma, slug: "pomezia",        name: "Pomezia",        isWholeProvince: false),
        .init(province: .roma, slug: "velletri",       name: "Velletri",       isWholeProvince: false),
        .init(province: .roma, slug: "civitavecchia",  name: "Civitavecchia",  isWholeProvince: false),
        .init(province: .roma, slug: "albano_laziale", name: "Albano Laziale", isWholeProvince: false),
        .init(province: .roma, slug: "ladispoli",      name: "Ladispoli",      isWholeProvince: false),
        .init(province: .roma, slug: "guidonia",       name: "Guidonia",       isWholeProvince: false),
        .init(province: .roma, slug: "fiumicino",      name: "Fiumicino",      isWholeProvince: false),

        // Provincia di Latina
        .init(province: .latina, slug: "latina",       name: "Latina",         isWholeProvince: false),
        .init(province: .latina, slug: "aprilia",      name: "Aprilia",        isWholeProvince: false),
        .init(province: .latina, slug: "cisterna",     name: "Cisterna",       isWholeProvince: false),
        .init(province: .latina, slug: "terracina",    name: "Terracina",      isWholeProvince: false),
        .init(province: .latina, slug: "fondi",        name: "Fondi",          isWholeProvince: false),
        .init(province: .latina, slug: "sabaudia",     name: "Sabaudia",       isWholeProvince: false),
        .init(province: .latina, slug: "formia",       name: "Formia",         isWholeProvince: false),
        .init(province: .latina, slug: "gaeta",        name: "Gaeta",          isWholeProvince: false),

        // Provincia di Frosinone
        .init(province: .frosinone, slug: "frosinone", name: "Frosinone",      isWholeProvince: false),
        .init(province: .frosinone, slug: "cassino",   name: "Cassino",        isWholeProvince: false),
        .init(province: .frosinone, slug: "anagni",    name: "Anagni",         isWholeProvince: false),
        .init(province: .frosinone, slug: "sora",      name: "Sora",           isWholeProvince: false),
        .init(province: .frosinone, slug: "veroli",    name: "Veroli",         isWholeProvince: false),
        .init(province: .frosinone, slug: "ferentino", name: "Ferentino",      isWholeProvince: false),
        .init(province: .frosinone, slug: "alatri",    name: "Alatri",         isWholeProvince: false),

        // Provincia di Rieti
        .init(province: .rieti, slug: "rieti",         name: "Rieti",          isWholeProvince: false),
        .init(province: .rieti, slug: "poggio_mirteto", name: "Poggio Mirteto", isWholeProvince: false),
        .init(province: .rieti, slug: "fara_sabina",   name: "Fara in Sabina", isWholeProvince: false),

        // Provincia di Viterbo
        .init(province: .viterbo, slug: "viterbo",     name: "Viterbo",        isWholeProvince: false),
        .init(province: .viterbo, slug: "civita_castellana", name: "Civita Castellana", isWholeProvince: false),
        .init(province: .viterbo, slug: "tarquinia",   name: "Tarquinia",      isWholeProvince: false),
        .init(province: .viterbo, slug: "vetralla",    name: "Vetralla",       isWholeProvince: false)
    ]

    /// "Tutta la provincia X" — utile per chi opera ovunque in una specifica provincia.
    static let wholeProvinces: [LazioArea] = LazioProvince.allCases.map { p in
        LazioArea(
            province: p,
            slug: "prov_\(p.rawValue.lowercased())",
            name: "Tutta la provincia di \(p.displayName)",
            isWholeProvince: true
        )
    }

    /// Lista canonica completa. Ordine usato anche dalla UI: prima le provincie
    /// intere, poi i quartieri di Roma, poi gli altri comuni.
    static let allCases: [LazioArea] =
        wholeProvinces + romeNeighborhoods + majorMunicipalities

    /// Lookup by slug.
    static func area(forSlug slug: String) -> LazioArea? {
        allCases.first { $0.slug == slug }
    }

    /// Aree raggruppate per provincia, comodo per la UI a sezioni.
    static var groupedByProvince: [LazioProvince: [LazioArea]] {
        Dictionary(grouping: allCases, by: { $0.province })
    }

    /// Etichetta human-readable per una lista di slug.
    static func displayLabel(forSlugs slugs: [String]) -> String {
        guard !slugs.isEmpty else { return "Tutto il Lazio" }
        let names = slugs.compactMap { area(forSlug: $0)?.name }
        switch names.count {
        case 0:  return "Tutto il Lazio"
        case 1:  return names[0]
        case 2:  return names.joined(separator: " · ")
        default: return "\(names[0]) +\(names.count - 1)"
        }
    }
}
