//
//  AppDelegate.swift
//  Brindoo
//
//  AppDelegate per gestire i callback di sistema legati alle push notifications.
//  Si integra con SwiftUI tramite @UIApplicationDelegateAdaptor in BrindooApp.
//
//  È l'UNICO delegate di UNUserNotificationCenter dell'app (NotificationService
//  delega tutta la parte UI a questa classe).
//

import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {

    /// Deep link memorizzato quando l'utente tocca una notifica da app chiusa.
    /// DeepLinkRouter lo legge all'avvio.
    static var pendingDeepLink: NotificationPayload?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Imposta il delegate del centro notifiche per gestire foreground / tap
        UNUserNotificationCenter.current().delegate = self
        // Registra le categorie di notifiche con azioni rapide (rispondi, accetta, ecc.)
        NotificationCategoriesRegistrar.registerCategories()
        return true
    }

    // MARK: - APNs Token

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            await NotificationService.shared.saveDeviceToken(deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            NotificationService.shared.handleRegistrationFailure(error)
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {

    /// Notifica ricevuta mentre l'app è in foreground:
    /// la mostriamo come banner con suono. Niente `.badge`: applicherebbe
    /// all'icona il numero della push anche se l'utente sta già leggendo
    /// in-app, lasciando un "1" fantasma quando esce. Il numerino sull'icona
    /// è gestito da MainTabView, allineato alle cose realmente da gestire.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound, .list]
    }

    /// L'utente ha toccato una notifica → naviga alla schermata corrispondente
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        // Le azioni rapide (rispondi inline, accetta offerta, ecc.) sono gestite
        // qui. Se l'utente tocca semplicemente la notifica si esegue il deep link.
        await PushActionHandler.handle(response)
    }
}
