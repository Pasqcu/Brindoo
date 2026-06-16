//
//  ProfessionalOnboardingHint.swift
//  Brindoo
//
//  Flag locale per tracciare se un cliente è appena passato a Professionista
//  e deve ancora completare le categorie/portfolio.
//  Si auto-disattiva quando l'organizer ha almeno una categoria associata.
//

import Foundation

enum ProfessionalOnboardingHint {

    private static let key = "brindoo.pro.onboarding.pending"

    /// True se l'utente è appena passato a Professionista e non ha ancora
    /// compilato categorie/descrizione.
    static var isPending: Bool {
        UserDefaults.standard.bool(forKey: key)
    }

    static func markPendingCompletion() {
        UserDefaults.standard.set(true, forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
