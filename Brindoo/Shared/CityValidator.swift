//
//  CityValidator.swift
//  Brindoo
//
//  Modelli e validazione per limitare l'app alla regione Lazio.
//  L'utente seleziona una provincia tra le cinque del Lazio e digita
//  liberamente la città. Le zone romane (vedi `RomeZone`) sono disponibili
//  solo se la città è "Roma".
//

import Foundation

/// Province della regione Lazio. Lo `slug` (sigla, due lettere maiuscole) è il
/// valore salvato in `profiles.province`.
enum LazioProvince: String, CaseIterable, Identifiable, Codable {
    case roma = "RM"
    case frosinone = "FR"
    case latina = "LT"
    case rieti = "RI"
    case viterbo = "VT"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .roma:      return "Roma"
        case .frosinone: return "Frosinone"
        case .latina:    return "Latina"
        case .rieti:     return "Rieti"
        case .viterbo:   return "Viterbo"
        }
    }
}

/// Helper di validazione della località dell'utente. Il vincolo è "deve essere
/// nel Lazio", espresso tramite la `LazioProvince`.
enum CityValidator {

    /// Etichetta della regione attualmente supportata.
    static let allowedRegionDisplay = "Lazio"

    /// True se la città digitata coincide con "Roma" (case + accenti insensitive).
    static func isRome(_ city: String) -> Bool {
        canonical(city) == "roma"
    }

    /// Restituisce un messaggio di errore se la combinazione città/provincia
    /// non è valida per la regione Lazio. `nil` se tutto OK.
    /// - Parameters:
    ///   - city: testo libero inserito dall'utente
    ///   - province: provincia laziale selezionata (può essere nil → errore)
    static func validate(city: String, province: LazioProvince?) -> String? {
        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCity.isEmpty else {
            return "Inserisci la tua città"
        }
        guard let province else {
            return "Seleziona la tua provincia"
        }

        // Coerenza fra città == Roma e provincia == Roma (RM).
        if isRome(trimmedCity) && province != .roma {
            return "Roma appartiene alla provincia di Roma (RM)"
        }
        if !isRome(trimmedCity) && province == .roma {
            // Permettiamo paesi della provincia di Roma diversi da Roma stessa
            // (es. Tivoli, Frascati, Anzio…). Nessun errore qui.
        }
        return nil
    }

    /// Versione normalizzata della città per il salvataggio. Per ora solo
    /// rifiniamo "roma" → "Roma".
    static func normalizedCity(_ city: String) -> String {
        let trimmed = city.trimmingCharacters(in: .whitespacesAndNewlines)
        return isRome(trimmed) ? "Roma" : trimmed
    }

    private static func canonical(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
    }
}
