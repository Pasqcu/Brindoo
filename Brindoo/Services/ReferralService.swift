//
//  ReferralService.swift
//  Brindoo
//
//  Gestisce il programma referral: codice univoco utente, riscatto codici.
//  Tabelle: `referral_codes`, `referral_redemptions`.
//

import Foundation
import Supabase

struct ReferralCode: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    let code: String
    let usesCount: Int
    let rewardGrantedCount: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case code
        case usesCount = "uses_count"
        case rewardGrantedCount = "reward_granted_count"
        case createdAt = "created_at"
    }

    var shareURL: URL? {
        URL(string: "https://brindoo.app/r/\(code)")
    }

    var displayCode: String {
        code.uppercased()
    }
}

struct ReferralStats: Codable, Equatable {
    let totalInvited: Int
    let totalActivated: Int
    let proMonthsEarned: Int

    static let zero = ReferralStats(totalInvited: 0, totalActivated: 0, proMonthsEarned: 0)
}

enum ReferralError: LocalizedError {
    case invalidCode
    case alreadyRedeemed
    case selfReferral
    case notFound

    var errorDescription: String? {
        switch self {
        case .invalidCode: return "Codice non valido."
        case .alreadyRedeemed: return "Hai già usato un codice referral."
        case .selfReferral: return "Non puoi usare il tuo stesso codice."
        case .notFound: return "Codice non trovato."
        }
    }
}

@MainActor
final class ReferralService {
    static let shared = ReferralService()
    private init() {}

    private var client: SupabaseClient { SupabaseManager.shared.client }

    /// Restituisce (o crea) il codice referral dell'utente corrente.
    func fetchOrCreateMyCode() async throws -> ReferralCode {
        guard let userId = SupabaseManager.shared.currentUserID else {
            throw ReferralError.invalidCode
        }
        let existing: [ReferralCode] = try await client
            .from("referral_codes")
            .select()
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value
        if let first = existing.first { return first }

        struct CreatePayload: Encodable {
            let user_id: UUID
            let code: String
        }
        let newCode = Self.generateCode()
        let created: ReferralCode = try await client
            .from("referral_codes")
            .insert(CreatePayload(user_id: userId, code: newCode))
            .select()
            .single()
            .execute()
            .value
        return created
    }

    /// Statistiche referral dell'utente corrente.
    func fetchMyStats() async throws -> ReferralStats {
        guard let userId = SupabaseManager.shared.currentUserID else { return .zero }
        struct Row: Decodable {
            let total_invited: Int
            let total_activated: Int
            let pro_months_earned: Int
        }
        let rows: [Row] = try await client
            .from("referral_stats")
            .select()
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value
        guard let r = rows.first else { return .zero }
        return ReferralStats(
            totalInvited: r.total_invited,
            totalActivated: r.total_activated,
            proMonthsEarned: r.pro_months_earned
        )
    }

    /// Riscatta un codice referral (al primo login o dalle impostazioni).
    func redeem(code: String) async throws {
        guard let userId = SupabaseManager.shared.currentUserID else {
            throw ReferralError.notFound
        }
        let clean = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !clean.isEmpty else { throw ReferralError.invalidCode }

        struct CodeRow: Decodable {
            let id: UUID
            let user_id: UUID
        }
        let owners: [CodeRow] = try await client
            .from("referral_codes")
            .select("id, user_id")
            .eq("code", value: clean)
            .limit(1)
            .execute()
            .value
        guard let owner = owners.first else { throw ReferralError.notFound }
        guard owner.user_id != userId else { throw ReferralError.selfReferral }

        struct InsertPayload: Encodable {
            let code_id: UUID
            let redeemer_id: UUID
            let code: String
        }
        do {
            try await client
                .from("referral_redemptions")
                .insert(InsertPayload(code_id: owner.id, redeemer_id: userId, code: clean))
                .execute()
        } catch {
            throw ReferralError.alreadyRedeemed
        }
    }

    // MARK: - Helpers

    private static func generateCode(length: Int = 7) -> String {
        let alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<length).compactMap { _ in alphabet.randomElement() })
    }
}
