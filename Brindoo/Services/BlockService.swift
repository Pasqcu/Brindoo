//
//  BlockService.swift
//

import Foundation
import Supabase

@MainActor
final class BlockService {
    static let shared = BlockService()
    private init() {}
    
    private var client: SupabaseClient {
        SupabaseManager.shared.client
    }
    
    /// Set degli ID utenti bloccati dall'utente corrente (cache locale)
    private(set) var blockedIds: Set<UUID> = []
    private(set) var blockedByIds: Set<UUID> = []
    
    /// Carica blocchi all'avvio o quando l'utente fa login
    func loadBlocks() async {
        guard let userId = SupabaseManager.shared.currentUserID else { return }
        
        struct Row: Decodable {
            let blocker_id: UUID
            let blocked_id: UUID
        }
        
        do {
            // Io ho bloccato chi
            let myBlocks: [Row] = try await client
                .from("blocked_users")
                .select("blocker_id, blocked_id")
                .eq("blocker_id", value: userId)
                .execute()
                .value
            
            blockedIds = Set(myBlocks.map { $0.blocked_id })
            
            // Chi ha bloccato me
            let blocksOnMe: [Row] = try await client
                .from("blocked_users")
                .select("blocker_id, blocked_id")
                .eq("blocked_id", value: userId)
                .execute()
                .value
            
            blockedByIds = Set(blocksOnMe.map { $0.blocker_id })
            
            print("✅ Block cache: blocco \(blockedIds.count), bloccato da \(blockedByIds.count)")
        } catch {
            print("❌ Errore loadBlocks: \(error)")
        }
    }
    
    /// True se l'utente corrente ha bloccato l'altro utente
    func haveIBlocked(_ otherUserId: UUID) -> Bool {
        blockedIds.contains(otherUserId)
    }
    
    /// True se l'utente corrente è stato bloccato dall'altro
    func amIBlockedBy(_ otherUserId: UUID) -> Bool {
        blockedByIds.contains(otherUserId)
    }
    
    /// True se c'è un blocco reciproco
    func isBlockingOrBlocked(_ otherUserId: UUID) -> Bool {
        haveIBlocked(otherUserId) || amIBlockedBy(otherUserId)
    }
    
    func block(userId: UUID) async throws {
        guard let blockerId = SupabaseManager.shared.currentUserID else { return }
        
        struct Payload: Encodable {
            let blocker_id: UUID
            let blocked_id: UUID
        }
        
        try await client
            .from("blocked_users")
            .insert(Payload(blocker_id: blockerId, blocked_id: userId))
            .execute()
        
        blockedIds.insert(userId)
    }
    
    func unblock(userId: UUID) async throws {
        guard let blockerId = SupabaseManager.shared.currentUserID else { return }
        
        try await client
            .from("blocked_users")
            .delete()
            .eq("blocker_id", value: blockerId)
            .eq("blocked_id", value: userId)
            .execute()
        
        blockedIds.remove(userId)
    }
}
