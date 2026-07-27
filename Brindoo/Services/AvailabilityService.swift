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

    struct Row: Decodable { let day: String }

    /// Giorni segnati a mano come non disponibili da un organizzatore.
    func fetchMarkedUnavailableDays(organizerId: UUID) async throws -> Set<String> {
        let rows: [Row] = try await client
            .from("organizer_unavailable_dates")
            .select("day")
            .eq("organizer_id", value: organizerId)
            .execute()
            .value
        return Set(rows.map { $0.day })
    }

    /// Giorni in cui un organizzatore ha già un evento confermato.
    ///
    /// Sono impegni veri, presi dentro l'app: contano come occupato quanto
    /// i giorni segnati a mano. Senza questo, chi si dimentica di segnare
    /// il calendario risulta libero e può essere prenotato due volte per lo
    /// stesso giorno — nel mestiere degli eventi il danno peggiore.
    func fetchBookedDays(organizerId: UUID) async throws -> Set<String> {
        struct DayRow: Decodable { let event_date: String? }
        let rows: [DayRow] = try await client
            .from("offer_proposals")
            .select("event_date")
            .eq("organizer_id", value: organizerId)
            .eq("status", value: OfferProposalStatus.accepted.rawValue)
            .neq("booking_status", value: BookingStatus.cancelled.rawValue)
            .not("event_date", operator: .is, value: "null")
            .execute()
            .value
        return Set(rows.compactMap(\.event_date))
    }

    /// Tutti i giorni occupati di un organizzatore: segnati a mano più
    /// quelli degli eventi già confermati.
    func fetchUnavailableDays(organizerId: UUID) async throws -> Set<String> {
        async let marked = fetchMarkedUnavailableDays(organizerId: organizerId)
        async let booked = fetchBookedDays(organizerId: organizerId)
        return try await marked.union(booked)
    }

    /// ID degli organizzatori occupati nel giorno dato, per qualunque
    /// motivo: giorno segnato a mano oppure evento già confermato.
    func fetchBusyOrganizerIds(on day: Date) async throws -> Set<UUID> {
        let dayString = BrindooFormat.dayString(from: day)
        struct IdRow: Decodable { let organizer_id: UUID }
        struct BookedRow: Decodable { let organizer_id: UUID }

        async let markedRows: [IdRow] = client
            .from("organizer_unavailable_dates")
            .select("organizer_id")
            .eq("day", value: dayString)
            .execute()
            .value

        async let bookedRows: [BookedRow] = client
            .from("offer_proposals")
            .select("organizer_id")
            .eq("event_date", value: dayString)
            .eq("status", value: OfferProposalStatus.accepted.rawValue)
            .neq("booking_status", value: BookingStatus.cancelled.rawValue)
            .execute()
            .value

        let marked = try await markedRows.map(\.organizer_id)
        let booked = try await bookedRows.map(\.organizer_id)
        return Set(marked).union(booked)
    }

    /// Giorni segnati a mano dall'utente corrente: sono i soli che può
    /// togliere: quelli degli eventi confermati non si cancellano da qui.
    func fetchMyUnavailableDays() async throws -> Set<Date> {
        guard let userId = SupabaseManager.shared.currentUserID else { return [] }
        let days = try await fetchMarkedUnavailableDays(organizerId: userId)
        return Set(days.compactMap { BrindooFormat.day(from: $0) })
    }

    /// Giorni dell'utente corrente già impegnati da eventi confermati.
    func fetchMyBookedDays() async throws -> Set<Date> {
        guard let userId = SupabaseManager.shared.currentUserID else { return [] }
        let days = try await fetchBookedDays(organizerId: userId)
        return Set(days.compactMap { BrindooFormat.day(from: $0) })
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
        let payload = dates.map { Insert(organizer_id: userId, day: BrindooFormat.dayString(from: $0)) }
        try await client
            .from("organizer_unavailable_dates")
            .insert(payload)
            .execute()
    }
}
