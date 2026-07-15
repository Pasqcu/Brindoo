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

    // Confronto fianco a fianco (2-3 preferiti)
    @State private var compareMode = false
    @State private var selectedIds: Set<UUID> = []
    @State private var showCompare = false

    private let maxCompared = 3

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
                        if compareMode {
                            Button {
                                toggleSelection(profile.id)
                            } label: {
                                HStack(spacing: BrindooSpacing.sm) {
                                    Image(systemName: selectedIds.contains(profile.id)
                                          ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 22))
                                        .foregroundStyle(selectedIds.contains(profile.id)
                                                         ? Color.brindooCoral : Color.brindooTextTertiary)
                                    row(for: profile)
                                }
                            }
                            .buttonStyle(.plain)
                        } else {
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
        .toolbar {
            // Il confronto ha senso solo con almeno 2 salvati.
            if case .loaded(let list) = vm.state, list.count >= 2 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(compareMode ? "Annulla" : "Confronta") {
                        compareMode.toggle()
                        if !compareMode { selectedIds.removeAll() }
                    }
                    .font(BrindooFont.bodyMedium.weight(.medium))
                    .foregroundStyle(Color.brindooCoral)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if compareMode {
                BrindooButton(
                    selectedIds.count < 2
                        ? "Scegli almeno 2 professionisti"
                        : "Confronta (\(selectedIds.count))",
                    style: .primary,
                    size: .large,
                    isDisabled: selectedIds.count < 2
                ) {
                    showCompare = true
                }
                .padding(.horizontal, BrindooSpacing.lg)
                .padding(.vertical, BrindooSpacing.sm)
                .background(
                    Color.brindooBackground
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: -2)
                )
            }
        }
        .sheet(isPresented: $showCompare) {
            if case .loaded(let list) = vm.state {
                CompareOrganizersView(
                    organizers: list.filter { selectedIds.contains($0.id) }
                )
            }
        }
        .task { await vm.load() }
        .refreshable { await vm.refresh() }
    }

    private func toggleSelection(_ id: UUID) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else if selectedIds.count < maxCompared {
            selectedIds.insert(id)
        }
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
