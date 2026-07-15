//
//  ResponseInsightsService.swift
//  Brindoo
//
//  Calcola la velocità di risposta in chat del professionista corrente
//  (mediana dei tempi con cui risponde ai messaggi dei clienti) e la salva
//  su `profiles.response_minutes`, così i clienti vedono "Risponde in giornata".
//
//  Il calcolo usa solo i messaggi delle proprie conversazioni (RLS) e gira
//  al massimo una volta al giorno, al primo avvio utile.
//

import Foundation
import Supabase

@MainActor
final class ResponseInsightsService {

    static let shared = ResponseInsightsService()
    private init() {}

    private var client: SupabaseClient {
        SupabaseManager.shared.client
    }

    private static let lastRunKey = "brindoo.responseInsights.lastRun"

    /// Aggiorna il tempo di risposta del professionista corrente, se serve.
    /// No-op per i clienti e se l'ultimo calcolo risale a meno di 24 ore fa.
    func updateIfNeeded(profile: Profile?) async {
        guard let profile, profile.role == .organizer else { return }

        let last = UserDefaults.standard.object(forKey: Self.lastRunKey) as? Date
        if let last, Date().timeIntervalSince(last) < 24 * 60 * 60 { return }

        struct Row: Decodable {
            let conversation_id: UUID
            let sender_id: UUID
            let created_at: Date
        }

        do {
            // Ultimi messaggi delle mie conversazioni (RLS limita già alle mie).
            let rows: [Row] = try await client
                .from("messages")
                .select("conversation_id, sender_id, created_at")
                .order("created_at", ascending: false)
                .limit(400)
                .execute()
                .value

            let samples = Self.responseSamples(
                messages: rows
                    .sorted { $0.created_at < $1.created_at }
                    .map { (conversation: $0.conversation_id, sender: $0.sender_id, at: $0.created_at) },
                me: profile.id
            )

            // Con meno di 3 risposte il dato non è affidabile: non salvare nulla.
            if samples.count >= 3, let median = Self.medianMinutes(samples) {
                struct Payload: Encodable { let response_minutes: Int }
                try await client
                    .from("profiles")
                    .update(Payload(response_minutes: median))
                    .eq("id", value: profile.id)
                    .execute()
            }

            UserDefaults.standard.set(Date(), forKey: Self.lastRunKey)
        } catch {
            // Colonna mancante o rete assente: riproverà al prossimo avvio.
            BrindooLog.error("ResponseInsights: \(error)")
        }
    }

    // MARK: - Logica pura (testabile)

    /// Estrae i tempi di risposta (in minuti) dell'utente `me`:
    /// per ogni messaggio altrui seguito da una mia risposta nella stessa
    /// conversazione, misura l'attesa del primo messaggio senza risposta.
    /// I messaggi devono essere in ordine cronologico crescente.
    nonisolated static func responseSamples(
        messages: [(conversation: UUID, sender: UUID, at: Date)],
        me: UUID
    ) -> [TimeInterval] {
        var pendingSince: [UUID: Date] = [:]   // conversazione → primo msg altrui in attesa
        var samples: [TimeInterval] = []

        for msg in messages {
            if msg.sender == me {
                if let since = pendingSince.removeValue(forKey: msg.conversation) {
                    samples.append(msg.at.timeIntervalSince(since))
                }
            } else if pendingSince[msg.conversation] == nil {
                pendingSince[msg.conversation] = msg.at
            }
        }
        return samples.filter { $0 >= 0 }
    }

    /// Mediana in minuti (arrotondata) di un insieme di intervalli.
    nonisolated static func medianMinutes(_ samples: [TimeInterval]) -> Int? {
        guard !samples.isEmpty else { return nil }
        let sorted = samples.sorted()
        let mid = sorted.count / 2
        let median: TimeInterval = sorted.count.isMultiple(of: 2)
            ? (sorted[mid - 1] + sorted[mid]) / 2
            : sorted[mid]
        return Int((median / 60).rounded())
    }
}
