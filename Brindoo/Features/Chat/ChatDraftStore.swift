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

    /// Dopo un mese una frase lasciata a metà non è più una bozza: è una
    /// trappola che riappare in una conversazione dimenticata, pronta da
    /// mandare per sbaglio. Passato questo tempo la bozza si butta.
    static let maxAge: TimeInterval = 30 * 24 * 60 * 60

    /// Bozza con la data in cui è stata scritta.
    private struct StoredDraft: Codable {
        let text: String
        let savedAt: Date
    }

    private init() {}

    func draft(for conversationID: UUID) async -> String {
        if let cached = memoryCache[conversationID] { return cached }

        let key = BrindooCacheKey.draft(conversationID: conversationID)

        if let stored: StoredDraft = await LocalCacheStore.shared.load(StoredDraft.self, for: key) {
            guard Date().timeIntervalSince(stored.savedAt) < Self.maxAge else {
                await LocalCacheStore.shared.remove(for: key)
                return ""
            }
            memoryCache[conversationID] = stored.text
            return stored.text
        }

        // Bozze salvate dalle versioni precedenti: erano solo testo, senza
        // data. Si leggono ancora e alla prima modifica prendono la data.
        if let legacy: String = await LocalCacheStore.shared.load(String.self, for: key) {
            memoryCache[conversationID] = legacy
            return legacy
        }
        return ""
    }

    func setDraft(_ text: String, for conversationID: UUID) async {
        memoryCache[conversationID] = text
        let key = BrindooCacheKey.draft(conversationID: conversationID)
        if text.isEmpty {
            await LocalCacheStore.shared.remove(for: key)
        } else {
            await LocalCacheStore.shared.save(StoredDraft(text: text, savedAt: Date()), for: key)
        }
    }

    func clear(_ conversationID: UUID) async {
        memoryCache.removeValue(forKey: conversationID)
        await LocalCacheStore.shared.remove(for: BrindooCacheKey.draft(conversationID: conversationID))
    }
}
