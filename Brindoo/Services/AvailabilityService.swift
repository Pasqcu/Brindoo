//
//  AvailabilityService.swift
//  Brindoo
//
//  Gestisce le date di NON disponibilità degli organizzatori.
//  L'organizzatore segna i giorni occupati; i clienti li leggono per evitarli.
//

import Foundation
import Supabase

@MainActor
final class AvailabilityService {

    static let shared = AvailabilityService()
    private init() {}

    private var client: SupabaseClient {
        SupabaseManager.shared.client
    }

    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    struct Row: Decodable { let day: String }

    /// Giorni non disponibili (stringhe "yyyy-MM-dd") di un organizzatore.
    func fetchUnavailableDays(organizerId: UUID) async throws -> Set<String> {
        let rows: [Row] = try await client
            .from("organizer_unavailable_dates")
            .select("day")
            .eq("organizer_id", value: organizerId)
            .execute()
            .value
        return Set(rows.map { $0.day })
    }

    func fetchMyUnavailableDays() async throws -> Set<Date> {
        guard let userId = SupabaseManager.shared.currentUserID else { return [] }
        let days = try await fetchUnavailableDays(organizerId: userId)
        return Set(days.compactMap { Self.fmt.date(from: $0) })
    }

    /// Sovrascrive l'insieme dei giorni non disponibili dell'utente corrente.
    func setMyUnavailableDays(_ dates: Set<Date>) async throws {
        guard let userId = SupabaseManager.shared.currentUserID else { return }

        // Cancella tutto e reinserisce (insieme piccolo: semplice e robusto).
        try await client
            .from("organizer_unavailable_dates")
            .delete()
            .eq("organizer_id", value: userId)
            .execute()

        guard !dates.isEmpty else { return }

        struct Insert: Encodable { let organizer_id: UUID; let day: String }
        let payload = dates.map { Insert(organizer_id: userId, day: Self.fmt.string(from: $0)) }
        try await client
            .from("organizer_unavailable_dates")
            .insert(payload)
            .execute()
    }
}
