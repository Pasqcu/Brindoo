//
//  DeepLinkRouter.swift
//  Brindoo
//
//  Gestisce la navigazione quando l'utente tocca una notifica.
//  Le View osservano i Published per reagire e navigare alla destinazione corretta.
//

import Foundation
import Observation

/// Tipi di notifica che l'app gestisce
enum NotificationType: String {
    case newMessage = "new_message"
    case newProposal = "new_proposal"
    case proposalCounter = "proposal_counter"
    case proposalAccepted = "proposal_accepted"
    case newReview = "new_review"
}

/// Rappresenta una notifica ricevuta, parsata
struct NotificationPayload: Equatable {
    let type: NotificationType
    let conversationId: UUID?
    let offerId: UUID?
    let reviewId: UUID?

    init?(userInfo: [AnyHashable: Any]) {
        guard let typeString = userInfo["type"] as? String,
              let type = NotificationType(rawValue: typeString) else {
            return nil
        }

        self.type = type
        self.conversationId = (userInfo["conversation_id"] as? String).flatMap(UUID.init)
        self.offerId = (userInfo["offer_id"] as? String).flatMap(UUID.init)
        self.reviewId = (userInfo["review_id"] as? String).flatMap(UUID.init)
    }
}

/// Router globale: le View principali (MainTabView, ChatListView, BoardView) osservano
/// `pendingDestination` per reagire al tap su notifica
@MainActor
@Observable
final class DeepLinkRouter {

    static let shared = DeepLinkRouter()
    private init() {}

    /// Tab da selezionare in MainTabView (0=Bacheca, 1=Trattative, 2=Chat, 3=Profilo)
    var selectedTab: Int = 0

    /// Conversazione da aprire (chat tab)
    var pendingConversationId: UUID?

    /// Offerta da aprire (bacheca → dettaglio o trattative)
    var pendingOfferId: UUID?

    /// Profilo professionista da aprire (da link condiviso)
    var pendingProfileId: UUID?

    /// Recensione → naviga al profilo dell'organizzatore (id non disponibile dal payload,
    /// la View decide cosa fare)
    var pendingReviewId: UUID?

    /// Gestisce un payload notifica e imposta la destinazione
    func handle(payload: NotificationPayload) async {
        switch payload.type {
        case .newMessage:
            selectedTab = 2 // Chat
            pendingConversationId = payload.conversationId

        case .newProposal, .proposalCounter, .proposalAccepted:
            selectedTab = 1 // Trattative
            pendingOfferId = payload.offerId

        case .newReview:
            selectedTab = 3 // Profilo (l'organizzatore vede la propria recensione)
            pendingReviewId = payload.reviewId
        }

        print("✅ Deep link gestito: \(payload.type.rawValue)")
    }

    /// Reset dopo che la destinazione è stata raggiunta
    func clearPendingConversation() {
        pendingConversationId = nil
    }

    func clearPendingOffer() {
        pendingOfferId = nil
    }

    func clearPendingProfile() {
        pendingProfileId = nil
    }

    /// Gestisce un link "https://brindoo.app/p/<id>" o "/o/<id>".
    /// Restituisce true se è stato riconosciuto.
    @discardableResult
    func handleShareLink(_ url: URL) -> Bool {
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count >= 2 else { return false }
        switch parts[0] {
        case "p":
            if let id = UUID(uuidString: parts[1]) { pendingProfileId = id; return true }
        case "o":
            if let id = UUID(uuidString: parts[1]) { pendingOfferId = id; return true }
        default:
            break
        }
        return false
    }

    func clearPendingReview() {
        pendingReviewId = nil
    }
}
