//
//  BlockedUsersView.swift
//  Brindoo
//
//  Lista dei profili bloccati con possibilità di sbloccarli.
//

import SwiftUI

struct BlockedUsersView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var profiles: [Profile] = []
    @State private var isLoading = true
    @State private var unblockError: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView().tint(.brindooCoral)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if profiles.isEmpty {
                    VStack(spacing: BrindooSpacing.md) {
                        Image(systemName: "hand.raised.slash")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.brindooTextSecondary)
                        Text("Nessun utente bloccato")
                            .font(BrindooFont.bodyMedium)
                            .foregroundStyle(Color.brindooTextSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(profiles) { profile in
                            HStack {
                                AvatarView(url: profile.avatarUrl, name: profile.fullName, size: 40)
                                VStack(alignment: .leading) {
                                    Text(profile.displayName)
                                        .font(BrindooFont.bodyMedium)
                                    if let city = profile.city {
                                        Text(city)
                                            .font(BrindooFont.caption)
                                            .foregroundStyle(Color.brindooTextSecondary)
                                    }
                                }
                                Spacer()
                                Button("Sblocca") {
                                    Task { await unblock(profile.id) }
                                }
                                .font(BrindooFont.bodySmall.weight(.medium))
                                .foregroundStyle(Color.brindooCoral)
                                // Solo il bottone sblocca: in una List, senza
                                // questo stile, bastava toccare il nome.
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }
            }
            .background(Color.brindooBackground)
            .navigationTitle("Utenti bloccati")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chiudi") { dismiss() }
                }
            }
            .task { await load() }
            .alert(
                "Non riuscito",
                isPresented: Binding(get: { unblockError != nil }, set: { if !$0 { unblockError = nil } })
            ) {
                Button("OK", role: .cancel) { unblockError = nil }
            } message: {
                Text(unblockError ?? "")
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        await BlockService.shared.loadBlocks()
        // Una richiesta sola per tutti i bloccati.
        profiles = (try? await ProfileService.shared.fetchProfiles(
            ids: Array(BlockService.shared.blockedIds)
        )) ?? []
    }

    private func unblock(_ userId: UUID) async {
        do {
            try await BlockService.shared.unblock(userId: userId)
            profiles.removeAll { $0.id == userId }
        } catch {
            BrindooLog.error("\(error)")
            unblockError = BrindooErrorText.message(for: error, fallback: "Sblocco non riuscito. \(BrindooText.retryHint)")
        }
    }
}
