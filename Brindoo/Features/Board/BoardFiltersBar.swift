//
//  BoardFiltersBar.swift
//  Brindoo
//
//  Barra filtri della bacheca cliente (estratta da BoardView):
//  ricerca, chip province, selettore area e chip categorie.
//  Parla direttamente col BoardViewModel.
//

import SwiftUI

struct BoardFiltersBar: View {

    @Bindable var vm: BoardViewModel
    @Binding var showAreaPicker: Bool

    /// Quando l'utente scorre la bacheca la barra si riduce alla sola
    /// ricerca (più un riassunto dei filtri attivi): su iPhone piccoli
    /// le tre righe impilate mangiavano mezzo schermo.
    var isCompact: Bool = false

    private let lazioProvinces = LazioProvince.allCases

    private func provinceSlug(_ p: LazioProvince) -> String { "prov_\(p.rawValue.lowercased())" }

    private var areaFilterTitle: String {
        if vm.selectedAreaSlugs.isEmpty { return "Area" }
        return LazioArea.displayLabel(forSlugs: Array(vm.selectedAreaSlugs))
    }

    var body: some View {
        VStack(spacing: BrindooSpacing.xs) {
            searchBar
                .padding(.horizontal, BrindooSpacing.md)
                .padding(.top, BrindooSpacing.xs)

            if isCompact {
                compactSummary
            } else {
                expandedFilters
            }
        }
        .padding(.bottom, isCompact ? BrindooSpacing.xs : BrindooSpacing.sm)
        .animation(BrindooAnimation.snappy, value: isCompact)
    }

    /// Riga unica mostrata mentre si scorre: dice cosa è attivo e riapre i filtri.
    @ViewBuilder
    private var compactSummary: some View {
        Button {
            showAreaPicker = true
        } label: {
            HStack(spacing: BrindooSpacing.xs) {
                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text(compactSummaryText)
                    .font(BrindooFont.bodySmall.weight(.medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(Color.brindooCoral)
            .padding(.horizontal, BrindooSpacing.md)
            .padding(.vertical, BrindooSpacing.xs)
            .frame(maxWidth: .infinity)
            .background(Color.brindooCoral.opacity(0.08))
            .clipShape(Capsule())
            .padding(.horizontal, BrindooSpacing.md)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filtri attivi: \(compactSummaryText). Tocca per cambiarli.")
        .transition(.opacity)
    }

    private var compactSummaryText: String {
        var parts: [String] = [areaFilterTitle == "Area" ? BrindooText.wholeLazio : areaFilterTitle]
        if !vm.selectedCategoryIds.isEmpty {
            let names = vm.categories.filter { vm.selectedCategoryIds.contains($0.id) }.map(\.name)
            parts.append(names.count <= 2 ? names.joined(separator: ", ") : "\(names.count) categorie")
        }
        if vm.eventDate != nil { parts.append("data scelta") }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var expandedFilters: some View {
        VStack(spacing: BrindooSpacing.xs) {
            provinceChipsBar

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: BrindooSpacing.xs) {
                    clearFiltersChip
                    ForEach(vm.categories) { category in
                        let isSelected = vm.selectedCategoryIds.contains(category.id)
                        let tint = category.tint
                        Button {
                            if isSelected {
                                vm.selectedCategoryIds.remove(category.id)
                            } else {
                                vm.selectedCategoryIds.insert(category.id)
                            }
                            Task { await vm.loadOrganizers() }
                        } label: {
                            HStack(spacing: BrindooSpacing.xxs) {
                                Image(systemName: category.icon)
                                    .font(.system(size: 13, weight: .medium))
                                Text(category.name)
                                    .font(BrindooFont.bodySmall.weight(.medium))
                            }
                            .foregroundStyle(isSelected ? .white : tint)
                            .padding(.horizontal, BrindooSpacing.md)
                            .padding(.vertical, BrindooSpacing.xs)
                            .background(isSelected ? tint : tint.opacity(0.12))
                            .clipShape(Capsule())
                        }
                        .accessibilityLabel(category.name)
                        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                    }
                }
                .padding(.horizontal, BrindooSpacing.md)
            }
        }
        .transition(.opacity)
    }

    /// Chip compatto "Pulisci" in testa alla riga categorie.
    @ViewBuilder
    private var clearFiltersChip: some View {
        if !vm.selectedCategoryIds.isEmpty || !vm.selectedAreaSlugs.isEmpty || vm.eventDate != nil {
            Button {
                vm.selectedCategoryIds.removeAll()
                vm.selectedAreaSlugs.removeAll()
                vm.eventDate = nil
                Task { await vm.loadOrganizers() }
            } label: {
                HStack(spacing: BrindooSpacing.xxs) {
                    Image(systemName: BrindooIcon.close)
                        .font(.system(size: 11, weight: .semibold))
                    Text("Pulisci")
                        .font(BrindooFont.bodySmall.weight(.medium))
                }
                .foregroundStyle(Color.brindooCoral)
                .padding(.horizontal, BrindooSpacing.sm)
                .padding(.vertical, BrindooSpacing.xs)
                .background(Color.brindooCoral.opacity(0.1))
                .clipShape(Capsule())
            }
            .accessibilityLabel("Pulisci filtri")
        }
    }

    @ViewBuilder
    private var provinceChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BrindooSpacing.xs) {
                areaFilterButton
                Divider().frame(height: 22)
                provinceChip(title: BrindooText.wholeLazio, isOn: vm.selectedAreaSlugs.isEmpty) {
                    vm.selectedAreaSlugs.removeAll()
                    Task { await vm.loadOrganizers() }
                }
                ForEach(lazioProvinces) { p in
                    let slug = provinceSlug(p)
                    provinceChip(title: p.displayName, isOn: vm.selectedAreaSlugs == [slug]) {
                        vm.selectedAreaSlugs = [slug]
                        Task { await vm.loadOrganizers() }
                    }
                }
            }
            .padding(.horizontal, BrindooSpacing.md)
        }
    }

