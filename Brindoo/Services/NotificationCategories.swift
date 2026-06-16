//
//  NotificationCategories.swift
//  Brindoo
//
//  Categorie e azioni rapide per le notifiche push.
//  Da registrare all'avvio (AppDelegate o didFinishLaunching).
//

import Foundation
import UserNotifications

enum BrindooPushCategory: String {
    case message = "BRINDOO_MESSAGE"
    case offer = "BRINDOO_OFFER"
    case review = "BRINDOO_REVIEW"
}

enum BrindooPushAction: String {
    case replyMessage = "REPLY_MESSAGE"
    case markRead = "MARK_READ"
    case acceptOffer = "ACCEPT_OFFER"
    case rejectOffer = "REJECT_OFFER"
    case viewReview = "VIEW_REVIEW"
}

enum NotificationCategoriesRegistrar {

    static func registerCategories() {
        // Messaggio: rispondi inline + segna come letto
        let replyAction = UNTextInputNotificationAction(
            identifier: BrindooPushAction.replyMessage.rawValue,
            title: "Rispondi",
            options: [],
            textInputButtonTitle: "Invia",
            textInputPlaceholder: "Scrivi un messaggio…"
        )
        let markReadAction = UNNotificationAction(
            identifier: BrindooPushAction.markRead.rawValue,
            title: "Segna come letto",
            options: []
        )
        let messageCategory = UNNotificationCategory(
            identifier: BrindooPushCategory.message.rawValue,
            actions: [replyAction, markReadAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        // Offerta: accetta / rifiuta
        let acceptAction = UNNotificationAction(
            identifier: BrindooPushAction.acceptOffer.rawValue,
            title: "Accetta",
            options: [.authenticationRequired]
        )
        let rejectAction = UNNotificationAction(
            identifier: BrindooPushAction.rejectOffer.rawValue,
            title: "Rifiuta",
            options: [.destructive, .authenticationRequired]
        )
        let offerCategory = UNNotificationCategory(
            identifier: BrindooPushCategory.offer.rawValue,
            actions: [acceptAction, rejectAction],
            intentIdentifiers: [],
            options: []
        )

        // Recensione: visualizza
        let viewReviewAction = UNNotificationAction(
            identifier: BrindooPushAction.viewReview.rawValue,
            title: "Visualizza",
            options: [.foreground]
        )
        let reviewCategory = UNNotificationCategory(
            identifier: BrindooPushCategory.review.rawValue,
            actions: [viewReviewAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            messageCategory, offerCategory, reviewCategory
        ])
    }
}
