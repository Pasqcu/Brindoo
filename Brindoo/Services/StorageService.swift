//
//  StorageService.swift
//  Brindoo
//
//  Upload e cancellazione di immagini su Supabase Storage: avatar, portfolio,
//  copertine delle offerte e foto delle recensioni.
//
//  I quattro tipi di caricamento facevano gli stessi cinque passi (controllo
//  sessione, compressione, invio, URL pubblico, registro) ricopiati ogni
//  volta, con differenze non volute: uno non registrava niente, un altro
//  restituiva un errore diverso a parità di causa. Ora il percorso è uno solo
//  e ogni metodo dice soltanto dove va il file.
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

    /// I due contenitori usati su Supabase Storage.
    private enum Bucket {
        static let avatars = "avatars"
        /// Le policy consentono qualunque percorso che inizi con l'id utente,
        /// quindi qui stanno anche copertine delle offerte e foto recensione.
        static let portfolio = "portfolio"
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

    // MARK: - Caricamento

    /// Percorso dentro il contenitore, sempre sotto la cartella dell'utente:
    /// è la condizione che le policy del server controllano.
    private func userPath(_ filename: String) throws -> (userId: UUID, path: String) {
        guard let userId = SupabaseManager.shared.currentUserID else {
            throw BrindooServiceError.notLoggedIn
        }
        return (userId, "\(userId.uuidString)/\(filename)")
    }

    /// Comprime, carica e restituisce l'indirizzo pubblico del file.
    /// `upsert` sovrascrive un file con lo stesso nome (serve solo all'avatar,
    /// che ha un nome fisso).
    private func upload(
        _ image: UIImage,
        to bucket: String,
        filename: String,
        quality: CGFloat,
        upsert: Bool,
        describedAs description: String
    ) async throws -> (url: String, path: String) {
        let path = try userPath(filename).path

        guard let data = compressImage(image, quality: quality) else {
            throw BrindooServiceError.invalidImage
        }

        do {
            try await storage
                .from(bucket)
                .upload(
                    path,
                    data: data,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: "image/jpeg",
                        upsert: upsert
                    )
                )
            let publicUrl = try storage.from(bucket).getPublicURL(path: path)
            BrindooLog.info("\(description) caricata")
            return (publicUrl.absoluteString, path)
        } catch {
            BrindooLog.error("Errore upload \(description): \(error)")
            throw error
        }
    }

    // MARK: - Avatar utente

    /// Carica l'avatar dell'utente corrente. Restituisce l'URL pubblico.
    /// Path nel bucket: avatars/{user_id}/avatar.jpg
    func uploadAvatar(_ image: UIImage) async throws -> String {
        let result = try await upload(
            image,
            to: Bucket.avatars,
            filename: "avatar.jpg",
            quality: 0.7,
            upsert: true,
            describedAs: "Avatar"
        )
        // Il nome del file non cambia mai: senza questa coda le cache
        // continuerebbero a mostrare la foto vecchia.
        return "\(result.url)?t=\(Int(Date().timeIntervalSince1970))"
    }

    /// Cancella l'avatar dell'utente corrente
    func deleteAvatar() async throws {
        guard let userId = SupabaseManager.shared.currentUserID else { return }

        do {
            _ = try await storage
                .from(Bucket.avatars)
                .remove(paths: ["\(userId.uuidString)/avatar.jpg"])
            BrindooLog.info("Avatar cancellato")
        } catch {
            BrindooLog.error("Errore cancellazione avatar: \(error)")
            // Non rilancio l'errore: se il file non esiste è ok lo stesso
        }
    }

    // MARK: - Portfolio

    /// Carica una foto nel portfolio dell'organizzatore corrente.
    /// Restituisce: (publicUrl, storagePath) per salvarli nella tabella portfolio_items
    func uploadPortfolioImage(_ image: UIImage) async throws -> (url: String, path: String) {
        try await upload(
            image,
            to: Bucket.portfolio,
            filename: "\(UUID().uuidString).jpg",
            quality: 0.8,
            upsert: false,
            describedAs: "Foto portfolio"
        )
    }

    // MARK: - Foto di copertina offerta

    /// Carica la foto di copertina di un'offerta. Restituisce l'URL pubblico.
    func uploadOfferImage(_ image: UIImage) async throws -> String {
        try await upload(
            image,
            to: Bucket.portfolio,
            filename: "offer_\(UUID().uuidString).jpg",
            quality: 0.8,
            upsert: false,
            describedAs: "Foto offerta"
        ).url
    }

    // MARK: - Foto recensione

    /// Carica la foto allegata a una recensione (lato cliente).
    func uploadReviewImage(_ image: UIImage) async throws -> String {
        try await upload(
            image,
            to: Bucket.portfolio,
            filename: "review_\(UUID().uuidString).jpg",
            quality: 0.8,
            upsert: false,
            describedAs: "Foto recensione"
        ).url
    }

    /// Cancella una foto specifica dal portfolio
    func deletePortfolioImage(storagePath: String) async throws {
        do {
            _ = try await storage.from(Bucket.portfolio).remove(paths: [storagePath])
            BrindooLog.info("Foto portfolio cancellata: \(storagePath)")
        } catch {
            BrindooLog.error("Errore cancellazione foto portfolio: \(error)")
            throw error
        }
    }
}
