//
//  PriceParsingTests.swift
//  BrindooTests
//
//  Il prezzo è il numero attorno a cui gira tutta la trattativa e viene
//  scritto a mano, con la virgola all'italiana o con il punto. Qui si
//  fissa come va letto, perché un "1.200" interpretato come 1,20 sarebbe
//  un accordo sbagliato di mille euro.
//

import XCTest
@testable import Brindoo

final class PriceParsingTests: XCTestCase {

    // MARK: - Forme scritte all'italiana

    func test_virgolaSeparaICentesimi() {
        XCTAssertEqual(BrindooFormat.price(from: "250,50"), 250.50)
        XCTAssertEqual(BrindooFormat.price(from: "0,99"), 0.99)
    }

    func test_puntoDelleMigliaiaConVirgola() {
        XCTAssertEqual(BrindooFormat.price(from: "1.200,50"), 1200.50)
        XCTAssertEqual(BrindooFormat.price(from: "12.000,00"), 12000)
    }

    /// Un punto solo è ambiguo: decide quante cifre lo seguono.
    func test_puntoSingoloConTreCifreSonoMigliaia() {
        XCTAssertEqual(BrindooFormat.price(from: "1.200"), 1200)
        XCTAssertEqual(BrindooFormat.price(from: "15.000"), 15000)
    }

    func test_puntoSingoloConDueCifreSonoCentesimi() {
        XCTAssertEqual(BrindooFormat.price(from: "12.50"), 12.50)
        XCTAssertEqual(BrindooFormat.price(from: "250.5"), 250.5)
    }

    func test_piuPuntiSonoTuttiMigliaia() {
        XCTAssertEqual(BrindooFormat.price(from: "1.200.000"), 1_200_000 <= BrindooFormat.maxPrice ? 1_200_000 : nil)
    }

    // MARK: - Ripulitura

    func test_simboloEuroESpaziVengonoIgnorati() {
        XCTAssertEqual(BrindooFormat.price(from: " 350 € "), 350)
        XCTAssertEqual(BrindooFormat.price(from: "€350"), 350)
    }

    // MARK: - Valori rifiutati

    func test_zeroENegativiRifiutati() {
        XCTAssertNil(BrindooFormat.price(from: "0"))
        XCTAssertNil(BrindooFormat.price(from: "-100"))
    }

    func test_testoNonNumericoRifiutato() {
        XCTAssertNil(BrindooFormat.price(from: ""))
        XCTAssertNil(BrindooFormat.price(from: "prezzo"))
        XCTAssertNil(BrindooFormat.price(from: "  "))
    }

    /// Gli zeri battuti per sbaglio non devono diventare una proposta.
    func test_cifreAssurdeRifiutate() {
        XCTAssertNil(BrindooFormat.price(from: "999999999"))
        XCTAssertNotNil(BrindooFormat.price(from: "100000"), "il tetto stesso resta accettabile")
    }

    // MARK: - Andata e ritorno con la scrittura in euro

    func test_ilPrezzoScrittoDallAppSiRilegge() {
        for value in [50.0, 250.5, 1200.0, 99999.99] {
            let written = BrindooFormat.euro(value)
            let read = BrindooFormat.price(from: written)
            XCTAssertEqual(read ?? -1, value, accuracy: 0.001, "non rileggo «\(written)»")
        }
    }
}
