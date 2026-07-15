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
    /// Oltre al registro di sistema, la riga finisce nell'archivio su file
    /// usato dal rapporto diagnostico (Impostazioni → Assistenza).
    static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        BrindooLogStore.shared.append(message)
        #if DEBUG
        print("[errore] \(message)")
        #endif
    }
}
