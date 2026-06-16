//
//  FavoriteOrganizersView.swift
//  Brindoo
//
//  Lista degli organizer salvati dal cliente.
//

import SwiftUI

@MainActor
@Observable
final class FavoriteOrganizersViewModel: BrindooViewModel {
    var state: LoadState<[Profile]> = .idle

    func load() async {
        state = .loading
        do {
            let list = try await OrganizerFavoriteService.shared.fetchMyFavoriteOrganizers()
            state = list.isEmpty ? .empty : .loaded(list)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func refresh() async { await load() }

    func remove(_ id: UUID) async {
        try? await OrganizerFavoriteService.shared.remove(organizerId: id)
        await load()
    }
}

struct FavoriteOrganizersView: View {
    @State private var vm = FavoriteOrganizersViewModel()

    var body: some View {
        Group {
            switch vm.state {
            case .idle, .loading:
                VStack(spacing: BrindooSpacing.md) {
                    ForEach(0..<5, id: \.self) { _ in BrindooSkeletonCard() }
                }
                .padding(BrindooSpacing.md)
            case .empty:
                BrindooEmptyState(
                    icon: BrindooIcon.heart,
                    title: "Nessun organizer salvato",
                    message: "Tocca il cuore sul profilo di un organizer per ritrovarlo qui."
                )
            case .loaded(let list):
                List {
                    ForEach(list) { profile in
                        NavigationLink {
                            OrganizerDetailView(organizer: profile)
                        } label: {
                            row(for: profile)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                Task { await vm.remove(profile.id) }
                            } label: {
                                Label("Rimuovi", systemImage: BrindooIcon.heart)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            case .error(let message):
                BrindooEmptyState(
                    icon: BrindooIcon.error,
                    title: "Qualcosa è andato storto",
                    message: message,
                    actionTitle: "Riprova"
                ) {
                    Task { await vm.refresh() }
                }
            }
        }
        .navigationTitle("Preferiti")
        .task { await vm.load() }
        .refreshable { await vm.refresh() }
    }

    private func row(for profile: Profile) -> some View {
        HStack(spacing: BrindooSpacing.sm) {
            AvatarView(url: profile.avatarUrl, name: profile.displayName, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(profile.displayName)
                        .font(BrindooFont.titleSmall)
                    if profile.isPro == true {
                        BrindooBadge("Pro", style: .pro, icon: BrindooIcon.crown)
                    }
                }
                if let city = profile.city {
                    Label(city, systemImage: BrindooIcon.location)
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextSecondary)
                }
            }
            Spacer()
            Image(systemName: BrindooIcon.heartFilled)
                .foregroundStyle(Color.brindooCoral)
        }
        .padding(.vertical, 4)
    }
}
