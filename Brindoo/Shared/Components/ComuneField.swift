//
//  ComuneField.swift
//  Brindoo
//
//  Campo per scegliere il comune del Lazio da un elenco (con ricerca),
//  con possibilità di inserire un comune non in lista. Selezionando un comune
//  noto, imposta automaticamente anche la provincia.
//

import SwiftUI

/// Elenco comuni del Lazio usato per la selezione guidata.
enum LazioComuni {
    static let all: [(name: String, province: LazioProvince)] = {
        var list: [(String, LazioProvince)] = [("Roma", .roma)]
        list += LazioArea.majorMunicipalities.map { ($0.name, $0.province) }
        return list.sorted { $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending }
    }()
}

struct ComuneField: View {
    @Binding var city: String
    @Binding var province: LazioProvince?
    var error: String?
    var isDisabled: Bool = false

    @State private var showPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
            Text("Città")
                .font(BrindooFont.bodySmall.weight(.medium))
                .foregroundStyle(Color.brindooTextSecondary)

            Button {
                showPicker = true
            } label: {
                HStack(spacing: BrindooSpacing.sm) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundStyle(Color.brindooTextSecondary)
                    Text(city.isEmpty ? "Scegli il comune" : city)
                        .font(BrindooFont.bodyLarge)
                        .foregroundStyle(city.isEmpty ? Color.brindooTextTertiary : Color.brindooTextPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.brindooTextSecondary)
                }
                .padding(.horizontal, BrindooSpacing.md)
                .frame(height: 52)
                .background(Color.brindooSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: BrindooRadius.md)
                        .strokeBorder(error != nil ? Color.brindooError : Color.brindooBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)

            if let error {
                Text(error)
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooError)
            }
        }
        .sheet(isPresented: $showPicker) {
            ComunePicker(selectedCity: $city, selectedProvince: $province)
                .presentationDetents([.large])
        }
    }
}

private struct ComunePicker: View {
    @Binding var selectedCity: String
    @Binding var selectedProvince: LazioProvince?

    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""

    private var filtered: [(name: String, province: LazioProvince)] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return LazioComuni.all }
        return LazioComuni.all.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    private var customEntry: String? {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return nil }
        let exists = LazioComuni.all.contains { $0.name.localizedCaseInsensitiveCompare(q) == .orderedSame }
        return exists ? nil : q
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BrindooSpacing.sm) {
                    BrindooTextField(
                        title: "Cerca",
                        placeholder: "Es. Roma, Tivoli, Latina…",
                        text: $query,
                        icon: "magnifyingglass",
                        autocapitalization: .words
                    )

                    if let custom = customEntry {
                        comuneRow(name: "Usa «\(custom)»", province: nil) {
                            selectedCity = custom
                            dismiss()
                        }
                    }

                    ForEach(filtered, id: \.name) { item in
                        comuneRow(name: item.name, province: item.province) {
                            selectedCity = item.name
                            selectedProvince = item.province
                            dismiss()
                        }
                    }
                }
                .padding(BrindooSpacing.md)
            }
            .background(Color.brindooBackground)
            .navigationTitle("Comune")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func comuneRow(name: String, province: LazioProvince?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: BrindooSpacing.sm) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(Color.brindooCoral)
                Text(name)
                    .font(BrindooFont.bodyMedium.weight(.medium))
                    .foregroundStyle(Color.brindooTextPrimary)
                Spacer()
                if let province {
                    Text(province.displayName)
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextSecondary)
                }
            }
            .padding(BrindooSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.brindooSurface)
            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
        }
        .buttonStyle(.plain)
    }
}
