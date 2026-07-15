//
//  AnalyticsService.swift
//  Brindoo
//
//  Tracking minimale per le statistiche Pro:
//   - profile_views: chi visita un profilo
//   - offer_views  : chi apre il dettaglio di un'offerta
//   - calcolo aggregati per OrganizerStatsView
//

import Foundation
import Supabase

@MainActor
final class AnalyticsService {

    static let shared = AnalyticsService()
    private init() {}

    private var client: SupabaseClient { SupabaseManager.shared.client }

    // MARK: - Tracking

    /// Registra una visita al profilo. Best-effort, silenzia errori.
    func trackProfileView(profileId: UUID) async {
        guard let viewerId = SupabaseManager.shared.currentUserID, viewerId != profileId else {
            return
        }
        struct Row: Encodable {
            let profile_id: UUID
            let viewer_id: UUID?
        }
        do {
            try await client
                .from("profile_views")
                .insert(Row(profile_id: profileId, viewer_id: viewerId))
                .execute()
        } catch {
            print("⚠️ profile_view: \(error)")
        }
    }

    /// Registra una visita al dettaglio offerta.
    func trackOfferView(offerId: UUID) async {
        guard let viewerId = SupabaseManager.shared.currentUserID else { return }
        struct Row: Encodable {
            let offer_id: UUID
            let viewer_id: UUID?
        }
        do {
            try await client
                .from("offer_views")
                .insert(Row(offer_id: offerId, viewer_id: viewerId))
                .execute()
        } catch {
            print("⚠️ offer_view: \(error)")
        }
    }

    // MARK: - Statistiche aggregate (per dashboard Pro)

    struct OrganizerStats: Equatable {
        let profileViews30d: Int
        let offerViews30d: Int
        let applicationsReceived30d: Int
        let proposalsReceived30d: Int
        let averageResponseMinutes: Double?
    }

    /// Carica gli aggregati delle ultime 4 settimane per l'organizzatore corrente.
    func fetchMyStats() async throws -> OrganizerStats {
        guard let userId = SupabaseManager.shared.currentUserID else {
            return OrganizerStats(
                profileViews30d: 0, offerViews30d: 0,
                applicationsReceived30d: 0, proposalsReceived30d: 0,
                averageResponseMinutes: nil
            )
        }

        let since = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        let sinceISO = ISO8601DateFormatter().string(from: since)

        // 1) profile views
        struct PVRow: Decodable { let id: UUID }
        let pvs: [PVRow] = (try? await client
            .from("profile_views")
            .select("id")
            .eq("profile_id", value: userId)
            .gte("viewed_at", value: sinceISO)
            .execute()
            .value) ?? []

        // 2) offer views (richiede le mie offerte)
        struct OfferRow: Decodable { let id: UUID }
        let myOffers: [OfferRow] = (try? await client
            .from("service_offers")
            .select("id")
            .eq("organizer_id", value: userId)
            .execute()
            .value) ?? []
        let offerIds = myOffers.map { $0.id.uuidString }

        var ovCount = 0
        if !offerIds.isEmpty {
            struct OVRow: Decodable { let id: UUID }
            let ovs: [OVRow] = (try? await client
                .from("offer_views")
                .select("id")
                .in("offer_id", values: offerIds)
                .gte("viewed_at", value: sinceISO)
                .execute()
                .value) ?? []
            ovCount = ovs.count
        }

        // 3) Applicazioni ricevute = candidature dove l'organizer è me — wait,
        //    no, l'organizzatore RICEVE candidature sulle SUE richieste? No, lo schema
        //    è: clienti pubblicano richieste, organizzatori si candidano. Quindi qui
        //    l'organizzatore non riceve "applications". Salto questo conteggio
        //    per gli organizzatori.
        //    Per i clienti invece le applications ricevute hanno senso, ma le statistiche
        //    sono per organizzatori Pro, quindi non ci interessa.
        let appsReceived = 0

        // 4) Proposte ricevute sulle proprie offerte
        struct PropRow: Decodable { let id: UUID }
        let props: [PropRow] = (try? await client
            .from("offer_proposals")
            .select("id")
            .eq("organizer_id", value: userId)
            .gte("created_at", value: sinceISO)
            .execute()
            .value) ?? []

        // 5) Tempo medio di risposta — calcolato sui messaggi in chat
        let avgResponse = await averageResponseMinutes(userId: userId)

        return OrganizerStats(
            profileViews30d: pvs.count,
            offerViews30d: ovCount,
            applicationsReceived30d: appsReceived,
            proposalsReceived30d: props.count,
            averageResponseMinutes: avgResponse
        )
    }

    /// Tempo medio (minuti) tra messaggio ricevuto e prima risposta dell'utente.
    /// Calcolato per le ultime 30 conversation con almeno una risposta.
    private func averageResponseMinutes(userId: UUID) async -> Double? {
        struct ConvRow: Decodable { let id: UUID }
        struct MsgRow: Decodable {
            let conversation_id: UUID
            let sender_id: UUID
            let created_at: Date
        }

        let convs: [ConvRow] = (try? await client
            .from("conversations")
            .select("id")
            .or("client_id.eq.\(userId.uuidString),organizer_id.eq.\(userId.uuidString)")
            .order("last_message_at", ascending: false)
            .limit(30)
            .execute()
            .value) ?? []
        guard !convs.isEmpty else { return nil }

        let convIds = convs.map { $0.id.uuidString }
        let msgs: [MsgRow] = (try? await client
            .from("messages")
            .select("conversation_id, sender_id, created_at")
            .in("conversation_id", values: convIds)
            .order("created_at", ascending: true)
            .execute()
            .value) ?? []
        guard !msgs.isEmpty else { return nil }

        // Per ogni conv, trova la prima coppia (msg-da-altri → mia risposta successiva)
        // e misura il delta.
        var deltas: [TimeInterval] = []
        let grouped = Dictionary(grouping: msgs) { $0.conversation_id }
        for (_, conversation) in grouped {
            var pendingIncoming: Date? = nil
            for m in conversation {
                if m.sender_id != userId {
                    if pendingIncoming == nil {
                        pendingIncoming = m.created_at
                    }
                } else {
                    if let incoming = pendingIncoming {
                        let delta = m.created_at.timeIntervalSince(incoming)
                        if delta > 0 {
                            deltas.append(delta)
                        }
                        pendingIncoming = nil
                        break // primo response per questa conv, basta
                    }
                }
            }
        }

        guard !deltas.isEmpty else { return nil }
        let avgSeconds = deltas.reduce(0, +) / Double(deltas.count)
        return avgSeconds / 60.0
    }
}
