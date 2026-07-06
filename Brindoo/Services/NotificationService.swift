//
//  NotificationService.swift
//  Brindoo
//
//  Gestisce permessi notifiche push, registrazione APNs e salvataggio token
//  nella tabella `device_tokens` di Supabase.
//
//  Nota: il delegate di UNUserNotificationCenter è impostato da AppDelegate.
//

import Foundation
import UserNotifications
import UIKit
import Supabase

@MainActor
final class NotificationService {

    static let shared = NotificationService()
    private init() {}

    private let center = UNUserNotificationCenter.current()

    /// Ultimo stato noto dell'autorizzazione push (cache locale).
    /// Aggiornato da `refreshAuthorizationStatus()`.
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    // MARK: - Autorizzazione

    /// Chiede all'utente i permessi notifiche (mostra la dialog di sistema).
    /// Se accetta, registra anche con APNs.
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            authorizationStatus = granted ? .authorized : .denied
            if granted {
                await registerForRemoteNotifications()
            }
            return granted
        } catch {
            print("❌ Errore autorizzazione notifiche: \(error)")
            return false
        }
    }

    /// True se l'utente ha già concesso permesso (o lo ha concesso in modalità provisional).
    func isAuthorized() async -> Bool {
        await refreshAuthorizationStatus()
        return authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    /// Aggiorna `authorizationStatus` leggendo lo stato corrente dal sistema.
    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    // MARK: - Registrazione APNs

    /// Se l'utente ha già autorizzato le notifiche, registra il device con APNs
    /// (per ottenere il device token). Chiamato all'avvio dell'app.
    func registerForRemoteNotificationsIfAuthorized() async {
        await refreshAuthorizationStatus()
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else {
            return
        }
        await registerForRemoteNotifications()
    }

    /// Forza la registrazione APNs (chiamato dopo che l'utente ha autorizzato).
    private func registerForRemoteNotifications() async {
        UIApplication.shared.registerForRemoteNotifications()
    }

    /// Dopo il login, se l'utente ha il permesso, ri-registra in modo da
    /// poter salvare il token associato al nuovo utente.
    func syncTokenAfterLogin() async {
        await registerForRemoteNotificationsIfAuthorized()
    }

    // MARK: - Gestione token

    /// Chiamato da AppDelegate quando APNs restituisce il device token.
    func saveDeviceToken(_ token: Data) async {
        let tokenString = token.map { String(format: "%02x", $0) }.joined()
        print("📱 Push token: \(tokenString)")

        guard let userId = SupabaseManager.shared.currentUserID else {
            // Non loggato: salviamo il token solo quando l'utente farà login
            return
        }

        struct Payload: Encodable {
            let user_id: UUID
            let token: String
            let platform: String
        }

        do {
            try await SupabaseManager.shared.client
                .from("device_tokens")
                .upsert(
                    Payload(user_id: userId, token: tokenString, platform: "ios"),
                    onConflict: "token"
                )
                .execute()
            print("✅ Device token salvato su Supabase")
        } catch {
            print("❌ Errore salvataggio device token: \(error)")
        }
    }

    /// Chiamato da AppDelegate se la registrazione APNs fallisce.
    func handleRegistrationFailure(_ error: Error) {
        print("❌ Registrazione APNs fallita: \(error.localizedDescription)")
    }

    // MARK: - Badge

    /// Azzera il badge sull'icona dell'app e ripulisce le notifiche già
    /// consegnate dal Centro Notifiche. Chiamato quando l'app diventa attiva:
    /// evita badge "fantasma" che restano sull'icona a tempo indeterminato.
    func clearBadgeAndDeliveredNotifications() async {
        try? await center.setBadgeCount(0)
        center.removeAllDeliveredNotifications()
    }

    /// Allinea il numerino sull'icona alle cose realmente da gestire
    /// (trattative che aspettano una risposta + messaggi non letti).
    /// Con zero, ripulisce anche le notifiche già consegnate: è il "reset".
    func syncAppBadge(to count: Int) async {
        try? await center.setBadgeCount(max(0, count))
        if count <= 0 {
            center.removeAllDeliveredNotifications()
        }
    }

    /// Cancella i token del device dell'utente corrente (es. su logout).
    func removeDeviceToken() async {
        guard let userId = SupabaseManager.shared.currentUserID else { return }
        _ = try? await SupabaseManager.shared.client
            .from("device_tokens")
            .delete()
            .eq("user_id", value: userId)
            .execute()
    }
}
