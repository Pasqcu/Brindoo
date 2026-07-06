//
//  BrindooApp.swift
//  Brindoo
//
//  Entry point dell'applicazione.
//  Configura l'ambiente globale e gestisce deep link + push notifications.
//

import SwiftUI
import UserNotifications

@main
struct BrindooApp: App {
    
    /// AppDelegate adapter per gestire callback APNs (push notifications).
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    /// Stato globale dell'app (sessione utente, profilo).
    @State private var session = SessionStore()

    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .preferredColorScheme(nil)
                .tint(.brindooCoral)
                .task {
                    // Se i permessi push sono già concessi, refresha il token
                    await NotificationService.shared.registerForRemoteNotificationsIfAuthorized()
                    // Carica catalogo IAP e verifica le subscription già attive
                    // (utile dopo restore o cambio device).
                    await PurchaseService.shared.loadProducts()
                    await PurchaseService.shared.refreshEntitlements()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    // Da loggati il numerino sull'icona è gestito da MainTabView
                    // (allineato a trattative e messaggi reali). Qui si azzera
                    // solo quando NON c'è una sessione, per non lasciare
                    // badge fantasma dopo un logout.
                    if newPhase == .active && session.authState != .signedIn {
                        Task { await NotificationService.shared.clearBadgeAndDeliveredNotifications() }
                    }
                }
                .onChange(of: session.authState) { _, newState in
                    Task {
                        if newState == .signedIn {
                            await NotificationService.shared.syncTokenAfterLogin()
                            // Sincronizza l'entitlement Pro sul nuovo account.
                            await PurchaseService.shared.refreshEntitlements()
                        }
                    }
                }
                .onOpenURL { url in
                    // Deep link in arrivo (conferma email, reset password, link condivisi)
                    print("📲 Deep link ricevuto: \(url.absoluteString)")
                    // Link condivisi di profilo/offerta (https://brindoo.app/p|o/<id>)
                    if DeepLinkRouter.shared.handleShareLink(url) { return }
                    Task {
                        await AuthService.shared.handleDeepLink(url)
                    }
                }
        }
    }
}
