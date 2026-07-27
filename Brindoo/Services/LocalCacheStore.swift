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

    // `FileManager` non e' Sendable: tenerne una copia dentro l'attore la
    // farebbe uscire dal suo confine. Si prende all'uso, che e' gratis.
    private lazy var root: URL = {
        let fm = FileManager.default
        // La cartella caches c'e' sempre su iOS, ma un `!` qui farebbe morire
        // l'app per una cache: la cartella temporanea e' un ripiego onesto.
        let base = fm.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fm.temporaryDirectory
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
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(type, from: data)
    }

    func remove(for key: String) {
        try? FileManager.default.removeItem(at: url(for: key))
    }

    func clearAll() {
        try? FileManager.default.removeItem(at: root)
    }
}

enum BrindooCacheKey {
    /// Ultima bacheca mostrata, per l'apertura istantanea.
    static let boardSnapshot = "board_snapshot_v1"
    /// Ricerche salvate dal cliente (con eventuale avviso attivo).
    static let savedSearches = "saved_searches_v1"
    /// Azioni scritte mentre l'utente era offline, in attesa di reinvio.
    static let outbox = "offline_outbox_v1"
    /// Bozza di messaggio per conversazione.
    static func draft(conversationID: UUID) -> String { "chat_draft_\(conversationID.uuidString)" }
}
