//
//  ProBenefits.swift
//  Brindoo
//
//  Cosa comprende Brindoo Pro, ruolo per ruolo.
//
//  L'abbonamento è uno solo, ma chi vende e chi compra non cercano la stessa
//  cosa: al professionista servono vetrina e strumenti, al cliente serve farsi
//  trovare dai professionisti giusti. Vendere a un cliente "portfolio 50 foto"
//  significa incassare per qualcosa che non userà mai.
//

import Foundation

/// Una riga della lista benefici mostrata nella paywall.
struct ProBenefit: Identifiable, Equatable {
    let icon: String
    let title: String
    let description: String

    var id: String { title }
}

enum ProBenefits {

    /// I benefici da mostrare a chi ha questo ruolo.
    static func list(for role: UserRole) -> [ProBenefit] {
        switch role {
        case .organizer: return organizer
        case .client:    return client
        }
    }

    /// Riassunto di una riga per la card in Impostazioni.
    static func shortPitch(for role: UserRole) -> String {
        switch role {
        case .organizer: return "Sblocca tutte le funzionalità"
        case .client:    return "Richieste illimitate e in evidenza"
        }
    }

    // MARK: - Professionista

    private static let organizer: [ProBenefit] = [
        ProBenefit(
            icon: "checkmark.seal.fill",
            title: "Badge Pro",
            description: "Sigillo di trust accanto al tuo nome ovunque"
        ),
        ProBenefit(
            icon: "infinity",
            title: "Offerte illimitate",
            description: "Pubblica tutti i pacchetti che vuoi (free: max 1)"
        ),
        ProBenefit(
            icon: "star.bubble.fill",
            title: "Priorità in bacheca",
            description: "Il tuo profilo e le tue offerte appaiono prima dei non-Pro"
        ),
        ProBenefit(
            icon: "beach.umbrella.fill",
            title: "Modalità vacanza",
            description: "Offerte nascoste e nuove proposte in pausa, il profilo resta visibile"
        ),
        ProBenefit(
            icon: "arrowshape.turn.up.left.fill",
            title: "Risposta automatica",
            description: "Quando sei assente, i clienti che ti scrivono ricevono un tuo messaggio"
        ),
        ProBenefit(
            icon: "chart.bar.fill",
            title: "Statistiche dettagliate",
            description: "Visite profilo, offerte, proposte e tempo medio risposta"
        ),
        ProBenefit(
            icon: "photo.on.rectangle.angled",
            title: "Portfolio fino a 50 foto",
            description: "Free: 5 foto. Pro: 50 foto."
        ),
        ProBenefit(
            icon: "app.gift",
            title: "Icona dorata",
            description: "Brindoo in oro sulla Home del tuo iPhone"
        )
    ]

    // MARK: - Cliente

    private static let client: [ProBenefit] = [
        ProBenefit(
            icon: "infinity",
            title: "Richieste illimitate",
            description: "Tieni aperte tutte le richieste che vuoi (free: max \(ClientRequestService.maxOpenRequestsFree))"
        ),
        ProBenefit(
            icon: "star.bubble.fill",
            title: "Richieste in evidenza",
            description: "Le tue richieste appaiono in cima a quelle che i professionisti sfogliano"
        ),
        ProBenefit(
            icon: "app.gift",
            title: "Icona dorata",
            description: "Brindoo in oro sulla Home del tuo iPhone"
        )
    ]
}