    @ViewBuilder
    private func provinceChip(title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(BrindooFont.bodySmall.weight(.semibold))
                .foregroundStyle(isOn ? .white : Color.brindooTextSecondary)
                .padding(.horizontal, BrindooSpacing.md)
                .padding(.vertical, BrindooSpacing.xs)
                .background(isOn ? Color.brindooCoral : Color.brindooSurface)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color.brindooBorder, lineWidth: isOn ? 0 : 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var areaFilterButton: some View {
        let isActive = !vm.selectedAreaSlugs.isEmpty
        Button {
            showAreaPicker = true
        } label: {
            HStack(spacing: BrindooSpacing.xxs) {
                Image(systemName: BrindooIcon.location)
                    .font(.system(size: 13, weight: .medium))
                Text(areaFilterTitle)
                    .font(BrindooFont.bodySmall.weight(.medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isActive ? .white : Color.brindooCoral)
            .padding(.horizontal, BrindooSpacing.md)
            .padding(.vertical, BrindooSpacing.xs)
            .background(isActive ? Color.brindooCoral : Color.brindooCoral.opacity(0.1))
            .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private var searchBar: some View {
        HStack(spacing: BrindooSpacing.sm) {
            Image(systemName: BrindooIcon.search)
                .foregroundStyle(Color.brindooTextSecondary)

            TextField("Cerca professionista", text: $vm.searchText)
                .font(BrindooFont.bodyLarge)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .onSubmit { Task { await vm.loadOrganizers() } }

            if !vm.searchText.isEmpty {
                Button {
                    // La ricarica parte dal task di ricerca "dal vivo".
                    vm.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.brindooTextSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancella la ricerca")
            }
        }
        .padding(.horizontal, BrindooSpacing.md)
        .frame(height: 44)
        .brindooSurfaceBackground()
    }
}
