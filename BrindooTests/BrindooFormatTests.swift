//
//  BrindooFormatTests.swift
//  BrindooTests
//
//  Rete di sicurezza sui formattatori condivisi: prezzo, giorni
//  "yyyy-MM-dd" e date leggibili in italiano.
//

import XCTest
@testable import Brindoo

final class BrindooFormatTests: XCTestCase {

    // Lo spazio tra numero e € può essere uno spazio speciale (dipende dal
    // sistema): i controlli guardano contenuto, non byte per byte.
    func test_euro_interoSenzaDecimali() {
        let s = BrindooFormat.euro(450)
        XCTAssertTrue(s.contains("450") && s.contains("€"))
        XCTAssertFalse(s.contains(","))
    }

    func test_euro_conDecimaliSoloSeServono() {
        let s = BrindooFormat.euro(450.5)
        XCTAssertTrue(s.contains("450,50") && s.contains("€"))
    }

    func test_giorno_andataERitorno() {
        let date = BrindooFormat.day(from: "2026-09-12")
        XCTAssertNotNil(date)
        XCTAssertEqual(BrindooFormat.dayString(from: date!), "2026-09-12")
    }

    func test_giorno_formatoNonValido() {
        XCTAssertNil(BrindooFormat.day(from: "12/09/2026"))
        XCTAssertNil(BrindooFormat.day(from: ""))
    }

    func test_dataItaliana() {
        XCTAssertEqual(BrindooFormat.italianDate(fromDay: "2026-09-12"), "12 settembre 2026")
        XCTAssertNil(BrindooFormat.italianDate(fromDay: "non-una-data"))
    }

    func test_tempoRelativo_nonVuoto() {
        let past = Date().addingTimeInterval(-3600)
        XCTAssertFalse(BrindooFormat.timeAgo(past).isEmpty)
        XCTAssertFalse(BrindooFormat.timeAgoShort(past).isEmpty)
    }
}
