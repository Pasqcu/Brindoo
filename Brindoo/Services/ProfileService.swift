//
//  ProfileService.swift
//  Brindoo
//
//  Service per leggere/scrivere il profilo utente in Supabase.
//

import Foundation
import Supabase

@MainActor
final class ProfileService {

    static let shared = ProfileService()
    private init() {}

    private var client: SupabaseClient {
        SupabaseManager.shared.client
    }

    // MARK: - Fetch

    func fetchProfile(userID: UUID) async throws -> Profile? {
        let result: [Profile] = try await client
            .from("profiles")
            .select()
            .eq("id", value: userID)
            .limit(1)
            .execute()
            .value
        return result.first
    }

    func fetchCurrentProfile() async throws -> Profile? {
        guard let userID = SupabaseManager.shared.currentUserID else { return nil }
        return try await fetchProfile(userID: userID)
    }

    /// Più profili per id, in un'unica richiesta.
    func fetchProfiles(ids: [UUID]) async throws -> [Profile] {
        guard !ids.isEmpty else { return [] }
        return try await client
            .from("profiles")
            .select()
            .in("id", values: ids.map { $0.uuidString })
            .execute()
            .value
    }

    // MARK: - Creazione

    /// Crea il profilo dell'utente loggato se non esiste ancora.
    @discardableResult
    func createProfileIfNeeded(role: UserRole = .client) async throws -> Profile {
        guard let userID = SupabaseManager.shared.currentUserID else {
            throw NSError(
                domain: "ProfileService",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Devi essere loggato"]
            )
        }

        if let existing = try await fetchProfile(userID: userID) {
            return existing
        }

        struct NewProfile: Encodable {
            let id: UUID
            let role: String
        }

        let newProfile = NewProfile(id: userID, role: role.rawValue)

        let profile: Profile = try await client
            .from("profiles")
            .insert(newProfile)
            .select()
            .single()
            .execute()
            .value

        print("✅ Profilo creato: \(profile.id)")
        return profile
    }

    // MARK: - Update profilo

    /// Aggiornamento completo via `ProfileUpdate` (usato in ProfileSetupView).
    @discardableResult
    func updateCurrentProfile(_ update: ProfileUpdate) async throws -> Profile {
        guard let userID = SupabaseManager.shared.currentUserID else {
            throw NSError(domain: "ProfileService", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Devi essere loggato"])
        }

        struct Payload: Encodable {
            let role: String
            let full_name: String
            let phone: String?
            let city: String
            let province: String
            let bio: String?
        }

        let payload = Payload(
            role: update.role.rawValue,
            full_name: update.fullName,
            phone: update.phone,
            city: update.city,
            province: update.province.rawValue,
            bio: update.bio
        )

        let profile: Profile = try await client
            .from("profiles")
            .update(payload)
            .eq("id", value: userID)
            .select()
            .single()
            .execute()
            .value

        return profile
    }

    /// Aggiornamento ruolo
    func setRole(_ role: UserRole) async throws -> Profile {
        guard let userID = SupabaseManager.shared.currentUserID else {
            throw NSError(domain: "Profile", code: 401)
        }
        struct Payload: Encodable { let role: String }
        return try await client
            .from("profiles")
            .update(Payload(role: role.rawValue))
            .eq("id", value: userID)
            .select()
            .single()
            .execute()
            .value
    }

    /// Aggiornamento con avatar (usato in EditProfileView)
    @discardableResult
    func updateProfileWithAvatar(
        fullName: String,
        phone: String,
        city: String,
        province: LazioProvince,
        bio: String,
        avatarUrl: String?
    ) async throws -> Profile {
        guard let userID = SupabaseManager.shared.currentUserID else {
            throw NSError(domain: "Profile", code: 401)
        }

        struct Payload: Encodable {
            let full_name: String
            let phone: String
            let city: String
            let province: String
            let bio: String
            let avatar_url: String?
        }

        let payload = Payload(
            full_name: fullName,
            phone: phone,
            city: city,
            province: province.rawValue,
            bio: bio,
            avatar_url: avatarUrl
        )

        return try await client
            .from("profiles")
            .update(payload)
            .eq("id", value: userID)
            .select()
            .single()
            .execute()
            .value
    }

    /// Aggiornamento aree di copertura (organizer). Array vuoto = "ovunque nel Lazio".
    @discardableResult
    func updateCoverageAreas(_ slugs: [String]) async throws -> Profile {
        guard let userID = SupabaseManager.shared.currentUserID else {
            throw NSError(domain: "Profile", code: 401)
        }
        struct Payload: Encodable { let coverage_areas: [String] }
        return try await client
            .from("profiles")
            .update(Payload(coverage_areas: slugs))
            .eq("id", value: userID)
            .select()
            .single()
            .execute()
            .value
    }

    /// Aggiornamento read receipts
    func updateReadReceipts(enabled: Bool) async throws {
        guard let userID = SupabaseManager.shared.currentUserID else { return }
        struct Payload: Encodable { let read_receipts_enabled: Bool }
        try await client
            .from("profiles")
            .update(Payload(read_receipts_enabled: enabled))
            .eq("id", value: userID)
            .execute()
    }

    /// Aggiornamento stato Pro
    func updateProStatus(isPro: Bool, expiresAt: Date?) async throws {
        guard let userID = SupabaseManager.shared.currentUserID else { return }
        struct Payload: Encodable {
            let is_pro: Bool
            let pro_expires_at: String?
        }
        let expStr = expiresAt.map { ISO8601DateFormatter().string(from: $0) }
        try await client
            .from("profiles")
            .update(Payload(is_pro: isPro, pro_expires_at: expStr))
            .eq("id", value: userID)
            .execute()
    }

    /// Aggiornamento stato Boost
    func updateBoostStatus(expiresAt: Date) async throws {
        guard let userID = SupabaseManager.shared.currentUserID else { return }
        struct Payload: Encodable { let boost_expires_at: String }
        try await client
            .from("profiles")
            .update(Payload(boost_expires_at: ISO8601DateFormatter().string(from: expiresAt)))
            .eq("id", value: userID)
            .execute()
    }

    // MARK: - Vacation mode

    /// Imposta o rimuove la modalità vacanza per l'utente corrente.
    /// `until` nullo = nessuna vacanza in corso.
    func setVacation(until: Date?) async throws {
        guard let userID = SupabaseManager.shared.currentUserID else { return }

        let dateString: String? = until.map { date in
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            fmt.timeZone = TimeZone(identifier: "UTC")
            return fmt.string(from: date)
        }

        // Usa NullableColumnUpdate per garantire che `vacation_until: null`
        // arrivi davvero al DB (il sintetizzato di Encodable ometterebbe la
        // chiave quando il valore è nil, lasciando la colonna invariata).
        try await client
            .from("profiles")
            .update(NullableColumnUpdate(column: "vacation_until", value: dateString))
            .eq("id", value: userID)
            .execute()
    }

}
