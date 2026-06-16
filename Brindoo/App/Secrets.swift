//
//  Secrets.swift
//  Brindoo
//
//  ⚠️ ATTENZIONE: questo file contiene le credenziali pubbliche di Supabase.
//  La "anon key" è progettata per essere pubblica (è protetta dalle Row Level Security
//  che hai già configurato), quindi va bene tenerla qui.
//
//  ⚠️ NON inserire MAI qui la "service_role key" di Supabase.
//

import Foundation

enum Secrets {
    
    // MARK: - Supabase
    
    /// URL del progetto Supabase
    /// Lo trovi su: app.supabase.com → tuo progetto → Project Settings → API → Project URL
    static let supabaseURL = "https://ulpuaphxdpwhyusrqqpk.supabase.co"
    
    /// Chiave anonima pubblica (anon/public key)
    /// La trovi su: app.supabase.com → tuo progetto → Project Settings → API → anon public
    static let supabaseAnonKey = "sb_publishable_K4o3lkqIIpl4YkB6E1EViQ_0Xo4KQp-"
}
