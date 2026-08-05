//
//  AppLaunchGate.swift
//  Brindoo
//
//  Dice alla schermata di avvio quando la prima schermata è davvero pronta.
//  Senza questo la splash esce appena l'autenticazione risponde, e l'utente
//  vede la bacheca vuota per un istante prima che i dati arrivino di scatto.
//

import Foundation
import Observation

@MainActor
@Observable
final class AppLaunchGate {
    static let shared = AppLaunchGate()

    /// La prima schermata ha i suoi dati: la splash può uscire.
    private(set) var isFirstScreenReady: Bool = false

    private init() {}

    /// Chiamato quando la prima schermata ha finito di caricare, o quando non
    /// c'è nulla da aspettare (onboarding, setup profilo).
    func markFirstScreenReady() {
        guard !isFirstScreenReady else { return }
        isFirstScreenReady = true
    }
}
