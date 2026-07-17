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
                    }
                }
                .padding(.horizontal, BrindooSpacing.md)
            }
        }
        .padding(.bottom, BrindooSpacing.sm)
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
                    Image(systemName: "xmark")
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
                provinceChip(title: "Tutto il Lazio", isOn: vm.selectedAreaSlugs.isEmpty) {
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
                Image(systemName: "mappin.and.ellipse")
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
            Image(systemName: "magnifyingglass")
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
                }
            }
        }
        .padding(.horizontal, BrindooSpacing.md)
        .frame(height: 44)
        .background(Color.brindooSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
    }
}
