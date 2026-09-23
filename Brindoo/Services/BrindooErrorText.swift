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
        if let rule = serverRule(error) {
            return rule
        }
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription,
           !description.isEmpty {
            return description
        }
        return fallback
    }

    /// Rifiuti delle regole del database (trigger `brindoo_guard_*`,
    /// limiti, inviti), tradotti in una frase per l'utente. `nil` quando
    /// l'errore non è uno di questi. Se cambia un testo SQL, cambia anche qui.
    static func serverRule(_ error: Error) -> String? {
        let text = "\(error)"
        return serverRules.first { text.contains($0.needle) }?.message
    }

    private static let serverRules: [(needle: String, message: String)] = [
        ("Utente bloccato", "Non puoi interagire con questo utente."),
        ("e' in vacanza", "Il professionista è in vacanza: potrai contattarlo quando torna disponibile."),
        ("Data occupata", "Il professionista ha già un evento confermato in quella data."),
        ("segnare svolto", "Potrai segnarlo come svolto dal giorno dell'evento."),
        ("Tocca all'altra parte", "Tocca all'altra parte rispondere: aggiorna la trattativa."),
        ("gia' chiusa", "Questa trattativa è già chiusa: aggiorna la schermata."),
        ("gia' chiuso", "Questo appuntamento è già chiuso: aggiorna la schermata."),
        ("data di questa richiesta", "La data di questa richiesta è passata: pubblicane una nuova."),
        ("non puoi usare il tuo codice", "Non puoi usare il tuo stesso codice."),
        ("30 giorni dall", "Il codice invito si usa entro 30 giorni dall'iscrizione."),
        ("Puoi rispondere solo", "Puoi rispondere solo alle recensioni che hai ricevuto."),
    ]

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
