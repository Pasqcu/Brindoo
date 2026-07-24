//
//  ClientTrustService.swift
//  Brindoo
//
//  Fiducia nell'altro senso: finora solo il cliente giudicava il
//  professionista. Qui il professionista dice com'è andata col cliente
//  dopo un evento (si è presentato? ha annullato all'ultimo?).
//
//  Non è una recensione pubblica con testo: sono solo conteggi, mostrati
//  come distintivo ("cliente affidabile · 5 eventi"). Nessuno può scrivere
//  giudizi liberi su un cliente.
//

import Foundation
import Supabase

/// Com'è andata con il cliente.
enum ClientOutcome: String, Codable, CaseIterable, Identifiable {
    case honored        // tutto regolare
    case cancelledLate = "cancelled_late"  // ha annullato all'ultimo
    case noShow = "no_show"                // non si è presentato

    var id: String { rawValue }

    var label: String {
        switch self {
        case .honored:       return "Tutto regolare"
        case .cancelledLate: return "Ha annullato all'ultimo"
        case .noShow:        return "Non si è presentato"
        }
    }

    var icon: String {
        switch self {
        case .honored:       return "checkmark.circle.fill"
        case .cancelledLate: return "calendar.badge.minus"
        case .noShow:        return "person.fill.xmark"
        }
    }
}

/// Conteggi pubblici di un cliente.
struct ClientTrust: Codable, Hashable, Equatable {
    let clientId: UUID
    let honoredCount: Int
    let noShowCount: Int
    let cancelledLateCount: Int
    let totalCount: Int

    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case honoredCount = "honored_count"
        case noShowCount = "no_show_count"
        case cancelledLateCount = "cancelled_late_count"
        case totalCount = "total_count"
    }

    static func empty(for id: UUID) -> ClientTrust {
        ClientTrust(clientId: id, honoredCount: 0, noShowCount: 0, cancelledLateCount: 0, totalCount: 0)
    }

    /// Distintivo da mostrare, o nil se non c'è abbastanza storia.
    /// Serve almeno un paio di eventi per non etichettare nessuno al primo colpo.
    var badge: (label: String, icon: String, isPositive: Bool)? {
        guard totalCount >= 2 else { return nil }
        let problems = noShowCount + cancelledLateCount
        if problems == 0 {
            return ("Cliente affidabile · \(honoredCount) eventi", "checkmark.seal.fill", true)
        }
        if problems >= 2, problems > honoredCount {
            return ("\(problems) impegni non rispettati", "exclamationmark.triangle.fill", false)
        }
        return ("\(honoredCount) eventi regolari su \(totalCount)", "info.circle", true)
    }
}

@MainActor
final class ClientTrustService {

    static let shared = ClientTrustService()
    private init() {}

    private var client: SupabaseClient {
        SupabaseManager.shared.client
    }

    /// Conteggi di un cliente (vuoto se non ha ancora storia).
    func fetchTrust(clientId: UUID) async throws -> ClientTrust {
        let rows: [ClientTrust] = try await client
            .from("client_trust_stats")
            .select()
            .eq("client_id", value: clientId)
            .limit(1)
            .execute()
            .value
        return rows.first ?? .empty(for: clientId)
    }

    /// Conteggi di più clienti in una richiesta sola.
    func fetchTrust(clientIds: [UUID]) async throws -> [UUID: ClientTrust] {
        guard !clientIds.isEmpty else { return [:] }
        let rows: [ClientTrust] = try await client
            .from("client_trust_stats")
            .select()
            .in("client_id", values: clientIds.map(\.uuidString))
            .execute()
            .value
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.clientId, $0) })
    }

    /// Il professionista registra com'è andata. Una sola volta per trattativa.
    func submit(proposalId: UUID, clientId: UUID, outcome: ClientOutcome) async throws {
        guard let me = SupabaseManager.shared.currentUserID else { return }
        struct Row: Encodable {
            let proposal_id: UUID
            let organizer_id: UUID
            let client_id: UUID
            let outcome: String
        }
        try await client
            .from("client_feedback")
            .insert(Row(
                proposal_id: proposalId,
                organizer_id: me,
                client_id: clientId,
                outcome: outcome.rawValue
            ))
            .execute()
    }

    /// Trattative concluse per cui il professionista non ha ancora detto
    /// com'è andata (per proporglielo una volta sola).
    func pendingFeedbackProposalIds(among proposals: [OfferProposal]) async -> Set<UUID> {
        guard let me = SupabaseManager.shared.currentUserID else { return [] }
        let candidates = proposals.filter {
            $0.organizerId == me && $0.status == .accepted && $0.isEventPast
        }
        guard !candidates.isEmpty else { return [] }

        struct Row: Decodable { let proposal_id: UUID }
        let done: [Row] = (try? await client
            .from("client_feedback")
            .select("proposal_id")
            .in("proposal_id", values: candidates.map(\.id.uuidString))
            .execute()
            .value) ?? []

        let alreadyDone = Set(done.map(\.proposal_id))
        return Set(candidates.map(\.id)).subtracting(alreadyDone)
    }
}
