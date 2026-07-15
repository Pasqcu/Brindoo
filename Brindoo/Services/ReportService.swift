//
//  ReportService.swift
//  Brindoo
//
//  Service per le segnalazioni di contenuti / utenti.
//  Richiesto da Apple App Store Guideline 1.2 (User-Generated Content):
//  ogni app con UGC deve offrire un meccanismo per segnalare contenuti
//  offensivi e bloccare l'autore. Risposta entro 24 ore.
//

import Foundation
import Supabase

// MARK: - Modello

/// Tipo di entità segnalata.
enum ReportTargetType: String, Codable, CaseIterable {
    case user            // segnalazione utente intero
    case review          // recensione
    case message         // singolo messaggio in chat
    case portfolioItem = "portfolio_item"  // foto del portfolio
    case offer           // offerta di servizio
}

/// Motivo predefinito della segnalazione.
enum ReportReason: String, Codable, CaseIterable, Identifiable {
    case spam
    case inappropriate
    case harassment
    case fake
    case impersonation
    case illegal
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spam:           return "Spam o pubblicità"
        case .inappropriate:  return "Contenuto inappropriato o offensivo"
        case .harassment:     return "Molestie o minacce"
        case .fake:           return "Informazioni false o ingannevoli"
        case .impersonation:  return "Impersonificazione di altri"
        case .illegal:        return "Attività illegale"
        case .other:          return "Altro"
        }
    }

    var systemIcon: String {
        switch self {
        case .spam:           return "envelope.badge"
        case .inappropriate:  return "exclamationmark.octagon.fill"
        case .harassment:     return "hand.raised.fill"
        case .fake:           return "questionmark.circle.fill"
        case .impersonation:  return "person.fill.questionmark"
        case .illegal:        return "exclamationmark.shield.fill"
        case .other:          return "ellipsis.circle.fill"
        }
    }
}

// MARK: - Service

@MainActor
final class ReportService {

    static let shared = ReportService()
    private init() {}

    private var client: SupabaseClient {
        SupabaseManager.shared.client
    }

    /// Invia una segnalazione. Se l'utente ha già segnalato lo stesso target
    /// la riga è ignorata (UNIQUE constraint).
    func report(
        targetType: ReportTargetType,
        targetId: UUID,
        reason: ReportReason,
        description: String?
    ) async throws {
        guard let reporterId = SupabaseManager.shared.currentUserID else {
            throw NSError(
                domain: "ReportService",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Devi essere loggato per segnalare"]
            )
        }

        // Non puoi segnalare te stesso (caso target_type = user)
        if targetType == .user && targetId == reporterId {
            throw NSError(
                domain: "ReportService",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Non puoi segnalare te stesso"]
            )
        }

        let trimmed = description?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(1000)
        let finalDescription: String? = trimmed.map(String.init).flatMap {
            $0.isEmpty ? nil : $0
        }

        struct Payload: Encodable {
            let reporter_id: UUID
            let target_type: String
            let target_id: UUID
            let reason: String
            let description: String?
        }

        let payload = Payload(
            reporter_id: reporterId,
            target_type: targetType.rawValue,
            target_id: targetId,
            reason: reason.rawValue,
            description: finalDescription
        )

        do {
            try await client
                .from("reports")
                .insert(payload)
                .execute()
            print("✅ Segnalazione inviata: \(targetType.rawValue) \(targetId)")
        } catch {
            // Se l'utente ha già segnalato lo stesso target, l'INSERT viola
            // l'UNIQUE constraint. Lo trattiamo come success "soft": l'utente
            // ha già segnalato → conferma silenziosa.
            let message = error.localizedDescription.lowercased()
            if message.contains("duplicate") || message.contains("unique") {
                print("ℹ️ Segnalazione già esistente, ignoro")
                return
            }
            BrindooLog.error("Errore invio segnalazione: \(error)")
            throw error
        }
    }
}
