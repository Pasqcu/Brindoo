//
//  EventChecklistView.swift
//  Brindoo
//
//  Checklist locale per un evento confermato: compiti standard con scadenze
//  calcolate sulla data dell'evento, spuntabili. Salvata sul dispositivo.
//

import SwiftUI

/// Voce della checklist con scadenza relativa alla data dell'evento.
private struct ChecklistTask: Identifiable {
    /// Chiave stabile usata per salvare la spunta.
    let key: String
    let title: String
    /// Scadenza: data evento meno questi giorni.
    let daysBefore: Int

    var id: String { key }
}

struct EventChecklistView: View {

    @Environment(\.dismiss) private var dismiss

    let proposalId: UUID
    let eventDate: Date
    let offerTitle: String

    @State private var done: Set<String> = []

    private static let tasks: [ChecklistTask] = [
        .init(key: "conferma-dettagli", title: "Conferma i dettagli con il professionista", daysBefore: 30),
        .init(key: "luogo-orari", title: "Ricontrolla luogo e orari", daysBefore: 14),
        .init(key: "ospiti", title: "Conferma il numero di ospiti", daysBefore: 7),
        .init(key: "acconto", title: "Accordati su acconto e pagamento", daysBefore: 7),
        .init(key: "contatti", title: "Scambia i contatti per il giorno dell'evento", daysBefore: 1),
    ]

    private var storageKey: String { "event-checklist-\(proposalId.uuidString)" }

    private var progress: Double {
        Double(done.count) / Double(Self.tasks.count)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BrindooSpacing.lg) {
                    header

                    VStack(spacing: BrindooSpacing.sm) {
                        ForEach(Self.tasks) { task in
                            taskRow(task)
                        }
                    }
                }
                .padding(BrindooSpacing.lg)
                .brindooReadableWidth()
            }
            .background(Color.brindooBackground)
            .navigationTitle("Checklist evento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chiudi") { dismiss() }
                }
            }
            .onAppear(perform: load)
        }
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
            Text(offerTitle)
                .font(BrindooFont.titleSmall)
                .foregroundStyle(Color.brindooTextPrimary)
            Text(eventDate.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "it_IT"))))
                .font(BrindooFont.bodySmall)
                .foregroundStyle(Color.brindooTextSecondary)

            ProgressView(value: progress)
                .tint(progress == 1 ? Color.brindooSuccess : Color.brindooCoral)
                .padding(.top, BrindooSpacing.xs)

            Text(progress == 1
                 ? "Tutto pronto per il grande giorno! 🎉"
                 : "\(done.count) su \(Self.tasks.count) completati")
                .font(BrindooFont.caption)
                .foregroundStyle(progress == 1 ? Color.brindooSuccess : Color.brindooTextSecondary)
        }
        .padding(BrindooSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brindooSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
    }

    @ViewBuilder
    private func taskRow(_ task: ChecklistTask) -> some View {
        let isDone = done.contains(task.key)

        Button {
            if isDone {
                done.remove(task.key)
            } else {
                done.insert(task.key)
                BrindooHaptics.notify(.success)
            }
            save()
        } label: {
            HStack(spacing: BrindooSpacing.sm) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isDone ? Color.brindooSuccess : Color.brindooBorder)

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(BrindooFont.bodyMedium)
                        .foregroundStyle(Color.brindooTextPrimary)
                        .strikethrough(isDone, color: Color.brindooTextSecondary)
                        .multilineTextAlignment(.leading)
                    Text(dueLabel(task))
                        .font(BrindooFont.caption)
                        .foregroundStyle(isOverdue(task) && !isDone ? Color.brindooError : Color.brindooTextSecondary)
                }

                Spacer()
            }
            .padding(BrindooSpacing.md)
            .background(Color.brindooSurface)
            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Scadenze

    private func dueDate(_ task: ChecklistTask) -> Date {
        Calendar.current.date(byAdding: .day, value: -task.daysBefore, to: eventDate) ?? eventDate
    }

    private func isOverdue(_ task: ChecklistTask) -> Bool {
        dueDate(task) < Calendar.current.startOfDay(for: Date())
    }

    private func dueLabel(_ task: ChecklistTask) -> String {
        let day = dueDate(task).formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "it_IT")))
        return "Entro il \(day)"
    }

    // MARK: - Salvataggio locale

    private func load() {
        done = Set(UserDefaults.standard.stringArray(forKey: storageKey) ?? [])
    }

    private func save() {
        UserDefaults.standard.set(Array(done), forKey: storageKey)
    }
}
