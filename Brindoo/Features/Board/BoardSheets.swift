//
//  BoardSheets.swift
//  Brindoo
//
//  Pannelli modali della bacheca cliente: filtro aree, filtri extra
//  (valutazione / prezzo / data evento) e primo passo guidato.
//  (Estratti da BoardView.)
//

import SwiftUI

// MARK: - Area picker sheet (per cliente: filtro bacheca)

struct AreaPickerSheet: View {

    @Binding var selected: Set<String>
    let onApply: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var working: Set<String> = []
    @State private var searchQuery: String = ""

    private var filteredAreas: [LazioArea] {
        let q = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return LazioArea.allCases }
        return LazioArea.allCases.filter { $0.name.lowercased().contains(q) }
    }

    private var areasByProvince: [(LazioProvince, [LazioArea])] {
        let grouped = Dictionary(grouping: filteredAreas, by: { $0.province })
        return LazioProvince.allCases.compactMap { p in
            guard let list = grouped[p], !list.isEmpty else { return nil }
            return (p, list)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BrindooSpacing.md) {

                    BrindooTextField(
                        title: "Cerca",
                        placeholder: "Es. EUR, Tivoli, Latina…",
                        text: $searchQuery,
                        icon: "magnifyingglass",
                        autocapitalization: .never
                    )

                    ForEach(areasByProvince, id: \.0) { province, areas in
                        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
                            Text(province.displayName)
                                .font(BrindooFont.bodySmall.weight(.semibold))
                                .foregroundStyle(Color.brindooTextSecondary)
                                .textCase(.uppercase)
                                .padding(.top, BrindooSpacing.xs)

                            VStack(spacing: BrindooSpacing.xxs) {
                                ForEach(areas) { area in
                                    row(area)
                                }
                            }
                        }
                    }
                }
                .padding(BrindooSpacing.md)
            }
            .background(Color.brindooBackground)
            .navigationTitle("Filtra per area")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Pulisci") { working.removeAll() }
                        .disabled(working.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Applica") {
                        selected = working
                        onApply()
                        dismiss()
                    }
                    .font(BrindooFont.bodyMedium.weight(.semibold))
                }
            }
            .onAppear { working = selected }
        }
    }

    @ViewBuilder
    private func row(_ area: LazioArea) -> some View {
        let isOn = working.contains(area.slug)
        Button {
            if isOn { working.remove(area.slug) }
            else { working.insert(area.slug) }
        } label: {
            HStack(spacing: BrindooSpacing.sm) {
                Image(systemName: area.isWholeProvince ? "map.fill" : "mappin.and.ellipse")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isOn ? .white : Color.brindooCoral)
                    .frame(width: 28, height: 28)
                    .background(isOn ? Color.brindooCoral : Color.brindooCoral.opacity(0.1))
                    .clipShape(Circle())

                Text(area.name)
                    .font(BrindooFont.bodyMedium.weight(.medium))
                    .foregroundStyle(Color.brindooTextPrimary)

                Spacer()

                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isOn ? Color.brindooCoral : Color.brindooTextSecondary)
            }
            .padding(.horizontal, BrindooSpacing.sm)
            .padding(.vertical, BrindooSpacing.xs)
            .background(isOn ? Color.brindooCoral.opacity(0.05) : Color.brindooSurface)
            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Filtri bacheca (cliente)

struct BoardFiltersSheet: View {
    @Binding var minRating: Int
    @Binding var maxPrice: Double
    /// Data dell'evento: se impostata, la bacheca mostra solo i professionisti
    /// liberi quel giorno (in base al loro calendario disponibilità).
    @Binding var eventDate: Date?
    @Environment(\.dismiss) private var dismiss

    @State private var dateEnabled: Bool = false
    @State private var workingDate: Date = Date()

