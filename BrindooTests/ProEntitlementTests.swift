//
//  ProEntitlementTests.swift
//  BrindooTests
//
//  L'abbonamento Pro e il ruolo sono due cose diverse, e qui si tiene fermo
//  il confine: un mese pagato non vale a vita, e il sigillo "professionista
//  di fiducia" non finisce addosso a chi compra invece di vendere.
//

import XCTest
@testable import Brindoo

@MainActor
final class ProEntitlementTests: XCTestCase {

    private func makeProfile(
        role: String,
        isPro: Bool,
        proExpiresInDays: Int?
    ) throws -> Profile {
        let formatter = ISO8601DateFormatter()
        let now = Date()

        var json: [String: Any] = [
            "id": UUID().uuidString,
            "role": role,
            "full_name": "Prova",
            "is_pro": isPro,
            "created_at": formatter.string(from: now),
            "updated_at": formatter.string(from: now)
        ]
        if let proExpiresInDays {
            let expiry = now.addingTimeInterval(Double(proExpiresInDays) * 86_400)
            json["pro_expires_at"] = formatter.string(from: expiry)
        }

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Profile.self, from: data)
    }

    // MARK: - Scadenza

    func test_abbonamentoAttivoVale() throws {
        let profile = try makeProfile(role: "organizer", isPro: true, proExpiresInDays: 10)
        XCTAssertTrue(profile.isPro)
    }

    /// Il caso che regalava i vantaggi a vita: il server lascia il flag acceso
    /// perche' nessuno riscrive la riga, ma la data e' passata.
    func test_flagAccesoConDataPassataNonVale() throws {
        let profile = try makeProfile(role: "organizer", isPro: true, proExpiresInDays: -1)
        XCTAssertFalse(profile.isPro, "un abbonamento scaduto non puo' restare attivo")
    }

    func test_senzaDataNonEPro() throws {
        let profile = try makeProfile(role: "organizer", isPro: true, proExpiresInDays: nil)
        XCTAssertFalse(profile.isPro, "senza scadenza non c'e' abbonamento da onorare")
    }

    // MARK: - Badge

    func test_ilBadgeEDelProfessionista() throws {
        let organizer = try makeProfile(role: "organizer", isPro: true, proExpiresInDays: 10)
        XCTAssertTrue(organizer.showsProBadge)
    }

    func test_ilClienteProNonMostraIlBadge() throws {
        let client = try makeProfile(role: "client", isPro: true, proExpiresInDays: 10)
        XCTAssertTrue(client.isPro, "il cliente e' abbonato davvero")
        XCTAssertFalse(client.showsProBadge, "ma il sigillo di trust non lo riguarda")
    }

    func test_professionistaScadutoPerdeIlBadge() throws {
        let organizer = try makeProfile(role: "organizer", isPro: true, proExpiresInDays: -3)
        XCTAssertFalse(organizer.showsProBadge)
    }

    // MARK: - Benefici per ruolo

    func test_iDueRuoliVedonoListeDiverse() {
        let organizer = ProBenefits.list(for: .organizer)
        let client = ProBenefits.list(for: .client)

        XCTAssertFalse(organizer.isEmpty)
        XCTAssertFalse(client.isEmpty)
        XCTAssertNotEqual(organizer, client)
    }

    /// Vendere "portfolio 50 foto" a chi non ha un portfolio era il difetto di
    /// partenza: nessun beneficio da professionista deve finire nella lista cliente.
    func test_alClienteNonSiVendonoIVantaggiDelProfessionista() {
        let clientTitles = Set(ProBenefits.list(for: .client).map(\.title))
        let organizerOnly = ["Badge Pro", "Modalità vacanza", "Statistiche dettagliate",
                             "Portfolio fino a 50 foto", "Offerte illimitate"]

        for title in organizerOnly {
            XCTAssertFalse(clientTitles.contains(title), "«\(title)» non riguarda un cliente")
        }
    }

    // MARK: - Rifiuti che arrivano dal database

    /// Finto errore Postgres: quello vero porta il testo del trigger dentro
    /// la propria descrizione, ed e' li' che il traduttore va a leggere.
    private struct FakeServerError: Error {
        let message: String
    }

    func test_ilLimiteOfferteDelServerDiventaUnErrorePerLaPaywall() {
        let error = FakeServerError(
            message: "Il piano gratuito permette 1 offerta attiva: passa a Brindoo Pro per averne quante vuoi"
        )
        guard case .maxOffersReached? = BrindooLimitError.fromServer(error) else {
            return XCTFail("il rifiuto del database non e' stato riconosciuto")
        }
    }

    func test_ilLimiteRichiesteDelServerDiventaUnErrorePerLaPaywall() {
        let error = FakeServerError(
            message: "Il piano gratuito permette 2 richieste aperte: passa a Brindoo Pro per averne quante vuoi"
        )
        guard case .maxClientRequestsReached(let max)? = BrindooLimitError.fromServer(error) else {
            return XCTFail("il rifiuto del database non e' stato riconosciuto")
        }
        XCTAssertEqual(max, ClientRequestService.maxOpenRequestsFree)
    }

    func test_ilLimitePortfolioDelServerDiventaUnErrorePerLaPaywall() {
        let error = FakeServerError(
            message: "Il piano gratuito permette 5 foto nel portfolio: passa a Brindoo Pro per averne fino a 50"
        )
        guard case .maxPortfolioReached(let max)? = BrindooLimitError.fromServer(error) else {
            return XCTFail("il rifiuto del database non e' stato riconosciuto")
        }
        XCTAssertEqual(max, PortfolioService.maxPhotosFree)
    }

    /// Un guasto di rete non e' un limite: non deve aprire la paywall.
    func test_unErroreQualsiasiRestaQuelloCheE() {
        let error = URLError(.notConnectedToInternet)
        XCTAssertNil(BrindooLimitError.fromServer(error))
        XCTAssertTrue(BrindooLimitError.mapping(error) is URLError)
    }
}
