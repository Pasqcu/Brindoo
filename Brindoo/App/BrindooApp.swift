//
//  BrindooApp.swift
//  Brindoo
//
//  Entry point dell'applicazione.
//  Configura l'ambiente globale e gestisce deep link + push notifications.
//

import SwiftUI

@main
struct BrindooApp: App {
    
    /// AppDelegate adapter per gestire callback APNs (push notifications).
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    /// Stato globale dell'app (sessione utente, profilo).
    @State private var session = SessionStore()
    
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
                    // Deep link in arrivo (es. conferma email, reset password)
                    print("📲 Deep link ricevuto: \(url.absoluteString)")
                    Task {
                        await AuthService.shared.handleDeepLink(url)
                    }
                }
        }
    }
}
