//
//  BrindooLog.swift
//  Brindoo
//
//  Punto unico per registrare gli errori.
//  In sviluppo stampa in console; in produzione passa dal registro
//  di sistema (visibile in Console.app), senza print sparsi.
//

import Foundation
import os

enum BrindooLog {

    private static let logger = Logger(subsystem: "com.pasqcu.brindoo", category: "app")

    /// Registra un errore non bloccante (l'utente riceve feedback altrove, se serve).
    static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        #if DEBUG
        print("[errore] \(message)")
        #endif
    }
}
