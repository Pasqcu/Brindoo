//
//  ContentFilterTests.swift
//  BrindooTests
//
//  Il filtro dei testi pubblici deve fermare gli insulti veri e lasciar
//  passare le parole innocenti che li contengono o gli somigliano.
//

import XCTest
@testable import Brindoo

final class ContentFilterTests: XCTestCase {

    func test_insulto_bloccato_ancheConMaiuscoleEPunteggiatura() {
        XCTAssertTrue(ContentFilter.containsBlockedWords("Che STRONZO!"))
        XCTAssertTrue(ContentFilter.containsBlockedWords("ok", "vaffanculo."))
    }

    func test_parolaInnocenteCheContieneUnInsulto_passa() {
        XCTAssertFalse(ContentFilter.containsBlockedWords("Scazzottata finale e merdaiola di coriandoli"))
    }

    func test_cognomiELuoghi_passano() {
        XCTAssertFalse(ContentFilter.containsBlockedWords("Festa a Troia con Mario Bastardo"))
        XCTAssertFalse(ContentFilter.containsBlockedWords("Catering Negro & figli"))
    }

    func test_testiVuotiONulli_passano() {
        XCTAssertFalse(ContentFilter.containsBlockedWords(nil, "", "   "))
    }

    func test_testoNormale_passa() {
        XCTAssertFalse(ContentFilter.containsBlockedWords("Animazione per feste di compleanno a Latina"))
    }
}
