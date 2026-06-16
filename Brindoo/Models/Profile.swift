//
//  Profile.swift
//  Brindoo
//
//  Modello utente (cliente o organizzatore).
//

import Foundation

// MARK: - Ruolo utente

enum UserRole: String, Codable, CaseIterable, Identifiable {
    case client
    case organizer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .client: return "Cliente"
        case .organizer: return "Professionista"
        }
    }

    /// Icona SF Symbols associata al ruolo (usata in ProfileSetupView)
    var iconName: String {
        switch self {
        case .client: return "magnifyingglass"
        case .organizer: return "sparkles"
        }
    }

    /// Descrizione mostrata in fase di onboarding
    var description: String {
        switch self {
        case .client:
            return "Sfoglia i professionisti, confronta le offerte e contatta quello giusto in pochi tap."
        case .organizer:
            return "Pubblica i tuoi servizi in bacheca e fatti scegliere dai clienti."
        }
    }
}

// MARK: - Profilo

struct Profile: Identifiable, Codable, Hashable, Equatable {
    let id: UUID
    let role: UserRole
    let fullName: String?
    let phone: String?
    let city: String?
    let province: LazioProvince?
    let coverageAreas: [String]
    let bio: String?
    let avatarUrl: String?
    let isPro: Bool
    let proExpiresAt: Date?
    let boostExpiresAt: Date?
    let readReceiptsEnabled: Bool
    let vacationUntil: Date?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case role
        case fullName = "full_name"
        case phone
        case city
        case province
        case coverageAreas = "coverage_areas"
        case bio
        case avatarUrl = "avatar_url"
        case isPro = "is_pro"
        case proExpiresAt = "pro_expires_at"
        case boostExpiresAt = "boost_expires_at"
        case readReceiptsEnabled = "read_receipts_enabled"
        case vacationUntil = "vacation_until"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        role = try c.decode(UserRole.self, forKey: .role)
        fullName = try c.decodeIfPresent(String.self, forKey: .fullName)
        phone = try c.decodeIfPresent(String.self, forKey: .phone)
        city = try c.decodeIfPresent(String.self, forKey: .city)
        province = try c.decodeIfPresent(String.self, forKey: .province).flatMap(LazioProvince.init(rawValue:))
        coverageAreas = try c.decodeIfPresent([String].self, forKey: .coverageAreas) ?? []
        bio = try c.decodeIfPresent(String.self, forKey: .bio)
        avatarUrl = try c.decodeIfPresent(String.self, forKey: .avatarUrl)
        isPro = try c.decodeIfPresent(Bool.self, forKey: .isPro) ?? false
        proExpiresAt = try c.decodeIfPresent(Date.self, forKey: .proExpiresAt)
        boostExpiresAt = try c.decodeIfPresent(Date.self, forKey: .boostExpiresAt)
        readReceiptsEnabled = try c.decodeIfPresent(Bool.self, forKey: .readReceiptsEnabled) ?? true

        // vacation_until è memorizzato come date (YYYY-MM-DD).
        if let dateString = try c.decodeIfPresent(String.self, forKey: .vacationUntil),
           !dateString.isEmpty {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            fmt.timeZone = TimeZone(identifier: "UTC")
            vacationUntil = fmt.date(from: dateString)
        } else {
            vacationUntil = nil
        }

        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
    }

    /// True quando il profilo ha i campi minimi compilati (nome + città + provincia).
    var isComplete: Bool {
        guard let fullName, !fullName.trimmingCharacters(in: .whitespaces).isEmpty else {
            return false
        }
        guard let city, !city.trimmingCharacters(in: .whitespaces).isEmpty else {
            return false
        }
        return province != nil
    }

    /// True se il profilo è geograficamente a Roma (città).
    var isInRome: Bool {
        guard let city else { return false }
        return CityValidator.isRome(city)
    }

    /// Etichetta delle aree di copertura per le card della bacheca.
    var coverageAreasDisplay: String {
        LazioArea.displayLabel(forSlugs: coverageAreas)
    }

    /// True se il boost è attualmente attivo
    var isBoosted: Bool {
        guard let boostExpiresAt else { return false }
        return boostExpiresAt > Date()
    }

    /// True quando l'organizzatore è in vacanza adesso.
    var isOnVacation: Bool {
        guard let vacationUntil else { return false }
        return vacationUntil >= Calendar.current.startOfDay(for: Date())
    }

    /// "Fino al 21 maggio" — usato nei banner.
    var vacationUntilDisplay: String? {
        guard let vacationUntil else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "d MMMM"
        return f.string(from: vacationUntil)
    }
}

// MARK: - Payload di aggiornamento profilo

/// Struttura usata per aggiornare il profilo in un colpo solo (es. setup iniziale).
struct ProfileUpdate {
    let role: UserRole
    let fullName: String
    let phone: String?
    let city: String
    let province: LazioProvince
    let bio: String?
}
