//
//  PushActionHandler.swift
//  Brindoo
//
//  Gestione delle azioni rapide ricevute dalle notifiche (reply, accept, reject, ecc.).
//

import Foundation
import UserNotifications

@MainActor
enum PushActionHandler {

    /// Chiamato da AppDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:)
    static func handle(_ response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        let action = response.actionIdentifier

        switch action {
        case BrindooPushAction.replyMessage.rawValue:
            await handleReplyMessage(userInfo: userInfo, response: response)
        case BrindooPushAction.markRead.rawValue:
            await handleMarkRead(userInfo: userInfo)
        case BrindooPushAction.acceptOffer.rawValue:
            await handleAcceptOffer(userInfo: userInfo)
        case BrindooPushAction.rejectOffer.rawValue:
            await handleRejectOffer(userInfo: userInfo)
        case BrindooPushAction.viewReview.rawValue,
             UNNotificationDefaultActionIdentifier:
            if let payload = NotificationPayload(userInfo: userInfo) {
                await DeepLinkRouter.shared.handle(payload: payload)
            }
        default:
            break
        }
    }

    // MARK: - Handlers

    private static func handleReplyMessage(userInfo: [AnyHashable: Any], response: UNNotificationResponse) async {
        guard let textResponse = response as? UNTextInputNotificationResponse,
              let conversationIDString = userInfo["conversation_id"] as? String,
              let conversationID = UUID(uuidString: conversationIDString) else { return }
        let text = textResponse.userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        _ = try? await MessageService.shared.sendMessage(
            conversationId: conversationID,
            content: text
        )
    }

    private static func handleMarkRead(userInfo: [AnyHashable: Any]) async {
        guard let conversationIDString = userInfo["conversation_id"] as? String,
              let conversationID = UUID(uuidString: conversationIDString) else { return }
        try? await MessageService.shared.markMessagesAsRead(conversationId: conversationID)
    }

    private static func handleAcceptOffer(userInfo: [AnyHashable: Any]) async {
        // Stub: implementare quando OfferProposalService espone fetchProposal(id:).
        // Per ora apre l'app sulla schermata corretta.
        if let payload = NotificationPayload(userInfo: userInfo) {
            await DeepLinkRouter.shared.handle(payload: payload)
        }
    }

    private static func handleRejectOffer(userInfo: [AnyHashable: Any]) async {
        if let payload = NotificationPayload(userInfo: userInfo) {
            await DeepLinkRouter.shared.handle(payload: payload)
        }
    }
}
