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
    /// Giorni già impegnati da eventi confermati: l'app li conosce da sé,
    /// qui si mostrano soltanto perché chi guarda il calendario deve
    /// vederli senza andarli a cercare in agenda.
    @State private var booked: [Date] = []
    @State private var isLoading: Bool = true
    @State private var isSaving: Bool = false
    @State private var error: String?

    private let calendar = BrindooFormat.dayCalendar

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BrindooSpacing.md) {
                    HStack(alignment: .top, spacing: BrindooSpacing.sm) {
                        Image(systemName: BrindooIcon.info)
                            .foregroundStyle(Color.brindooCoral)
                        Text("Tocca i giorni in cui non sei disponibile. I clienti non potranno fissare l'evento in quelle date. I giorni degli eventi già confermati risultano occupati da soli.")
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
                            .brindooSurfaceBackground()

                        Text("\(selected.count) giorni segnati come non disponibili")
                            .font(BrindooFont.caption)
                            .foregroundStyle(Color.brindooTextSecondary)

                        if !booked.isEmpty {
                            bookedSection
                        }
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

    /// Elenco di sola lettura: questi giorni non si tolgono da qui, si
    /// liberano annullando o spostando l'evento.
    @ViewBuilder
    private var bookedSection: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
            HStack(spacing: BrindooSpacing.xxs) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 12))
                Text("Già impegnato con eventi confermati")
                    .font(BrindooFont.caption.weight(.semibold))
            }
            .foregroundStyle(Color.brindooSuccess)

            ForEach(booked, id: \.self) { day in
                Text(BrindooFormat.italianDate(from: day))
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooTextSecondary)
            }

            Text("Per liberare uno di questi giorni sposta o annulla l'evento dall'agenda.")
                .font(BrindooFont.caption)
                .foregroundStyle(Color.brindooTextTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(BrindooSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brindooSurfaceBackground()
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let dates = try await AvailabilityService.shared.fetchMyUnavailableDays()
            selected = Set(dates.map { calendar.dateComponents([.year, .month, .day], from: $0) })
            let today = calendar.startOfDay(for: Date())
            booked = ((try? await AvailabilityService.shared.fetchMyBookedDays()) ?? [])
                .filter { $0 >= today }
                .sorted()
        } catch {
            self.error = BrindooText.loadError("il calendario.")
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
