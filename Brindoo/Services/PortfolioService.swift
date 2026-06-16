//
//  PortfolioService.swift
//  Brindoo
//
//  Service per gestire la tabella portfolio_items e l'upload coordinato
//  con Supabase Storage.
//

import Foundation
import UIKit
import Supabase

@MainActor
final class PortfolioService {

    static let shared = PortfolioService()
    private init() {}

    private var client: SupabaseClient {
        SupabaseManager.shared.client
    }

    // MARK: - Lista

    /// Recupera le foto del portfolio di un organizzatore (ordinate)
    func fetchPortfolio(organizerId: UUID) async throws -> [PortfolioItem] {
        do {
            let items: [PortfolioItem] = try await client
                .from("portfolio_items")
                .select()
                .eq("organizer_id", value: organizerId)
                .order("sort_order", ascending: true)
                .order("created_at", ascending: false)
                .execute()
                .value

            print("✅ Caricate \(items.count) foto portfolio")
            return items
        } catch {
            print("❌ Errore caricamento portfolio: \(error)")
            throw error
        }
    }

    /// Alias storico di `fetchPortfolio`.
    func fetchItems(organizerId: UUID) async throws -> [PortfolioItem] {
        try await fetchPortfolio(organizerId: organizerId)
    }

    // MARK: - Aggiungi foto

    /// Limite massimo di foto: 5 per il piano free, 50 per Pro.
    static let maxPhotosFree = 5
    static let maxPhotosPro  = 50

    /// Carica una foto sullo Storage e crea il record in DB.
    @discardableResult
    func addPhoto(_ image: UIImage, caption: String? = nil) async throws -> PortfolioItem {
        guard let userId = SupabaseManager.shared.currentUserID else {
            throw NSError(domain: "PortfolioService", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Devi essere loggato"])
        }

        // Enforce cap in base allo stato Pro.
        let profile = try? await ProfileService.shared.fetchProfile(userID: userId)
        let isPro = profile?.isPro ?? false
        let cap = isPro ? Self.maxPhotosPro : Self.maxPhotosFree
        let current = try await fetchPortfolio(organizerId: userId).count
        if current >= cap {
            throw BrindooLimitError.maxPortfolioReached(max: cap)
        }

        // 1. Upload su Storage
        let (publicUrl, storagePath) = try await StorageService.shared.uploadPortfolioImage(image)

        // 2. Inserisci record in DB
        do {
            let payload = NewPortfolioItem(
                organizer_id: userId,
                image_url: publicUrl,
                storage_path: storagePath,
                caption: caption?.trimmingCharacters(in: .whitespaces).isEmpty == true ? nil : caption,
                sort_order: 0
            )

            let item: PortfolioItem = try await client
                .from("portfolio_items")
                .insert(payload)
                .select()
                .single()
                .execute()
                .value

            print("✅ Foto aggiunta al portfolio")
            return item
        } catch {
            // Rollback: cancella la foto dallo Storage
            print("❌ Errore inserimento DB, rollback dello Storage")
            try? await StorageService.shared.deletePortfolioImage(storagePath: storagePath)
            throw error
        }
    }

    /// Alias storico di `addPhoto` (`uploadItem(image:)`).
    @discardableResult
    func uploadItem(image: UIImage, caption: String? = nil) async throws -> PortfolioItem {
        try await addPhoto(image, caption: caption)
    }

    // MARK: - Cancella foto

    /// Cancella una foto: prima dal DB, poi dallo Storage
    func deletePhoto(_ item: PortfolioItem) async throws {
        do {
            try await client
                .from("portfolio_items")
                .delete()
                .eq("id", value: item.id)
                .execute()
        } catch {
            print("❌ Errore cancellazione DB: \(error)")
            throw error
        }

        try? await StorageService.shared.deletePortfolioImage(storagePath: item.storagePath)
        print("✅ Foto rimossa dal portfolio")
    }

    /// Alias storico di `deletePhoto`.
    func deleteItem(_ item: PortfolioItem) async throws {
        try await deletePhoto(item)
    }

    // MARK: - Aggiorna caption

    func updateCaption(itemId: UUID, caption: String?) async throws {
        let trimmed = caption?.trimmingCharacters(in: .whitespaces)
        let value = (trimmed?.isEmpty ?? true) ? nil : trimmed

        do {
            try await client
                .from("portfolio_items")
                .update(["caption": value])
                .eq("id", value: itemId)
                .execute()
        } catch {
            print("❌ Errore update caption: \(error)")
            throw error
        }
    }
}
