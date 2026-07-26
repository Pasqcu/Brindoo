//
//  ResponseSpeedFreshnessTests.swift
//  BrindooTests
//
//  "Risponde entro un'ora" è una promessa che il cliente incassa. Se resta
//  attaccata a un professionista che non si fa vedere da mesi, il cliente
//  scrive e non riceve niente. Qui si fissa la scadenza di quella promessa.
//

import XCTest
@testable import Brindoo

final class ResponseSpeedFreshnessTests: XCTestCase {

    private func makeProfile(responseMinutes: Int?, updatedDaysAgo: Int) throws -> Profile {
        let updated = Calendar.current.date(byAdding: .day, value: -updatedDaysAgo, to: Date())!
        let formatter = ISO8601DateFormatter()
        var json: [String: Any] = [
            "id": UUID().uuidString,
            "role": "organizer",
            "full_name": "Studio Rossi",
            "created_at": formatter.string(from: updated),
            "updated_at": formatter.string(from: updated)
        ]
        if let responseMinutes { json["response_minutes"] = responseMinutes }

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Profile.self, from: data)
    }

    func test_datoRecenteMostraLaVelocita() throws {
        let profile = try makeProfile(responseMinutes: 30, updatedDaysAgo: 3)
        XCTAssertEqual(profile.responseSpeed, .withinHour)
    }

    func test_datoVecchioNonPromettePiuNiente() throws {
        let profile = try makeProfile(responseMinutes: 30, updatedDaysAgo: 120)
        XCTAssertNil(profile.responseSpeed, "un professionista sparito non può promettere un'ora")
    }

    /// Il giorno esatto della soglia vale ancora: si toglie solo dopo.
    func test_limiteDellaFreschezza() throws {
        let dentro = try makeProfile(responseMinutes: 30, updatedDaysAgo: Profile.responseSpeedFreshnessDays)
        let fuori = try makeProfile(responseMinutes: 30, updatedDaysAgo: Profile.responseSpeedFreshnessDays + 1)
        XCTAssertNotNil(dentro.responseSpeed)
        XCTAssertNil(fuori.responseSpeed)
    }

    func test_senzaDatoNonSiInventaNulla() throws {
        let profile = try makeProfile(responseMinutes: nil, updatedDaysAgo: 1)
        XCTAssertNil(profile.responseSpeed)
    }

    /// Oltre i tre giorni non si mostra un'etichetta negativa: meglio tacere.
    func test_rispostaTroppoLentaNonSiMostra() throws {
        let profile = try makeProfile(responseMinutes: 10 * 24 * 60, updatedDaysAgo: 1)
        XCTAssertNil(profile.responseSpeed)
    }
}
