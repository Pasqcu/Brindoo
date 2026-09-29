//
//  ErrorTextTests.swift
//  BrindooTests
//
//  Il testo nativo del server (in inglese) non deve arrivare a schermo;
//  le regole di Brindoo sì, tradotte.
//

import XCTest
import Supabase
@testable import Brindoo

final class ErrorTextTests: XCTestCase {

    func test_erroreNativoDelDatabase_usaLaFraseDellaSchermata() {
        let error = PostgrestError(code: "42501", message: "new row violates row-level security policy for table \"reviews\"")
        XCTAssertEqual(BrindooErrorText.message(for: error, fallback: "Impossibile salvare."), "Impossibile salvare.")
    }

    func test_regolaDiBrindoo_restaTradotta() {
        let error = PostgrestError(code: "42501", message: "Utente bloccato: non potete interagire")
        XCTAssertEqual(BrindooErrorText.message(for: error, fallback: "Impossibile salvare."),
                       "Non puoi interagire con questo utente.")
    }

    func test_erroreDellApp_mostraIlSuoTesto() {
        let error = BrindooServiceError.invalidInput("Voto non valido")
        XCTAssertEqual(BrindooErrorText.message(for: error, fallback: "Impossibile salvare."), "Voto non valido")
    }
}
