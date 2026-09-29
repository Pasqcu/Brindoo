//
//  AppLaunchGate.swift
//  Brindoo
//
//  Dice alla schermata di avvio quando la prima schermata è davvero pronta.
//  Senza questo la splash esce appena l'autenticazione risponde, e l'utente
//  vede la bacheca vuota per un istante prima che i dati arrivino di scatto.
//  Mette anche in fila i fogli che si aprono da soli al primo avvio.
//

import Foundation
import Observation

@MainActor
@Observable
final class AppLaunchGate {
    static let shared = AppLaunchGate()

    /// La prima schermata ha i suoi dati: la splash può uscire.
    private(set) var isFirstScreenReady: Bool = false

    /// Fogli che si aprono da soli al primo avvio.
    enum LaunchSheet {
        case welcome        // benvenuto del cliente, dalla bacheca
        case notifications  // spiegazione prima del dialogo iOS
    }

    /// Il foglio del primo avvio aperto adesso. Due insieme non reggono:
    /// SwiftUI chiudeva la spiegazione appena nata (dialogo iOS senza
    /// spiegazione) e il benvenuto passava per visto senza mai apparire.
    private(set) var launchSheet: LaunchSheet?

    private init() {}

    /// Chiamato quando la prima schermata ha finito di caricare, o quando non
    /// c'è nulla da aspettare (onboarding, setup profilo).
    func markFirstScreenReady() {
        guard !isFirstScreenReady else { return }
        isFirstScreenReady = true
    }

    /// Prenota il turno per aprire un foglio del primo avvio.
    /// Falso se ce n'è già uno aperto: si riprova quando si libera.
    func claimLaunchSheet(_ sheet: LaunchSheet) -> Bool {
        guard launchSheet == nil else { return launchSheet == sheet }
        launchSheet = sheet
        return true
    }

    /// Il foglio si è chiuso: tocca al prossimo.
    func releaseLaunchSheet(_ sheet: LaunchSheet) {
        if launchSheet == sheet { launchSheet = nil }
    }
}
