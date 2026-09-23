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
    @State private var isImporting: Bool = false
    @State private var importedCount: Int?
    @State private var error: String?
    /// Eventi saltati perché il cliente ha eliminato l'account.
    @State private var notices: [AvailabilityService.CancellationNotice] = []
    @State private var noticeToResolve: AvailabilityService.CancellationNotice?

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

                    if !notices.isEmpty {
                        noticesSection
                    }

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

                        Text(selected.count == 1
                             ? "1 giorno segnato come non disponibile"
                             : "\(selected.count) giorni segnati come non disponibili")
                            .font(BrindooFont.caption)
                            .foregroundStyle(Color.brindooTextSecondary)

                        // Chi ha il calendario pieno fuori da Brindoo risulterebbe
                        // "libero": un tocco e gli impegni diventano giorni occupati.
                        BrindooButton(
                            isImporting ? "Importo..." : "Importa impegni dal calendario",
                            style: .secondary, size: .medium, icon: "calendar.badge.plus"
                        ) {
                            Task { await importFromDeviceCalendar() }
                        }
                        .disabled(isImporting)

                        if let importedCount {
                            Text(importedCount == 0
                                 ? "Nessun impegno nuovo nei prossimi 6 mesi."
                                 : "\(importedCount) giorni aggiunti dal calendario. Controlla e salva.")
                                .font(BrindooFont.caption)
                                .foregroundStyle(Color.brindooSuccess)
                        }

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

    /// Date da controllare, in rosso: tocca per decidere.
    @ViewBuilder
    private var noticesSection: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
            HStack(spacing: BrindooSpacing.xs) {
                Image(systemName: BrindooIcon.warning)
                Text("Eventi annullati: date da controllare")
                    .font(BrindooFont.titleSmall)
            }
            .foregroundStyle(Color.brindooError)

            ForEach(notices) { notice in
                Button { noticeToResolve = notice } label: {
                    HStack(alignment: .top, spacing: BrindooSpacing.sm) {
                        Text(noticeDayText(notice))
                            .font(BrindooFont.bodyMedium.weight(.semibold))
                            .foregroundStyle(Color.brindooError)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(notice.counterpartName ?? "Il cliente") ha eliminato l'account")
                                .font(BrindooFont.bodySmall)
                                .foregroundStyle(Color.brindooTextPrimary)
                            if let title = notice.offerTitle {
                                Text("«\(title)» non è più in agenda")
                                    .font(BrindooFont.caption)
                                    .foregroundStyle(Color.brindooTextSecondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.brindooTextTertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(BrindooSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brindooError.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: BrindooRadius.md)
                .strokeBorder(Color.brindooError.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
        // Agganciato all'elenco: il riquadro di scelta si apre vicino alle date.
        .confirmationDialog(
            "Vuoi liberare questa data?",
            isPresented: Binding(
                get: { noticeToResolve != nil },
                set: { if !$0 { noticeToResolve = nil } }
            ),
            titleVisibility: .visible,
            presenting: noticeToResolve
        ) { notice in
            Button("Libera la data") { Task { await resolve(notice, keepBusy: false) } }
            Button("Tienila occupata") { Task { await resolve(notice, keepBusy: true) } }
            Button("Decido dopo", role: .cancel) {}
        } message: { notice in
            Text("L'evento del \(noticeDayText(notice)) è stato annullato. Se la liberi, i clienti potranno prenotarti quel giorno.")
        }
    }

    private func noticeDayText(_ notice: AvailabilityService.CancellationNotice) -> String {
        notice.day.map { BrindooFormat.italianDate(from: $0) } ?? notice.eventDate
    }

    private func resolve(_ notice: AvailabilityService.CancellationNotice, keepBusy: Bool) async {
        noticeToResolve = nil
        do {
            try await AvailabilityService.shared.resolveCancellationNotice(notice, keepBusy: keepBusy)
            notices.removeAll { $0.id == notice.id }
            if keepBusy, let day = notice.day {
                selected.insert(calendar.dateComponents([.year, .month, .day], from: day))
            }
            BrindooHaptics.notify(.success)
        } catch {
            self.error = "Impossibile aggiornare la data. Riprova."
            BrindooLog.error("\(error)")
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
            notices = (try? await AvailabilityService.shared.fetchMyCancellationNotices()) ?? []
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

    /// Unisce gli impegni del calendario iOS ai giorni già selezionati.
    /// Non salva da solo: la persona vede cosa è entrato e conferma con "Salva".
    private func importFromDeviceCalendar() async {
        isImporting = true
        defer { isImporting = false }
        error = nil
        do {
            let busy = try await CalendarService.fetchDeviceBusyDays()
            let before = selected.count
            selected.formUnion(busy.map { calendar.dateComponents([.year, .month, .day], from: $0) })
            importedCount = selected.count - before
            if importedCount != 0 { BrindooHaptics.notify(.success) }
        } catch {
            self.error = error.localizedDescription
            BrindooLog.error("Import calendario: \(error)")
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
