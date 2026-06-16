//
//  LocalReminderService.swift
//  Brindoo
//
//  Promemoria locali (sul dispositivo) per gli eventi concordati nelle trattative.
//  Non richiede backend: usa le notifiche locali di iOS. Programma un avviso
//  il giorno prima dell'evento (alle 10:00).
//

import Foundation
import UserNotifications

@MainActor
enum LocalReminderService {

    /// Programma (o riprogramma) il promemoria per un evento.
    /// `eventDate` nel formato "yyyy-MM-dd". No-op se la data è assente o passata,
    /// o se l'utente non ha concesso il permesso notifiche.
    static func scheduleEventReminder(
        proposalId: UUID,
        eventDate: String?,
        offerTitle: String
    ) async {
        guard let eventDate, !eventDate.isEmpty else { return }

        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.timeZone = TimeZone.current
        guard let day = parser.date(from: eventDate) else { return }

        // Avviso il giorno prima alle 10:00.
        guard let remindDate = Calendar.current.date(byAdding: .day, value: -1, to: day) else { return }
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: remindDate)
        comps.hour = 10
        comps.minute = 0
        guard let fireDate = Calendar.current.date(from: comps), fireDate > Date() else { return }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = "Evento in arrivo 🎉"
        content.body = "Domani: \(offerTitle). Tutto pronto?"
        content.sound = .default

        let triggerComps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComps, repeats: false)
        let request = UNNotificationRequest(
            identifier: "event-reminder-\(proposalId.uuidString)",
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    /// Annulla un eventuale promemoria già programmato.
    static func cancelReminder(proposalId: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["event-reminder-\(proposalId.uuidString)"])
    }
}
