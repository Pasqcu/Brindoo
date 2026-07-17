//
//  CategoryService.swift
//  Brindoo
//
//  Service per leggere le categorie di servizio dal database.
//  Le categorie sono fisse (definite via SQL), quindi le carichiamo
//  una sola volta e le manteniamo in cache in memoria.
//

import Foundation
import Supabase

@MainActor
final class CategoryService {
    
    static let shared = CategoryService()
    private init() {}
    
    private var client: SupabaseClient {
        SupabaseManager.shared.client
    }
    
    /// Cache in memoria delle categorie
    private var cachedCategories: [ServiceCategory]?
    
    // MARK: - Fetch
    
    /// Recupera tutte le categorie attive, ordinate.
    /// Usa la cache se già caricate (ricarica solo se forceReload = true).
    func fetchCategories(forceReload: Bool = false) async throws -> [ServiceCategory] {
        
        // Usa cache se disponibile
        if !forceReload, let cached = cachedCategories {
            return cached
        }
        
        do {
            let categories: [ServiceCategory] = try await client
                .from("service_categories")
                .select()
                .eq("is_active", value: true)
                .order("sort_order", ascending: true)
                .execute()
                .value
            
            self.cachedCategories = categories
            BrindooLog.info("Caricate \(categories.count) categorie")
            return categories
        } catch {
            BrindooLog.error("Errore caricamento categorie: \(error)")
            throw error
        }
    }
    
    /// Trova una categoria per slug
    func findCategory(slug: String) -> ServiceCategory? {
        cachedCategories?.first { $0.slug == slug }
    }
    
    /// Trova una categoria per ID
    func findCategory(id: UUID) -> ServiceCategory? {
        cachedCategories?.first { $0.id == id }
    }
    
    /// Pulisce la cache (es. dopo logout)
    func clearCache() {
        cachedCategories = nil
    }

    // MARK: - Suggestion (nuova categoria)

    /// Invia una proposta per una nuova categoria. Lo sviluppatore la revisiona
    /// manualmente. Non c'è feedback al cliente oltre al successo dell'insert.
    func proposeCategorySuggestion(name: String, description: String?) async throws {
        guard let userId = SupabaseManager.shared.currentUserID else {
            throw NSError(domain: "Category", code: 401)
        }
        struct Payload: Encodable {
            let user_id: UUID
            let name: String
            let description: String?
        }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDesc = description?.trimmingCharacters(in: .whitespacesAndNewlines)
        try await client
            .from("category_suggestions")
            .insert(Payload(
                user_id: userId,
                name: trimmedName,
                description: (trimmedDesc?.isEmpty == false) ? trimmedDesc : nil
            ))
            .execute()
    }
}
