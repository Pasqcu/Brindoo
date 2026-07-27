//
//  DeepLinkRouter.swift
//  Brindoo
//
//  Gestisce la navigazione quando l'utente tocca una notifica.
//  Le View osservano i Published per reagire e navigare alla destinazione corretta.
//

import Foundation
import Observation

/// Link condivisibili di Brindoo: un punto solo che sa come si scrivono e
/// come si rileggono. Prima l'indirizzo del sito e le lettere di percorso
/// erano ripetuti fra chi costruiva il link e chi lo interpretava: bastava
/// cambiarne uno per rompere l'apertura senza che nulla lo segnalasse.
nonisolated enum BrindooLink {

    private static let host = "https://brindoo.app"

    /// Prima lettera del percorso: `/p/` profilo, `/o/` offerta, `/r/` invito.
    enum Kind: String {
        case profile = "p"
        case offer = "o"
        case referral = "r"
    }

    static func url(_ kind: Kind, _ value: String) -> URL? {
        URL(string: "\(host)/\(kind.rawValue)/\(value)")
    }

    static func url(_ kind: Kind, _ id: UUID) -> URL? {
        url(kind, id.uuidString)
    }

    /// Riconosce un link condiviso e ne estrae tipo e valore.
    static func parse(_ url: URL) -> (kind: Kind, value: String)? {
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count >= 2, let kind = Kind(rawValue: parts[0]) else { return nil }
        return (kind, parts[1])
    }
}

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

        BrindooLog.info("Deep link gestito: \(payload.type.rawValue)")
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
        guard let link = BrindooLink.parse(url),
              let id = UUID(uuidString: link.value) else { return false }
        switch link.kind {
        case .profile: pendingProfileId = id
        case .offer: pendingOfferId = id
        case .referral: return false // l'invito si riscatta dalle Impostazioni
        }
        return true
    }

    func clearPendingReview() {
        pendingReviewId = nil
    }
}
