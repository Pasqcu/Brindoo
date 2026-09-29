//
//  ContentFilter.swift
//  Brindoo
//
//  Filtro delle parole offensive nei testi che tutti vedono (offerte,
//  richieste, profilo, recensioni, domande frequenti). La linea guida 1.2
//  dell'App Store chiede, per i contenuti degli utenti, anche "un modo per
//  filtrare il materiale offensivo" oltre a segnalazioni e blocchi.
//
//  Lista volutamente corta: solo insulti e volgarità che non hanno un
//  significato innocente. Restano fuori parole che sono anche cognomi o
//  luoghi (Troia, Bastardo, Negro...), perché bloccare una persona vera o un
//  paese è peggio che lasciar passare una parolaccia: per il resto ci sono
//  segnalazioni e moderazione. Si confrontano parole intere, senza
//  maiuscole né accenti, così "Scazzottata" o "Merdaiola" non scattano.
//

import Foundation

nonisolated enum ContentFilter {

    /// Frase mostrata sotto il campo quando il filtro scatta.
    static let message = "Il testo contiene parole offensive, che le regole di Brindoo non ammettono."

    private static let blockedWords: Set<String> = [
        // italiano
        "cazzo", "cazzi", "cazzone", "cazzoni",
        "coglione", "coglioni", "coglionazzo",
        "stronzo", "stronza", "stronzi", "stronze",
        "vaffanculo", "fanculo", "affanculo",
        "puttana", "puttane", "puttaniere",
        "mignotta", "mignotte", "zoccola", "zoccole",
        "merda", "merde", "merdoso", "merdosa",
        "frocio", "froci", "ricchione", "ricchioni",
        "troione", "pompinara",
        // inglese
        "fuck", "fucking", "fucker", "motherfucker",
        "shit", "bitch", "cunt", "whore", "slut",
        "nigger", "nigga", "faggot", "retard"
    ]

    /// Vero se uno dei testi contiene una parola della lista.
    static func containsBlockedWords(_ texts: String?...) -> Bool {
        texts.contains { text in
            guard let text, !text.isEmpty else { return false }
            let folded = text.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "it_IT")
            )
            let words = folded
                .split { !$0.isLetter }
                .map { String($0) }
            return words.contains { blockedWords.contains($0) }
        }
    }
}
