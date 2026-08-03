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

    /// Giorni (mezzanotte Roma) con almeno un impegno nel calendario iOS,
    /// da oggi ai prossimi `monthsAhead` mesi. Serve al professionista per
    /// importare in un tocco i giorni già occupati fuori da Brindoo.
    /// La lettura resta sul telefono: nulla del calendario esce dall'app.
    static func fetchDeviceBusyDays(monthsAhead: Int = 6) async throws -> Set<Date> {
        let store = EKEventStore()
        let granted = (try? await store.requestFullAccessToEvents()) ?? false
        guard granted else { throw CalendarServiceError.accessDenied }

        let cal = BrindooFormat.dayCalendar
        let start = BrindooFormat.startOfDay()
        guard let end = cal.date(byAdding: .month, value: monthsAhead, to: start) else { return [] }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        var days: Set<Date> = []
        for event in store.events(matching: predicate) {
            // Un impegno può coprire più giorni: si segnano tutti.
            var day = cal.startOfDay(for: event.startDate)
            let lastDay = cal.startOfDay(for: event.endDate)
            while day <= lastDay {
                if day >= start { days.insert(day) }
                guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }
        return days
    }
}
