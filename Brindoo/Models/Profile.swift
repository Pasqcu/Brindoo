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

// MARK: - FAQ del professionista

/// Coppia domanda/risposta scritta dal professionista, visibile ai clienti
/// sul profilo. Massimo 5 per profilo.
struct ProfileFAQ: Codable, Hashable, Equatable, Identifiable {
    var question: String
    var answer: String

    var id: String { question + "|" + answer }

    static let maxCount = 5
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
    /// Tempo mediano di risposta in chat (minuti), auto-calcolato dall'app.
    let responseMinutes: Int?
    /// Domande frequenti scritte dal professionista (max 5).
    let faqs: [ProfileFAQ]
    /// True se l'amministrazione ha verificato l'identità del professionista.
    let identityVerified: Bool
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
        case responseMinutes = "response_minutes"
        case faqs
        case identityVerified = "identity_verified"
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
        responseMinutes = try c.decodeIfPresent(Int.self, forKey: .responseMinutes)
        faqs = try c.decodeIfPresent([ProfileFAQ].self, forKey: .faqs) ?? []
        identityVerified = try c.decodeIfPresent(Bool.self, forKey: .identityVerified) ?? false

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

    /// Encoding simmetrico al decoding (vacation_until come "yyyy-MM-dd"),
    /// così il profilo può essere salvato e riletto dalla cache locale.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(role, forKey: .role)
        try c.encodeIfPresent(fullName, forKey: .fullName)
        try c.encodeIfPresent(phone, forKey: .phone)
        try c.encodeIfPresent(city, forKey: .city)
        try c.encodeIfPresent(province?.rawValue, forKey: .province)
        try c.encode(coverageAreas, forKey: .coverageAreas)
        try c.encodeIfPresent(bio, forKey: .bio)
        try c.encodeIfPresent(avatarUrl, forKey: .avatarUrl)
        try c.encode(isPro, forKey: .isPro)
        try c.encodeIfPresent(proExpiresAt, forKey: .proExpiresAt)
        try c.encodeIfPresent(boostExpiresAt, forKey: .boostExpiresAt)
        try c.encode(readReceiptsEnabled, forKey: .readReceiptsEnabled)
        if let vacationUntil {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            fmt.timeZone = TimeZone(identifier: "UTC")
            try c.encode(fmt.string(from: vacationUntil), forKey: .vacationUntil)
        }
        try c.encodeIfPresent(responseMinutes, forKey: .responseMinutes)
        try c.encode(faqs, forKey: .faqs)
        try c.encode(identityVerified, forKey: .identityVerified)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
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

    /// Velocità di risposta in chat, se nota e ragionevole.
    var responseSpeed: ResponseSpeed? {
        ResponseSpeed(minutes: responseMinutes)
    }
}

// MARK: - Velocità di risposta

/// Fascia di velocità con cui il professionista risponde ai messaggi.
/// Oltre i 3 giorni non mostriamo nulla (meglio niente che un'etichetta negativa).
enum ResponseSpeed: Equatable {
    case withinHour
    case sameDay
    case fewDays

    init?(minutes: Int?) {
        guard let minutes, minutes >= 0 else { return nil }
        switch minutes {
        case ...60:          self = .withinHour
        case ...(24 * 60):   self = .sameDay
        case ...(3 * 24 * 60): self = .fewDays
        default:             return nil
        }
    }

    var label: String {
        switch self {
        case .withinHour: return "Risponde entro un'ora"
        case .sameDay:    return "Risponde in giornata"
        case .fewDays:    return "Risponde entro pochi giorni"
        }
    }

    var iconName: String {
        switch self {
        case .withinHour: return "bolt.fill"
        case .sameDay:    return "clock.badge.checkmark"
        case .fewDays:    return "clock"
        }
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
