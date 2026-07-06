//
//  LocalCacheStore.swift
//  Brindoo
//
//  Cache locale leggera basata su file JSON in caches directory.
//  Pensata per snapshot read-only (es. ultime conversazioni, ultime offerte viste).
//

import Foundation

actor LocalCacheStore {
    static let shared = LocalCacheStore()

    private let fm = FileManager.default
    private lazy var root: URL = {
        let base = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let url = base.appendingPathComponent("BrindooCache", isDirectory: true)
        if !fm.fileExists(atPath: url.path) {
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }()

    private func url(for key: String) -> URL {
        let safe = key.replacingOccurrences(of: "/", with: "_")
        return root.appendingPathComponent(safe).appendingPathExtension("json")
    }

    func save<T: Encodable>(_ value: T, for key: String) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url(for: key), options: .atomic)
    }

    func load<T: Decodable>(_ type: T.Type, for key: String) -> T? {
        let url = url(for: key)
        guard fm.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(type, from: data)
    }

    func remove(for key: String) {
        try? fm.removeItem(at: url(for: key))
    }

    func clearAll() {
        try? fm.removeItem(at: root)
    }
}

enum BrindooCacheKey {
    static let recentConversations = "recent_conversations"
    static let recentOffers = "recent_offers"
    static let savedFilters = "saved_filters"
    static let onboardingSeen = "onboarding_seen"
    static let boardSnapshot = "board_snapshot_v1"
    static func draft(conversationID: UUID) -> String { "chat_draft_\(conversationID.uuidString)" }
}