    private var tomorrow: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BrindooSpacing.lg) {

                    VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
                        Text("Data dell'evento")
                            .font(BrindooFont.titleSmall)
                        Toggle(isOn: $dateEnabled.animation()) {
                            Text("Solo chi è libero in una data")
                                .font(BrindooFont.bodyMedium)
                        }
                        .tint(Color.brindooCoral)

                        if dateEnabled {
                            DatePicker(
                                "Data",
                                selection: $workingDate,
                                in: tomorrow...,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                            .environment(\.locale, Locale(identifier: "it_IT"))
                            Text("Nascondiamo i professionisti che hanno segnato quel giorno come occupato o sono in vacanza.")
                                .font(BrindooFont.caption)
                                .foregroundStyle(Color.brindooTextSecondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
                        Text("Valutazione minima")
                            .font(BrindooFont.titleSmall)
                        Picker("Valutazione minima", selection: $minRating) {
                            Text("Tutte").tag(0)
                            Text("3+ ⭐").tag(3)
                            Text("4+ ⭐").tag(4)
                            Text("5 ⭐").tag(5)
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
                        HStack {
                            Text("Prezzo massimo")
                                .font(BrindooFont.titleSmall)
                            Spacer()
                            Text(maxPrice > 0 ? "€\(Int(maxPrice))" : "Nessun limite")
                                .font(BrindooFont.bodyMedium.weight(.semibold))
                                .foregroundStyle(Color.brindooCoral)
                        }
                        Slider(value: $maxPrice, in: 0...2000, step: 50)
                            .tint(Color.brindooCoral)
                        Text("Mostra solo professionisti con almeno un'offerta entro questo prezzo.")
                            .font(BrindooFont.caption)
                            .foregroundStyle(Color.brindooTextSecondary)
                    }
                }
                .padding(BrindooSpacing.lg)
            }
            .background(Color.brindooBackground)
            .navigationTitle("Filtri")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Azzera") {
                        minRating = 0
                        maxPrice = 0
                        dateEnabled = false
                        eventDate = nil
                    }
                    .disabled(minRating == 0 && maxPrice == 0 && !dateEnabled)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Applica") {
                        eventDate = dateEnabled ? Calendar.current.startOfDay(for: workingDate) : nil
                        dismiss()
                    }
                    .font(BrindooFont.bodyMedium.weight(.semibold))
                }
            }
            .onAppear {
                if let eventDate {
                    dateEnabled = true
                    workingDate = eventDate
                } else {
                    workingDate = tomorrow
                }
            }
        }
    }
}

// MARK: - Primo passo guidato (cliente)

struct ClientWelcomeSheet: View {

    let categories: [ServiceCategory]
    let onApply: (Set<UUID>) -> Void
    let onSkip: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<UUID> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BrindooSpacing.lg) {
                    VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
                        Text("Che tipo di evento organizzi?")
                            .font(BrindooFont.titleLarge)
                        Text("Scegli uno o più servizi: ti mostriamo subito i professionisti giusti.")
                            .font(BrindooFont.bodyMedium)
                            .foregroundStyle(Color.brindooTextSecondary)
                    }

                    FlowLayoutView(spacing: BrindooSpacing.xs) {
                        ForEach(categories) { cat in
                            let isOn = selected.contains(cat.id)
                            Button {
                                if isOn { selected.remove(cat.id) } else { selected.insert(cat.id) }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: cat.icon).font(.system(size: 13, weight: .medium))
                                    Text(cat.name).font(BrindooFont.bodySmall.weight(.medium))
                                }
                                .padding(.horizontal, BrindooSpacing.md)
                                .padding(.vertical, BrindooSpacing.xs)
                                .foregroundStyle(isOn ? .white : cat.tint)
                                .background(isOn ? cat.tint : cat.tint.opacity(0.12))
                                .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding(BrindooSpacing.lg)
            }
            .background(Color.brindooBackground)
            .navigationTitle("Benvenuto 🎉")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Salta") { onSkip(); dismiss() }
                        .foregroundStyle(Color.brindooTextSecondary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                BrindooButton(
                    selected.isEmpty ? "Mostra tutti i professionisti" : "Mostra professionisti",
                    style: .primary,
                    size: .large
                ) {
                    onApply(selected)
                    dismiss()
                }
                .padding(.horizontal, BrindooSpacing.lg)
                .padding(.vertical, BrindooSpacing.sm)
                .background(Color.brindooBackground)
            }
        }
    }
}
