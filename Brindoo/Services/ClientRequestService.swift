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

    /// Quante richieste può tenere aperte insieme un cliente senza abbonamento.
    /// Due bastano per confrontare, alla terza Pro serve davvero.
    nonisolated static let maxOpenRequestsFree = 2

    private var client: SupabaseClient {
        SupabaseManager.shared.client
    }

    /// Richieste aperte per i professionisti, gia' nell'ordine giusto.
    ///
    /// L'ordine lo decide il database, non l'app: la pagina e' tagliata a 100
    /// righe, quindi riordinare dopo lascerebbe fuori proprio le richieste in
    /// evidenza piu' vecchie — cioe' il posto che i clienti Pro hanno pagato.
    /// In cima i clienti Pro, poi le urgenti, a parita' la piu' recente.
    /// Esclude le proprie (chi era cliente e poi è diventato professionista
    /// non deve ritrovarsele fra quelle da contattare) e quelle con la data
    /// già passata, anche prima che il lavoro notturno le chiuda.
    func fetchOpenRequests() async throws -> [ClientRequest] {
        var query = client
            .from("client_requests_ranked")
            .select()
            .eq("status", value: ClientRequestStatus.open.rawValue)
            .or("event_date.is.null,event_date.gte.\(BrindooFormat.todayString)")
        if let me = SupabaseManager.shared.currentUserID {
            query = query.neq("client_id", value: me)
        }
        return try await query
            .order("client_is_pro", ascending: false)
            .order("urgent", ascending: false, nullsFirst: false)
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

        try await ensureCanOpenAnother(userId: userId)

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

        do {
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
        } catch {
            // Il tetto vive anche nel database: se a rifiutare e' lui, l'utente
            // deve leggere lo stesso messaggio, non "riprova piu' tardi".
            throw BrindooLimitError.mapping(error)
        }
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
        if let userId = SupabaseManager.shared.currentUserID {
            // Riaprire è aprire: passa dallo stesso tetto della pubblicazione.
            try await ensureCanOpenAnother(userId: userId)
        }
        do {
            try await client
                .from("client_requests")
                .update(["status": ClientRequestStatus.open.rawValue])
                .eq("id", value: requestId)
                .execute()
        } catch {
            throw BrindooLimitError.mapping(error)
        }
    }

    /// Solleva `BrindooLimitError.maxClientRequestsReached` se il cliente non è
    /// Pro e ha già il massimo di richieste aperte. Il database ha lo stesso
    /// tetto: qui serve solo a dare il messaggio giusto e ad aprire la paywall.
    private func ensureCanOpenAnother(userId: UUID) async throws {
        // Prima si conta, poi semmai si guarda l'abbonamento: chi sta sotto al
        // tetto — quasi tutti, quasi sempre — non paga il viaggio in piu'.
        struct Row: Decodable { let id: UUID }
        let open: [Row] = try await client
            .from("client_requests")
            .select("id")
            .eq("client_id", value: userId)
            .eq("status", value: ClientRequestStatus.open.rawValue)
            // Quelle scadute non contano: il database le chiude da solo.
            .or("event_date.is.null,event_date.gte.\(BrindooFormat.todayString)")
            .limit(Self.maxOpenRequestsFree)
            .execute()
            .value

        guard open.count >= Self.maxOpenRequestsFree else { return }

        // Se il profilo non arriva (rete ballerina) non si inventa un rifiuto:
        // decide il database, che il tetto ce l'ha uguale.
        guard let profile = try? await ProfileService.shared.fetchProfile(userID: userId) else { return }
        if !profile.isPro {
            throw BrindooLimitError.maxClientRequestsReached(max: Self.maxOpenRequestsFree)
        }
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
