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
    /// Flag `is_pro` come arriva dal server: cache comoda per le query, non
    /// fonte di verita'. Serve solo a non perderlo nel salvataggio locale;
    /// per sapere se l'abbonamento vale usa `isPro`, che guarda la scadenza.
    private let isProFlag: Bool
    let proExpiresAt: Date?
    /// Fine del periodo pagato ad Apple (abbonamento). La scrive solo il server.
    let iapProExpiresAt: Date?
    /// Fine dei mesi Pro regalati dal codice invito. La scrive solo il server.
    let bonusProExpiresAt: Date?
    let boostExpiresAt: Date?
    let readReceiptsEnabled: Bool
    /// Quali notifiche l'utente vuole ricevere (messaggi / trattative / promemoria).
    let notifyMessages: Bool
    let notifyNegotiations: Bool
    let notifyReminders: Bool
    /// Giorno in cui il professionista torna disponibile (non fa parte della vacanza).
    let vacationUntil: Date?
    /// Tempo mediano di risposta in chat (minuti), auto-calcolato dall'app.
    let responseMinutes: Int?
    /// Domande frequenti scritte dal professionista (max 5).
    let faqs: [ProfileFAQ]
    /// True se l'amministrazione ha verificato l'identità del professionista.
    let identityVerified: Bool
    /// Prova del consenso: quando e quale versione dei Termini è stata accettata.
    let termsAcceptedAt: Date?
    let termsVersion: String?
    /// Quando il professionista ha confermato la dichiarazione di responsabilità.
    let professionalDeclarationAt: Date?
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
        case isProFlag = "is_pro"
        case proExpiresAt = "pro_expires_at"
        case iapProExpiresAt = "iap_pro_expires_at"
        case bonusProExpiresAt = "bonus_pro_expires_at"
        case boostExpiresAt = "boost_expires_at"
        case readReceiptsEnabled = "read_receipts_enabled"
        case notifyMessages = "notify_messages"
        case notifyNegotiations = "notify_negotiations"
        case notifyReminders = "notify_reminders"
        case vacationUntil = "vacation_until"
        case responseMinutes = "response_minutes"
        case faqs
        case identityVerified = "identity_verified"
        case termsAcceptedAt = "terms_accepted_at"
        case termsVersion = "terms_version"
        case professionalDeclarationAt = "professional_declaration_at"
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
        isProFlag = try c.decodeIfPresent(Bool.self, forKey: .isProFlag) ?? false
        proExpiresAt = try c.decodeIfPresent(Date.self, forKey: .proExpiresAt)
        iapProExpiresAt = try c.decodeIfPresent(Date.self, forKey: .iapProExpiresAt)
        bonusProExpiresAt = try c.decodeIfPresent(Date.self, forKey: .bonusProExpiresAt)
        boostExpiresAt = try c.decodeIfPresent(Date.self, forKey: .boostExpiresAt)
        readReceiptsEnabled = try c.decodeIfPresent(Bool.self, forKey: .readReceiptsEnabled) ?? true
        // Assenti finché la migrazione non è applicata: si parte da "tutte attive".
        notifyMessages = try c.decodeIfPresent(Bool.self, forKey: .notifyMessages) ?? true
        notifyNegotiations = try c.decodeIfPresent(Bool.self, forKey: .notifyNegotiations) ?? true
        notifyReminders = try c.decodeIfPresent(Bool.self, forKey: .notifyReminders) ?? true
        responseMinutes = try c.decodeIfPresent(Int.self, forKey: .responseMinutes)
        faqs = try c.decodeIfPresent([ProfileFAQ].self, forKey: .faqs) ?? []
        identityVerified = try c.decodeIfPresent(Bool.self, forKey: .identityVerified) ?? false
        termsAcceptedAt = try c.decodeIfPresent(Date.self, forKey: .termsAcceptedAt)
        termsVersion = try c.decodeIfPresent(String.self, forKey: .termsVersion)
        professionalDeclarationAt = try c.decodeIfPresent(Date.self, forKey: .professionalDeclarationAt)

        // vacation_until è memorizzato come date (YYYY-MM-DD).
        if let dateString = try c.decodeIfPresent(String.self, forKey: .vacationUntil),
           !dateString.isEmpty {
            vacationUntil = BrindooFormat.day(from: dateString)
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
        try c.encode(isProFlag, forKey: .isProFlag)
        try c.encodeIfPresent(proExpiresAt, forKey: .proExpiresAt)
        try c.encodeIfPresent(iapProExpiresAt, forKey: .iapProExpiresAt)
        try c.encodeIfPresent(bonusProExpiresAt, forKey: .bonusProExpiresAt)
        try c.encodeIfPresent(boostExpiresAt, forKey: .boostExpiresAt)
        try c.encode(readReceiptsEnabled, forKey: .readReceiptsEnabled)
        try c.encode(notifyMessages, forKey: .notifyMessages)
        try c.encode(notifyNegotiations, forKey: .notifyNegotiations)
        try c.encode(notifyReminders, forKey: .notifyReminders)
        if let vacationUntil {
            try c.encode(BrindooFormat.dayString(from: vacationUntil), forKey: .vacationUntil)
        }
        try c.encodeIfPresent(responseMinutes, forKey: .responseMinutes)
        try c.encode(faqs, forKey: .faqs)
        try c.encode(identityVerified, forKey: .identityVerified)
        try c.encodeIfPresent(termsAcceptedAt, forKey: .termsAcceptedAt)
        try c.encodeIfPresent(termsVersion, forKey: .termsVersion)
        try c.encodeIfPresent(professionalDeclarationAt, forKey: .professionalDeclarationAt)
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

    /// True se l'abbonamento Pro è attivo adesso.
    ///
    /// Comanda la data, come per il boost, e come fa il database in
    /// `brindoo_is_pro`. Il flag `is_pro` non decade da solo — quando
    /// l'abbonamento scade nessuno riscrive la riga — quindi non si guarda:
    /// `pro_expires_at` e' l'unica colonna che solo il server puo' scrivere.
    var isPro: Bool {
        guard let proExpiresAt else { return false }
        return proExpiresAt > Date()
    }

    /// True se il periodo pagato ad Apple è ancora in corso.
    var hasPaidPro: Bool {
        guard let iapProExpiresAt else { return false }
        return iapProExpiresAt > Date()
    }

    /// True se il Pro di adesso viene solo dai mesi regalati (codice invito).
    var hasOnlyGiftedPro: Bool {
        isPro && !hasPaidPro
    }

    /// True quando ha senso mostrare il sigillo Pro accanto al nome.
    ///
    /// Il badge dice "professionista di fiducia": su un cliente abbonato non
    /// comunica niente, quindi non si mostra.
    var showsProBadge: Bool {
        isPro && role == .organizer
    }

    /// True se il boost è attualmente attivo
    var isBoosted: Bool {
        guard let boostExpiresAt else { return false }
        return boostExpiresAt > Date()
    }

    /// True quando il professionista è in vacanza adesso.
    var isOnVacation: Bool {
        isOnVacation(on: Date())
    }

    /// True se quel giorno cade nella vacanza. `vacationUntil` è il giorno
    /// del ritorno: da lì in poi il professionista è di nuovo prenotabile.
    /// Stessa regola del database (vista `service_offers_ranked`, trigger
    /// delle proposte).
    func isOnVacation(on day: Date) -> Bool {
        guard let vacationUntil else { return false }
        return BrindooFormat.startOfDay(day) < BrindooFormat.startOfDay(vacationUntil)
    }

    /// "21 maggio": giorno del ritorno, usato nei banner ("Torna disponibile dal…").
    var vacationUntilDisplay: String? {
        vacationUntil.map { BrindooFormat.italianDayMonth(from: $0) }
    }

    /// Oltre questo tempo senza farsi vedere, quello che sappiamo sulla
    /// velocità di risposta è un ricordo, non una promessa.
    static let responseSpeedFreshnessDays = 45

    /// Velocità di risposta in chat, se nota, ragionevole e ancora attuale.
    ///
    /// "Risponde entro un'ora" appiccicato a chi non apre l'app da mesi è
    /// una promessa che il cliente incassa e il professionista non mantiene:
    /// scaduta la freschezza si preferisce non dire niente.
    var responseSpeed: ResponseSpeed? {
        let days = Calendar.current.dateComponents([.day], from: updatedAt, to: Date()).day ?? 0
        guard days <= Self.responseSpeedFreshnessDays else { return nil }
        return ResponseSpeed(minutes: responseMinutes)
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
