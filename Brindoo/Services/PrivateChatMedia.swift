//
//  PrivateChatMedia.swift
//  Brindoo
//
//  Foto e vocali della chat stanno in un bucket privato: li apre solo chi
//  partecipa alla conversazione, con la propria sessione. Prima il bucket
//  era pubblico e bastava il link per aprirli.
//
//  I messaggi salvano ancora l'indirizzo "pubblico" (anche quelli vecchi):
//  qui lo si trasforma in quello autenticato al momento di scaricarlo.
//

import Foundation
import Supabase

enum PrivateChatMedia {

    nonisolated private static let publicSegment = "/storage/v1/object/public/chat-images/"

    /// Richiesta per scaricare un file: autenticata se è un file della chat,
    /// normale per tutto il resto (avatar, portfolio restano pubblici).
    static func request(for url: URL) async -> URLRequest {
        let text = url.absoluteString
        guard text.contains(publicSegment),
              let authURL = URL(string: text.replacingOccurrences(
                of: "/storage/v1/object/public/",
                with: "/storage/v1/object/authenticated/"
              )),
              let token = try? await SupabaseManager.shared.auth.session.accessToken
        else { return URLRequest(url: url) }

        var request = URLRequest(url: authURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Secrets.supabaseAnonKey, forHTTPHeaderField: "apikey")
        return request
    }
}
