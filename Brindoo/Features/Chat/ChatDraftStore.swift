//
//  ChatDraftStore.swift
//  Brindoo
//
//  Memorizza in cache locale la bozza di un messaggio per ogni conversazione.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class ChatDraftStore: ObservableObject {
    static let shared = ChatDraftStore()

    private var memoryCache: [UUID: String] = [:]

    private init() {}

    func draft(for conversationID: UUID) async -> String {
        if let cached = memoryCache[conversationID] { return cached }
        if let stored: String = await LocalCacheStore.shared.load(
            String.self,
            for: BrindooCacheKey.draft(conversationID: conversationID)
        ) {
            memoryCache[conversationID] = stored
            return stored
        }
        return ""
    }

    func setDraft(_ text: String, for conversationID: UUID) async {
        memoryCache[conversationID] = text
        if text.isEmpty {
            await LocalCacheStore.shared.remove(for: BrindooCacheKey.draft(conversationID: conversationID))
        } else {
            await LocalCacheStore.shared.save(text, for: BrindooCacheKey.draft(conversationID: conversationID))
        }
    }

    func clear(_ conversationID: UUID) async {
        memoryCache.removeValue(forKey: conversationID)
        await LocalCacheStore.shared.remove(for: BrindooCacheKey.draft(conversationID: conversationID))
    }
}
