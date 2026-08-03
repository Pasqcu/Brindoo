//
//  LocalReminderService.swift
//  Brindoo
//
//  Promemoria locali (sul dispositivo) per gli eventi concordati nelle trattative.
//  Non richiede backend: usa le notifiche locali di iOS. La serie completa:
//  acconto a 30 giorni, controllo dettagli a 7, avviso il giorno prima e
//  invito a recensire il giorno dopo (gli ultimi due lato cliente).
//

import Foundation
import UserNotifications

@MainActor
enum LocalReminderService {

    /// Programma (o riprogramma) la serie di promemoria per un evento.
    /// `eventDate` nel formato "yyyy-MM-dd". No-op se la data è assente,
    /// se l'utente ha spento i promemoria o negato le notifiche; le tappe
    /// già passate si saltano da sole (controllo `fireDate > Date()`).
    static func scheduleEventReminders(
        proposalId: UUID,
        eventDate: String?,
        offerTitle: String,
        offerId: UUID?,
        isClient: Bool
    ) async {
        guard let eventDate, !eventDate.isEmpty else { return }
        // Rispetta la scelta fatta in Impostazioni.
        guard remindersEnabled else { return }
        guard let day = BrindooFormat.day(from: eventDate) else { return }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        // Il tap sul promemoria porta alla trattativa (stessa strada delle push).
        var userInfo: [AnyHashable: Any] = [:]
        if let offerId {
            userInfo = ["type": "new_proposal", "offer_id": offerId.uuidString]
        }

        if isClient {
            // L'acconto lo versa il cliente: inutile ricordarlo all'altro lato.
            await schedule(center, id: "event-deposit-\(proposalId.uuidString)",
                           day: day, daysOffset: -30,
                           title: "Un mese a \(offerTitle)",
                           body: "Se avete concordato un acconto, è il momento buono per versarlo e registrarlo.",
                           userInfo: userInfo)
        }

        await schedule(center, id: "event-checkup-\(proposalId.uuidString)",
                       day: day, daysOffset: -7,
                       title: "Una settimana a \(offerTitle)",
                       body: "Riguarda orari, indirizzo e dettagli in chat: meglio adesso che all'ultimo.",
                       userInfo: userInfo)

        await schedule(center, id: "event-reminder-\(proposalId.uuidString)",
                       day: day, daysOffset: -1,
                       title: "Evento in arrivo 🎉",
                       body: "Domani: \(offerTitle). Tutto pronto?",
                       userInfo: userInfo)

        if isClient {
            await schedule(center, id: "event-review-\(proposalId.uuidString)",
                           day: day, daysOffset: 1,
                           title: "Com'è andata? ⭐️",
                           body: "Racconta com'è andato \(offerTitle): la tua recensione aiuta chi organizza dopo di te.",
                           userInfo: userInfo)
        }
    }

    /// Una tappa della serie, alle 10:00. Il giorno civile si calcola col
    /// calendario degli eventi (Roma), l'orario resta quello del telefono:
    /// l'avviso serve a chi lo riceve.
    private static func schedule(
        _ center: UNUserNotificationCenter,
        id: String,
        day: Date,
        daysOffset: Int,
        title: String,
        body: String,
        userInfo: [AnyHashable: Any]
    ) async {
        guard let target = BrindooFormat.dayCalendar.date(byAdding: .day, value: daysOffset, to: day) else { return }
        var comps = BrindooFormat.dayCalendar.dateComponents([.year, .month, .day], from: target)
        comps.hour = 10
        comps.minute = 0
        guard let fireDate = Calendar.current.date(from: comps), fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if !userInfo.isEmpty { content.userInfo = userInfo }

        let triggerComps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComps, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    /// Tutti i prefissi della serie: servono a cancellare senza sapere
    /// quali tappe erano state programmate davvero.
    private static let reminderPrefixes = [
        "event-reminder-", "event-deposit-", "event-checkup-", "event-review-"
    ]

    /// Annulla l'intera serie di un evento (trattativa annullata o data cambiata).
    static func cancelReminder(proposalId: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: reminderPrefixes.map { $0 + proposalId.uuidString }
        )
    }

    /// L'acconto registrato spegne il suo promemoria: ha già fatto il suo lavoro.
    static func cancelDepositReminder(proposalId: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["event-deposit-\(proposalId.uuidString)"]
        )
    }

    /// Toglie tutti i promemoria eventi già programmati (l'utente li ha spenti).
    static func cancelAllEventReminders() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { id in
            reminderPrefixes.contains { id.hasPrefix($0) }
        }
        guard !ids.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Preferenza locale

    private static let remindersKey = "brindoo.notify.reminders"

    /// Copia locale della preferenza "promemoria eventi": serve qui perché
    /// i promemoria li programma il telefono, non il server.
    static var remindersEnabled: Bool {
        get { UserDefaults.standard.object(forKey: remindersKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: remindersKey) }
    }
}
