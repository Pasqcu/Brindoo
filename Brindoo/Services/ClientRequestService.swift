//
//  ClientRequestService.swift
//  Brindoo
//
//  CRUD delle richieste dei clienti (bacheca inversa).
//

import Foundation
import Supabase

@MainActor
final class ClientRequestService {

    static let shared = ClientRequestService()
    private init() {}

    private var client: SupabaseClient {
        SupabaseManager.shared.client
    }

    /// Richieste aperte, dalla più recente (per i professionisti).
    func fetchOpenRequests() async throws -> [ClientRequest] {
        try await client
            .from("client_requests")
            .select()
            .eq("status", value: ClientRequestStatus.open.rawValue)
            .order("created_at", ascending: false)
            .limit(100)
            .execute()
            .value
    }

    /// Le richieste del cliente corrente (aperte e chiuse).
    func fetchMyRequests() async throws -> [ClientRequest] {
        guard let userId = SupabaseManager.shared.currentUserID else { return [] }
        return try await client
            .from("client_requests")
            .select()
            .eq("client_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Pubblica una nuova richiesta.
    func create(
        title: String,
        description: String?,
        area: String,
        eventDate: String?,
        budget: Double?,
        categoryId: UUID?,
        urgent: Bool = false
    ) async throws -> ClientRequest {
        guard let userId = SupabaseManager.shared.currentUserID else {
            throw URLError(.userAuthenticationRequired)
        }

        struct Insert: Encodable {
            let client_id: UUID
            let title: String
            let description: String?
            let area: String
            let event_date: String?
            let budget: Double?
            let category_id: UUID?
            let urgent: Bool
        }

        return try await client
            .from("client_requests")
            .insert(Insert(
                client_id: userId,
                title: title,
                description: description,
                area: area,
                event_date: eventDate,
                budget: budget,
                category_id: categoryId,
                urgent: urgent
            ))
            .select()
            .single()
            .execute()
            .value
    }

    /// Chiude una richiesta (il cliente ha trovato quello che cercava).
    func close(requestId: UUID) async throws {
        try await client
            .from("client_requests")
            .update(["status": ClientRequestStatus.closed.rawValue])
            .eq("id", value: requestId)
            .execute()
    }

    /// Riapre una richiesta chiusa.
    func reopen(requestId: UUID) async throws {
        try await client
            .from("client_requests")
            .update(["status": ClientRequestStatus.open.rawValue])
            .eq("id", value: requestId)
            .execute()
    }

    /// Elimina definitivamente una richiesta.
    func delete(requestId: UUID) async throws {
        try await client
            .from("client_requests")
            .delete()
            .eq("id", value: requestId)
            .execute()
    }
}
