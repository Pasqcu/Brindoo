//
//  BrindooText.swift
//  Brindoo
//
//  Testi ricorrenti in un posto solo.
//
//  Perché: gli stessi messaggi erano scritti a mano decine di volte con
//  parole diverse ("Riprova.", "Riprova più tardi.", "Controlla la
//  connessione e riprova."), quindi l'app parlava in tre modi diversi
//  della stessa cosa. Qui si cambia una riga e cambia ovunque.
//
//  Restano fuori i testi unici di una singola schermata: accentrare quelli
//  renderebbe più difficile capire cosa si legge a video.
//

import Foundation

enum BrindooText {

    // MARK: - Nomi

    /// Iniziali per gli avatar: al massimo due lettere, "?" se manca il nome.
    /// Era ricopiata in tre punti, con esiti diversi sui nomi composti.
    static func initials(from name: String?) -> String {
        guard let name, !name.trimmingCharacters(in: .whitespaces).isEmpty else { return "?" }
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first?.uppercased() }.joined()
        return letters.isEmpty ? "?" : letters
    }

    // MARK: - Errori comuni

    /// Suggerimento standard sotto ogni errore di rete.
    static let retryHint = "Controlla la connessione e riprova."

    /// Errore quando manca la sessione (non dovrebbe capitare a schermo).
    static let loginRequired = "Devi essere loggato"

    /// BrindooText.loadError("le offerte"), "…le recensioni", …
    static func loadError(_ what: String) -> String {
        "Impossibile caricare \(what)"
    }

    /// "Impossibile salvare il profilo", "…la recensione", …
    static func saveError(_ what: String) -> String {
        "Impossibile salvare \(what)"
    }

    /// "Impossibile eliminare la foto", …
    static func deleteError(_ what: String) -> String {
        "Impossibile eliminare \(what)"
    }

    /// "Impossibile aggiornare l'offerta", …
    static func updateError(_ what: String) -> String {
        "Impossibile aggiornare \(what)"
    }

    // MARK: - Etichette ripetute

    static let wholeLazio = "Tutto il Lazio"
    static let reviews = "Recensioni"
    static let portfolio = "Portfolio"
    static let negotiations = "Trattative"
    static let featured = "In evidenza"
    static let receivedProposals = "Proposte ricevute"
    static let becomeProfessional = "Diventa Professionista"
    static let verifiedIdentity = "Identità verificata"
    static let invalidImage = "Immagine non valida"
    static let close = "Chiudi"
    static let cancel = "Annulla"
    static let retry = "Riprova"
}
