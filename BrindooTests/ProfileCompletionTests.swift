//
//  ProfileCompletionTests.swift
//  BrindooTests
//
//  Rete di sicurezza sulla logica "profilo completo al X%".
//

import XCTest
@testable import Brindoo

final class ProfileCompletionTests: XCTestCase {

    private func completion(
        hasAvatar: Bool = false,
        bioLength: Int = 0,
        categoriesCount: Int = 0,
        portfolioCount: Int = 0,
        activeOffersCount: Int = 0,
        coverageAreasCount: Int = 0
    ) -> ProfileCompletion {
        ProfileCompletion.evaluate(
            hasAvatar: hasAvatar,
            bioLength: bioLength,
            categoriesCount: categoriesCount,
            portfolioCount: portfolioCount,
            activeOffersCount: activeOffersCount,
            coverageAreasCount: coverageAreasCount
        )
    }

    func test_profiloVuoto_puntoZero() {
        let c = completion()
        XCTAssertEqual(c.score, 0)
        XCTAssertFalse(c.isComplete)
        XCTAssertNotNil(c.nextSuggestion)
    }

    func test_profiloCompleto_cento() {
        let c = completion(
            hasAvatar: true, bioLength: 80, categoriesCount: 2,
            portfolioCount: 5, activeOffersCount: 1, coverageAreasCount: 3
        )
        XCTAssertEqual(c.score, 100)
        XCTAssertTrue(c.isComplete)
        XCTAssertNil(c.nextSuggestion)
    }

    func test_bioTroppoCorta_nonConta() {
        let corta = completion(bioLength: 10)
        let lunga = completion(bioLength: 30)
        XCTAssertLessThan(corta.score, lunga.score)
    }

    func test_portfolioSottoTreFoto_nonConta() {
        XCTAssertEqual(completion(portfolioCount: 2).score, completion().score)
        XCTAssertGreaterThan(completion(portfolioCount: 3).score, completion().score)
    }

    func test_suggerimento_prioritaAlPesoMaggiore() {
        // Mancano solo avatar (peso 15) e categorie (peso 20):
        // il suggerimento deve puntare alle categorie.
        let c = completion(
            hasAvatar: false, bioLength: 50, categoriesCount: 0,
            portfolioCount: 4, activeOffersCount: 2, coverageAreasCount: 1
        )
        XCTAssertEqual(c.nextSuggestion, "Scegli le categorie dei tuoi servizi per farti trovare")
    }

    func test_punteggioSempreTraZeroECento() {
        let c = completion(hasAvatar: true, bioLength: 999, categoriesCount: 99,
                           portfolioCount: 99, activeOffersCount: 99, coverageAreasCount: 99)
        XCTAssertLessThanOrEqual(c.score, 100)
        XCTAssertGreaterThanOrEqual(completion().score, 0)
    }
}
