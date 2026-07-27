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

    /// Crea un evento "tutto il giorno" nel calendario di default,
    /// con promemoria il giorno prima alle 9. `dayString` in "yyyy-MM-dd".
    static func addAllDayEvent(title: String, dayString: String, notes: String? = nil) async throws {
        guard let eventDay = BrindooFormat.day(from: dayString) else {
            throw BrindooServiceError.invalidInput("Data non valida")
        }

        let store = EKEventStore()
        let granted = (try? await store.requestWriteOnlyAccessToEvents()) ?? false
        guard granted else { throw CalendarServiceError.accessDenied }

        // Stesso giorno del calendario, ma a mezzanotte locale: è così che
        // iOS si aspetta un evento "tutto il giorno".
        let comps = BrindooFormat.dayCalendar.dateComponents([.year, .month, .day], from: eventDay)
        let localDay = Calendar.current.date(from: DateComponents(
            year: comps.year, month: comps.month, day: comps.day
        )) ?? eventDay

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
