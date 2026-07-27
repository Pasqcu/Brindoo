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

    // MARK: - Giorni evento
    //
    // Il giorno di una festa non deve dipendere da dove si trova il telefono:
    // scritto, riletto e confrontato con "oggi" deve restare lo stesso.

    func test_giorno_stessoCalendarioInLetturaEScrittura() {
        for day in ["2026-01-01", "2026-06-15", "2026-12-31"] {
            let date = BrindooFormat.day(from: day)
            XCTAssertNotNil(date, day)
            XCTAssertEqual(BrindooFormat.dayString(from: date!), day)
        }
    }

    func test_giornoPassato_ieriSiOggiNo() {
        let oggi = BrindooFormat.todayString
        XCTAssertFalse(BrindooFormat.isPastDay(oggi), "oggi non è passato")

        let ieri = BrindooFormat.dayCalendar.date(
            byAdding: .day, value: -1, to: BrindooFormat.startOfDay()
        )!
        XCTAssertTrue(BrindooFormat.isPastDay(BrindooFormat.dayString(from: ieri)))

        let domani = BrindooFormat.dayCalendar.date(
            byAdding: .day, value: 1, to: BrindooFormat.startOfDay()
        )!
        XCTAssertFalse(BrindooFormat.isPastDay(BrindooFormat.dayString(from: domani)))
    }

    func test_giorniMancanti() {
        let fraTreGiorni = BrindooFormat.dayCalendar.date(
            byAdding: .day, value: 3, to: BrindooFormat.startOfDay()
        )!
        XCTAssertEqual(
            BrindooFormat.daysUntil(day: BrindooFormat.dayString(from: fraTreGiorni)), 3
        )
        XCTAssertEqual(BrindooFormat.daysUntil(day: BrindooFormat.todayString), 0)
        XCTAssertNil(BrindooFormat.daysUntil(day: "non-una-data"))
    }

    func test_oraLegale_ilGiornoNonScivola() {
        // Passaggio all'ora legale in Italia: 29 marzo 2026.
        for day in ["2026-03-28", "2026-03-29", "2026-03-30", "2026-10-25"] {
            let date = BrindooFormat.day(from: day)!
            XCTAssertEqual(BrindooFormat.dayString(from: date), day)
            XCTAssertNotNil(BrindooFormat.italianDate(fromDay: day))
        }
    }

    func test_tempoRelativo_nonVuoto() {
        let past = Date().addingTimeInterval(-3600)
        XCTAssertFalse(BrindooFormat.timeAgo(past).isEmpty)
        XCTAssertFalse(BrindooFormat.timeAgoShort(past).isEmpty)
    }
}
