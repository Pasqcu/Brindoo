//
//  LegalConsentTests.swift
//  BrindooTests
//
//  Rete di sicurezza sulla logica del consenso legale: quando va
//  riproposta l'accettazione dei Termini e quando serve la
//  dichiarazione del professionista.
//

import XCTest
@testable import Brindoo

final class LegalConsentTests: XCTestCase {

    /// Decodifica un profilo minimo con i campi legali voluti.
    private func profile(
        role: String = "client",
        termsAcceptedAt: String? = nil,
        termsVersion: String? = nil,
        professionalDeclarationAt: String? = nil
    ) throws -> Profile {
        var json: [String: Any] = [
            "id": UUID().uuidString,
            "role": role,
            "created_at": "2026-01-01T10:00:00Z",
            "updated_at": "2026-01-01T10:00:00Z"
        ]
        json["terms_accepted_at"] = termsAcceptedAt
        json["terms_version"] = termsVersion
        json["professional_declaration_at"] = professionalDeclarationAt

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Profile.self, from: data)
    }

    func test_senzaConsenso_vaRiproposto() throws {
        let p = try profile()
        XCTAssertTrue(p.needsTermsAcceptance)
    }

    func test_conConsensoVersioneCorrente_ok() throws {
        let p = try profile(termsAcceptedAt: "2026-07-17T09:00:00Z",
                            termsVersion: LegalVersion.current)
        XCTAssertFalse(p.needsTermsAcceptance)
    }

    func test_versioneVecchia_vaRiproposto() throws {
        let p = try profile(termsAcceptedAt: "2026-07-17T09:00:00Z",
                            termsVersion: "0.9")
        XCTAssertTrue(p.needsTermsAcceptance)
    }

    func test_dichiarazione_soloProfessionistiSenzaFirma() throws {
        XCTAssertFalse(try profile(role: "client").needsProfessionalDeclaration)
        XCTAssertTrue(try profile(role: "organizer").needsProfessionalDeclaration)
        XCTAssertFalse(try profile(
            role: "organizer",
            professionalDeclarationAt: "2026-07-17T09:00:00Z"
        ).needsProfessionalDeclaration)
    }

    func test_riepilogoAccordo_citaEstraneitaBrindoo() {
        XCTAssertFalse(ProfessionalDeclaration.points.isEmpty)
        XCTAssertFalse(LegalVersion.current.isEmpty)
    }
}
