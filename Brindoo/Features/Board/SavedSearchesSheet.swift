//
//  SavedSearchesSheet.swift
//  Brindoo
//
//  Ricerche messe da parte dal cliente. Da qui si riapre una ricerca con
//  un tocco, si accende l'avviso ("dimmi quando esce qualcuno di nuovo")
//  o si cancella.
//

import SwiftUI

struct SavedSearchesSheet: View {

    let categories: [ServiceCategory]
    /// Filtri attivi in questo momento: se ci sono, si possono salvare.
    let currentFilters: SavedSearch?
    /// Riapre una ricerca salvata nella bacheca.
    let onApply: (SavedSearch) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var service = SavedSearchService.shared
    @State private var newName: String = ""
    @State private var showNameField = false

    private var searches: [SavedSearch] { service.searches }

    var body: some View {
        NavigationStack {
            Group {
                if searches.isEmpty && currentFilters == nil {
                    BrindooEmptyState(
                        icon: "bookmark",
                        title: "Nessuna ricerca salvata",
                        message: "Imposta i filtri in bacheca, poi torna qui per metterli da parte e farti avvisare sulle novità."
                    )
                } else {
                    List {
                        if currentFilters != nil {
                            Section {
                                saveCurrentRow
                            }
                        }

                        if !searches.isEmpty {
                            Section("Le tue ricerche") {
                                ForEach(searches) { search in
                                    row(search)
                                }
                                .onDelete { indexSet in
                                    let ids = indexSet.map { searches[$0].id }
                                    Task { for id in ids { await service.remove(id: id) } }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Ricerche salvate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chiudi") { dismiss() }
                        .foregroundStyle(Color.brindooCoral)
                }
            }
            .task { await service.loadIfNeeded() }
        }
    }

    // MARK: - Salva i filtri di adesso

    @ViewBuilder
    private var saveCurrentRow: some View {
        if let current = currentFilters {
            VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
                Text("Filtri di adesso")
                    .font(BrindooFont.bodyMedium.weight(.semibold))
                Text(current.summary(categories: categories))
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooTextSecondary)

                if showNameField {
                    TextField("Dai un nome (es. DJ a Latina)", text: $newName)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                        .onSubmit { save(current) }

                    HStack {
                        Button("Annulla") {
                            showNameField = false
                            newName = ""
                        }
                        .foregroundStyle(Color.brindooTextSecondary)
                        Spacer()
                        Button("Salva") { save(current) }
                            .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                            .foregroundStyle(Color.brindooCoral)
                    }
                    .font(BrindooFont.bodyMedium)
                } else {
                    Button {
                        newName = current.summary(categories: categories)
                        showNameField = true
                    } label: {
                        Label("Salva questa ricerca", systemImage: "bookmark.fill")
                            .font(BrindooFont.bodyMedium.weight(.medium))
                            .foregroundStyle(Color.brindooCoral)
                    }
                }
            }
            .padding(.vertical, BrindooSpacing.xxs)
        }
    }

    private func save(_ current: SavedSearch) {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        var toSave = current
        toSave.name = name
        Task {
            await service.add(toSave)
            BrindooHaptics.notify(.success)
        }
        showNameField = false
        newName = ""
    }

    // MARK: - Riga di una ricerca salvata

    @ViewBuilder
    private func row(_ search: SavedSearch) -> some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.xxs) {
            Button {
                onApply(search)
                dismiss()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(search.name)
                        .font(BrindooFont.bodyMedium.weight(.semibold))
                        .foregroundStyle(Color.brindooTextPrimary)
                    Text(search.summary(categories: categories))
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextSecondary)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Toggle(isOn: Binding(
                get: { search.alertEnabled },
                set: { value in Task { await service.setAlert(id: search.id, enabled: value) } }
            )) {
                Text("Avvisami sulle novità")
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooTextSecondary)
            }
            .tint(Color.brindooCoral)
        }
        .padding(.vertical, 2)
    }
}
