//
//  CalendarService.swift
//  Brindoo
//
//  Aggiunge gli eventi confermati al calendario dell'iPhone
//  (accesso in sola scrittura: non leggiamo nulla dal calendario).
//

import Foundation
import EventKit

enum CalendarServiceError: LocalizedError {
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Consenti l'accesso al calendario dalle Impostazioni di iOS."
        }
    }
}

@MainActor
enum CalendarService {

    private static let dayParser: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    /// Crea un evento "tutto il giorno" nel calendario di default,
    /// con promemoria il giorno prima alle 9. `dayString` in "yyyy-MM-dd".
    static func addAllDayEvent(title: String, dayString: String, notes: String? = nil) async throws {
        guard let utcDay = dayParser.date(from: dayString) else {
            throw NSError(domain: "CalendarService", code: 400,
                          userInfo: [NSLocalizedDescriptionKey: "Data non valida"])
        }

        let store = EKEventStore()
        let granted = (try? await store.requestWriteOnlyAccessToEvents()) ?? false
        guard granted else { throw CalendarServiceError.accessDenied }

        // Trasforma il giorno UTC nel giorno "locale" corrispondente.
        var comps = Calendar.current.dateComponents(in: TimeZone(identifier: "UTC")!, from: utcDay)
        comps.timeZone = TimeZone.current
        let localDay = Calendar.current.date(from: DateComponents(
            year: comps.year, month: comps.month, day: comps.day
        )) ?? utcDay

        let event = EKEvent(eventStore: store)
        event.calendar = store.defaultCalendarForNewEvents
        event.title = title
        event.notes = notes
        event.isAllDay = true
        event.startDate = localDay
        event.endDate = localDay
        // Avviso il giorno prima alle 9 (evento tutto-il-giorno parte a mezzanotte).
        event.addAlarm(EKAlarm(relativeOffset: -15 * 60 * 60))

        try store.save(event, span: .thisEvent)
    }
}
