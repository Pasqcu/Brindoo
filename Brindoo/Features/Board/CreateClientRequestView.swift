//
//  CreateClientRequestView.swift
//  Brindoo
//
//  Form con cui il cliente pubblica una richiesta in bacheca inversa:
//  cosa cerca, dove, quando e con quale budget indicativo.
//

import SwiftUI

struct CreateClientRequestView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var area: String = ""
    @State private var budget: String = ""

    @State private var hasEventDate: Bool = false
    @State private var eventDate: Date = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()

    @State private var allCategories: [ServiceCategory] = []
    @State private var selectedCategoryId: UUID?

    @State private var titleError: String?
    @State private var areaError: String?
    @State private var generalError: String?
    @State private var isSaving: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BrindooSpacing.lg) {

                    Text("Racconta cosa ti serve: i professionisti giusti ti contatteranno in chat.")
                        .font(BrindooFont.bodySmall)
                        .foregroundStyle(Color.brindooTextSecondary)

                    BrindooTextField(
                        title: "Cosa cerchi?",
                        placeholder: "Es. Fotografo per matrimonio",
                        text: $title,
                        icon: "megaphone",
                        errorMessage: titleError,
                        isDisabled: isSaving
                    )

                    // Categoria (facoltativa)
                    if !allCategories.isEmpty {
                        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
                            Text("Categoria (opzionale)")
                                .font(BrindooFont.bodySmall.weight(.medium))
                                .foregroundStyle(Color.brindooTextSecondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: BrindooSpacing.xs) {
                                    ForEach(allCategories) { cat in
                                        let isSelected = selectedCategoryId == cat.id
                                        Button {
                                            selectedCategoryId = isSelected ? nil : cat.id
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: cat.icon).font(.system(size: 12))
                                                Text(cat.name).font(BrindooFont.bodySmall.weight(.medium))
                                            }
                                            .padding(.horizontal, BrindooSpacing.sm)
                                            .padding(.vertical, BrindooSpacing.xs)
                                            .foregroundStyle(isSelected ? .white : Color.brindooCoral)
                                            .background(isSelected ? Color.brindooCoral : Color.brindooCoral.opacity(0.1))
                                            .clipShape(Capsule())
                                        }
                                        .disabled(isSaving)
                                    }
                                }
                            }
                        }
                    }

                    BrindooTextField(
                        title: "Zona dell'evento",
                        placeholder: "Es. Latina e dintorni",
                        text: $area,
                        icon: "mappin.and.ellipse",
                        errorMessage: areaError,
                        isDisabled: isSaving
                    )

                    // Data evento (facoltativa)
                    VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
                        Toggle(isOn: $hasEventDate) {
                            Text("Ho già una data")
                                .font(BrindooFont.bodyMedium)
                        }
                        .tint(Color.brindooCoral)
                        .disabled(isSaving)

                        if hasEventDate {
                            DatePicker(
                                "Data dell'evento",
                                selection: $eventDate,
                                in: Date()...,
                                displayedComponents: .date
                            )
                            .environment(\.locale, Locale(identifier: "it_IT"))
                            .font(BrindooFont.bodyMedium)
                        }
                    }
                    .padding(BrindooSpacing.md)
                    .background(Color.brindooSurface)
                    .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))

                    BrindooTextField(
                        title: "Budget indicativo in € (opzionale)",
                        placeholder: "Es. 800",
                        text: $budget,
                        icon: "eurosign.circle",
                        keyboardType: .decimalPad,
                        isDisabled: isSaving
                    )

                    // Dettagli (facoltativi)
                    VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
                        Text("Dettagli (opzionale)")
                            .font(BrindooFont.bodySmall.weight(.medium))
                            .foregroundStyle(Color.brindooTextSecondary)
                        TextField(
                            "Numero di invitati, stile, orari…",
                            text: $description,
                            axis: .vertical
                        )
                        .lineLimit(3...8)
                        .font(BrindooFont.bodyLarge)
                        .padding(BrindooSpacing.md)
                        .background(Color.brindooSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: BrindooRadius.md)
                                .strokeBorder(Color.brindooBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
                        .disabled(isSaving)
                    }

                    if let generalError {
                        HStack(spacing: BrindooSpacing.xs) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(generalError).font(BrindooFont.bodySmall)
                        }
                        .foregroundStyle(Color.brindooError)
                        .padding(BrindooSpacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.brindooError.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
                    }
                }
                .padding(BrindooSpacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.brindooBackground)
            .navigationTitle("Nuova richiesta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annulla") { dismiss() }
                        .disabled(isSaving)
                }
            }
            .safeAreaInset(edge: .bottom) {
                BrindooButton(
                    "Pubblica richiesta",
                    style: .primary,
                    size: .large,
                    isLoading: isSaving
                ) {
                    Task { await save() }
                }
                .padding(.horizontal, BrindooSpacing.lg)
                .padding(.vertical, BrindooSpacing.sm)
                .background(
                    Color.brindooBackground
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: -2)
                )
            }
            .task {
                allCategories = (try? await CategoryService.shared.fetchCategories()) ?? []
            }
        }
    }

    private func save() async {
        titleError = nil
        areaError = nil
        generalError = nil

        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedArea = area.trimmingCharacters(in: .whitespaces)
        let trimmedDesc = description.trimmingCharacters(in: .whitespaces)

        var hasError = false
        if trimmedTitle.count < 5 {
            titleError = "Descrivi in poche parole cosa cerchi"
            hasError = true
        }
        if trimmedArea.count < 2 {
            areaError = "Indica la zona dell'evento"
            hasError = true
        }

        let budgetValue = Double(budget.replacingOccurrences(of: ",", with: "."))
        if !budget.trimmingCharacters(in: .whitespaces).isEmpty && (budgetValue == nil || budgetValue! <= 0) {
            generalError = "Il budget non è un numero valido."
            hasError = true
        }
        if hasError { return }

        var eventDateString: String?
        if hasEventDate {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.timeZone = TimeZone(identifier: "UTC")
            eventDateString = f.string(from: eventDate)
        }

        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await ClientRequestService.shared.create(
                title: trimmedTitle,
                description: trimmedDesc.isEmpty ? nil : trimmedDesc,
                area: trimmedArea,
                eventDate: eventDateString,
                budget: budgetValue,
                categoryId: selectedCategoryId
            )
            BrindooHaptics.notify(.success)
            dismiss()
        } catch {
            generalError = "Impossibile pubblicare. Riprova più tardi."
            BrindooLog.error("Creazione richiesta: \(error)")
        }
    }
}
