//
//  BrindooErrorText.swift
//  Brindoo
//
//  Traduce un errore in una frase che ha senso leggere.
//
//  Prima diverse schermate mostravano `error.localizedDescription` così com'era:
//  a schermo finiva il messaggio tecnico del database o della rete, in inglese,
//  che non dice all'utente né cos'è successo né cosa può fare. Qui l'errore
//  passa da un filtro solo: se sa parlare italiano (LocalizedError nostro) si
//  usa la sua frase, se è un problema di rete si dice che manca la linea,
//  altrimenti si usa la frase di ripiego decisa dalla schermata.
//

import Foundation

/// Le cose che un servizio si rifiuta di fare, dette in italiano.
///
/// Prima erano una ventina di errori generici col solo codice 401 e nessun
/// messaggio: a schermo diventavano "The operation couldn't be completed.
/// (Msg error 401.)", cioè niente di utile per chi legge.
nonisolated enum BrindooServiceError: LocalizedError {
    /// Manca la sessione: non dovrebbe arrivare a schermo, l'app porta al login.
    case notLoggedIn
    /// La foto scelta non si è potuta leggere o comprimere.
    case invalidImage
    /// Un dato inserito non va bene, con la spiegazione del perché.
    case invalidInput(String)

    var errorDescription: String? {
        switch self {
        case .notLoggedIn: return BrindooText.loginRequired
        case .invalidImage: return BrindooText.invalidImage
        case .invalidInput(let reason): return reason
        }
    }
}

nonisolated enum BrindooErrorText {

    /// Frase da mostrare all'utente. `fallback` è quello che la schermata
    /// vuole dire quando dell'errore non si sa niente di utile.
    static func message(for error: Error, fallback: String) -> String {
        if isOffline(error) {
            return "Connessione assente. Controlla la rete e riprova."
        }
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription,
           !description.isEmpty {
            return description
        }
        return fallback
    }

    /// Vero se l'errore è "non c'è linea" e non un problema dell'app.
    static func isOffline(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost,
             .timedOut, .dataNotAllowed, .cannotFindHost, .cannotConnectToHost:
            return true
        default:
            return false
        }
    }

    /// Vero se l'operazione è stata annullata (la schermata è sparita mentre
    /// caricava, tipicamente). Non è un guasto: non va mostrato niente.
    static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        return false
    }

    /// Vero se il database ha rifiutato la scrittura perché quella riga c'è già
    /// (vincolo UNIQUE). Chi chiama decide se è un errore o un "l'avevi già fatto".
    static func isDuplicate(_ error: Error) -> Bool {
        let text = error.localizedDescription.lowercased()
        return text.contains("duplicate") || text.contains("unique") || text.contains("23505")
    }
}
