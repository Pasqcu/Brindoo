//
//  BrindooFormat.swift
//  Brindoo
//
//  Formattatori condivisi (prezzo in euro, giorni "yyyy-MM-dd", date
//  leggibili in italiano). Un punto unico al posto delle copie sparse:
//  meno codice, stessi risultati ovunque, formattatori riusati (creare
//  un formatter è costoso, qui vengono creati una volta sola).
//

import Foundation

enum BrindooFormat {

    // MARK: - Prezzo

    private static let euroFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "it_IT")
        return f
    }()

    /// "450 €" all'italiana; i decimali compaiono solo se servono ("450,50 €").
    static func euro(_ value: Double) -> String {
        euroFormatter.maximumFractionDigits =
            value.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2
        return euroFormatter.string(from: NSNumber(value: value)) ?? "\(Int(value)) €"
    }

    // MARK: - Giorno "yyyy-MM-dd" (formato usato dal database)

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    /// "2026-09-12" → Date (nil se il formato non è valido).
    static func day(from string: String) -> Date? {
        dayFormatter.date(from: string)
    }

    /// Date → "2026-09-12".
    static func dayString(from date: Date) -> String {
        dayFormatter.string(from: date)
    }

    // MARK: - Data leggibile in italiano

    private static let italianDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "d MMMM yyyy"
        return f
    }()

    /// "2026-09-12" → "12 settembre 2026" (nil se il formato non è valido).
    static func italianDate(fromDay string: String) -> String? {
        day(from: string).map { italianDateFormatter.string(from: $0) }
    }

    // MARK: - Tempo relativo

    private static let relativeAbbrev: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.unitsStyle = .abbreviated
        return f
    }()

    private static let relativeFull: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.unitsStyle = .full
        return f
    }()

    /// "2 g fa" — forma breve per card e righe compatte.
    static func timeAgoShort(_ date: Date) -> String {
        relativeAbbrev.localizedString(for: date, relativeTo: Date())
    }

    /// "2 giorni fa" — forma estesa.
    static func timeAgo(_ date: Date) -> String {
        relativeFull.localizedString(for: date, relativeTo: Date())
    }
}
