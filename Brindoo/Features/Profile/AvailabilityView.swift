//
//  AvailabilityView.swift
//  Brindoo
//
//  L'organizzatore segna i giorni in cui NON è disponibile.
//  I clienti li vedono ed evitano quelle date quando propongono.
//

import SwiftUI

struct AvailabilityView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var selected: Set<DateComponents> = []
    @State private var isLoading: Bool = true
    @State private var isSaving: Bool = false
    @State private var error: String?

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BrindooSpacing.md) {
                    HStack(alignment: .top, spacing: BrindooSpacing.sm) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(Color.brindooCoral)
                        Text("Tocca i giorni in cui non sei disponibile. I clienti non potranno fissare l'evento in quelle date.")
                            .font(BrindooFont.bodySmall)
                            .foregroundStyle(Color.brindooTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(BrindooSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.brindooCoral.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))

                    if isLoading {
                        ProgressView().tint(.brindooCoral)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, BrindooSpacing.xl)
                    } else {
                        MultiDatePicker("Giorni non disponibili", selection: $selected, in: Date()...)
                            .tint(Color.brindooCoral)
                            .frame(maxWidth: .infinity)
                            .padding(BrindooSpacing.sm)
                            .background(Color.brindooSurface)
                            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))

                        Text("\(selected.count) giorni segnati come non disponibili")
                            .font(BrindooFont.caption)
                            .foregroundStyle(Color.brindooTextSecondary)
                    }

                    if let error {
                        Text(error)
                            .font(BrindooFont.bodySmall)
                            .foregroundStyle(Color.brindooError)
                    }
                }
                .padding(BrindooSpacing.lg)
            }
            .background(Color.brindooBackground)
            .navigationTitle("Disponibilità")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annulla") { dismiss() }.disabled(isSaving)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Salva") { Task { await save() } }
                        .font(BrindooFont.bodyMedium.weight(.semibold))
                        .disabled(isSaving || isLoading)
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let dates = try await AvailabilityService.shared.fetchMyUnavailableDays()
            selected = Set(dates.map { calendar.dateComponents([.year, .month, .day], from: $0) })
        } catch {
            self.error = "Impossibile caricare il calendario."
            BrindooLog.error("\(error)")
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let dates = Set(selected.compactMap { calendar.date(from: $0) })
        do {
            try await AvailabilityService.shared.setMyUnavailableDays(dates)
            BrindooHaptics.notify(.success)
            dismiss()
        } catch {
            self.error = "Impossibile salvare. Riprova."
            BrindooLog.error("\(error)")
        }
    }
}
