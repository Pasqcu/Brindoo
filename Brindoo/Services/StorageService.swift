//
//  StorageService.swift
//  Brindoo
//
//  Service per gestire upload e cancellazione di immagini su Supabase Storage.
//  Gestisce: avatar utente e foto del portfolio organizzatori.
//

import Foundation
import UIKit
import Supabase

@MainActor
final class StorageService {
    
    static let shared = StorageService()
    private init() {}
    
    private var storage: SupabaseStorageClient {
        SupabaseManager.shared.storage
    }
    
    // MARK: - Compressione immagini
    
    /// Comprime un'immagine UIImage in JPEG di qualità decente per upload.
    /// Ridimensiona a max 1600px lato lungo per limitare i kB.
    private func compressImage(_ image: UIImage, quality: CGFloat = 0.7) -> Data? {
        let maxDimension: CGFloat = 1600
        let resized = resizeImage(image, maxDimension: maxDimension)
        return resized.jpegData(compressionQuality: quality)
    }
    
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let largest = max(size.width, size.height)
        guard largest > maxDimension else { return image }
        
        let ratio = maxDimension / largest
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    // MARK: - Avatar utente
    
    /// Carica l'avatar dell'utente corrente. Restituisce l'URL pubblico.
    /// Path nel bucket: avatars/{user_id}/avatar.jpg
    func uploadAvatar(_ image: UIImage) async throws -> String {
        guard let userId = SupabaseManager.shared.currentUserID else {
            throw NSError(domain: "StorageService", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Devi essere loggato"])
        }
        
        guard let imageData = compressImage(image) else {
            throw NSError(domain: "StorageService", code: 400,
                          userInfo: [NSLocalizedDescriptionKey: "Immagine non valida"])
        }
        
        let path = "\(userId.uuidString)/avatar.jpg"
        
        do {
            // Upload con upsert: sovrascrive il file esistente
            try await storage
                .from("avatars")
                .upload(
                    path,
                    data: imageData,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: "image/jpeg",
                        upsert: true
                    )
                )
            
            // Costruisci l'URL pubblico (con cache busting per forzare refresh)
            let publicUrl = try storage.from("avatars").getPublicURL(path: path)
            let urlWithCacheBust = "\(publicUrl.absoluteString)?t=\(Int(Date().timeIntervalSince1970))"
            
            print("✅ Avatar caricato: \(urlWithCacheBust)")
            return urlWithCacheBust
        } catch {
            print("❌ Errore upload avatar: \(error)")
            throw error
        }
    }
    
    /// Cancella l'avatar dell'utente corrente
    func deleteAvatar() async throws {
        guard let userId = SupabaseManager.shared.currentUserID else { return }
        
        let path = "\(userId.uuidString)/avatar.jpg"
        
        do {
            _ = try await storage.from("avatars").remove(paths: [path])
            print("✅ Avatar cancellato")
        } catch {
            print("⚠️ Errore cancellazione avatar: \(error)")
            // Non rilancio l'errore: se il file non esiste è ok lo stesso
        }
    }
    
    // MARK: - Portfolio
    
    /// Carica una foto nel portfolio dell'organizzatore corrente.
    /// Restituisce: (publicUrl, storagePath) per salvarli nella tabella portfolio_items
    func uploadPortfolioImage(_ image: UIImage) async throws -> (url: String, path: String) {
        guard let userId = SupabaseManager.shared.currentUserID else {
            throw NSError(domain: "StorageService", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Devi essere loggato"])
        }
        
        guard let imageData = compressImage(image, quality: 0.8) else {
            throw NSError(domain: "StorageService", code: 400,
                          userInfo: [NSLocalizedDescriptionKey: "Immagine non valida"])
        }
        
        let filename = "\(UUID().uuidString).jpg"
        let path = "\(userId.uuidString)/\(filename)"
        
        do {
            try await storage
                .from("portfolio")
                .upload(
                    path,
                    data: imageData,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: "image/jpeg",
                        upsert: false
                    )
                )
            
            let publicUrl = try storage.from("portfolio").getPublicURL(path: path)
            
            print("✅ Foto portfolio caricata")
            return (url: publicUrl.absoluteString, path: path)
        } catch {
            print("❌ Errore upload portfolio: \(error)")
            throw error
        }
    }
    
    // MARK: - Foto di copertina offerta

    /// Carica la foto di copertina di un'offerta. Riusa il bucket `portfolio`
    /// (le policy consentono path che iniziano con l'id utente). Restituisce l'URL pubblico.
    func uploadOfferImage(_ image: UIImage) async throws -> String {
        guard let userId = SupabaseManager.shared.currentUserID else {
            throw NSError(domain: "StorageService", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Devi essere loggato"])
        }

        guard let imageData = compressImage(image, quality: 0.8) else {
            throw NSError(domain: "StorageService", code: 400,
                          userInfo: [NSLocalizedDescriptionKey: "Immagine non valida"])
        }

        let path = "\(userId.uuidString)/offer_\(UUID().uuidString).jpg"

        do {
            try await storage
                .from("portfolio")
                .upload(
                    path,
                    data: imageData,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: "image/jpeg",
                        upsert: false
                    )
                )
            let publicUrl = try storage.from("portfolio").getPublicURL(path: path)
            print("✅ Foto offerta caricata")
            return publicUrl.absoluteString
        } catch {
            print("❌ Errore upload foto offerta: \(error)")
            throw error
        }
    }

    // MARK: - Foto recensione

    /// Carica la foto allegata a una recensione (lato cliente). Riusa il
    /// bucket `portfolio` (upload consentito a ogni utente autenticato).
    func uploadReviewImage(_ image: UIImage) async throws -> String {
        guard let userId = SupabaseManager.shared.currentUserID else {
            throw NSError(domain: "StorageService", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Devi essere loggato"])
        }

        guard let imageData = compressImage(image, quality: 0.8) else {
            throw NSError(domain: "StorageService", code: 400,
                          userInfo: [NSLocalizedDescriptionKey: "Immagine non valida"])
        }

        let path = "\(userId.uuidString)/review_\(UUID().uuidString).jpg"

        try await storage
            .from("portfolio")
            .upload(
                path,
                data: imageData,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: "image/jpeg",
                    upsert: false
                )
            )
        let publicUrl = try storage.from("portfolio").getPublicURL(path: path)
        return publicUrl.absoluteString
    }

    /// Cancella una foto specifica dal portfolio
    func deletePortfolioImage(storagePath: String) async throws {
        do {
            _ = try await storage.from("portfolio").remove(paths: [storagePath])
            print("✅ Foto portfolio cancellata: \(storagePath)")
        } catch {
            print("⚠️ Errore cancellazione foto portfolio: \(error)")
            throw error
        }
    }
}
