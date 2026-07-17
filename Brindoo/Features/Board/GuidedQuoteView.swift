//
//  GuidedQuoteView.swift
//  Brindoo
//
//  Preventivo guidato: il cliente indica categoria, data e budget
//  e ottiene subito le offerte adatte, escludendo i professionisti
//  già occupati nella data scelta.
//

import SwiftUI

struct GuidedQuoteView: View {

    @State private var categories: [ServiceCategory] = []
    @State private var selectedCategoryId: UUID?
    @State private var hasDate: Bool
    @State private var eventDate: Date
    @State private var budget: String = ""

    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var searchFailed = false
    @State private var results: [ServiceOffer] = []

    /// `prefilledDate`: data già nota (es. arrivando da "Completa il tuo evento").
    init(prefilledDate: Date? = nil) {
        _hasDate = State(initialValue: prefilledDate != nil)
        _eventDate = State(initialValue: prefilledDate
            ?? Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrindooSpacing.lg) {

                Text("Rispondi a tre domande: ti mostriamo subito i professionisti adatti.")
                    .font(BrindooFont.bodySmall)
                    .foregroundStyle(Color.brindooTextSecondary)

                stepCategory
                stepDate
                stepBudget

                BrindooButton(
                    "Trova professionisti",
                    style: .primary,
                    size: .large,
                    isLoading: isSearching
                ) {
                    Task { await search() }
                }
                .disabled(selectedCategoryId == nil)

                if hasSearched {
                    resultsSection
                }
            }
            .padding(BrindooSpacing.lg)
            .brindooReadableWidth()
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.brindooBackground)
        .navigationTitle("Preventivo guidato")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            categories = (try? await CategoryService.shared.fetchCategories()) ?? []
        }
    }

    // MARK: - Passi

    @ViewBuilder
    private var stepCategory: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
            stepTitle(number: 1, text: "Che cosa ti serve?")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: BrindooSpacing.xs) {
                    ForEach(categories) { cat in
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
                        .disabled(isSearching)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var stepDate: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
            stepTitle(number: 2, text: "Quando?")
            Toggle(isOn: $hasDate) {
                Text("Ho già una data")
                    .font(BrindooFont.bodyMedium)
            }
            .tint(Color.brindooCoral)
            .disabled(isSearching)

            if hasDate {
                DatePicker(
                    "Data dell'evento",
                    selection: $eventDate,
                    in: Date()...,
                    displayedComponents: .date
                )
                .environment(\.locale, Locale(identifier: "it_IT"))
                .font(BrindooFont.bodyMedium)

                Text("Escludiamo chi risulta già occupato quel giorno.")
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooTextSecondary)
            }
        }
        .padding(BrindooSpacing.md)
        .background(Color.brindooSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
    }

    @ViewBuilder
    private var stepBudget: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
            stepTitle(number: 3, text: "Quanto vuoi spendere?")
            BrindooTextField(
                title: "Budget massimo in € (opzionale)",
                placeholder: "Es. 800",
                text: $budget,
                icon: "eurosign.circle",
                keyboardType: .decimalPad,
                isDisabled: isSearching
            )
        }
    }

    @ViewBuilder
    private func stepTitle(number: Int, text: String) -> some View {
        HStack(spacing: BrindooSpacing.xs) {
            Text("\(number)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.brindooCoral)
                .clipShape(Circle())
            Text(text)
                .font(BrindooFont.titleSmall)
                .foregroundStyle(Color.brindooTextPrimary)
        }
    }

    // MARK: - Risultati

    @ViewBuilder
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
            if searchFailed {
                BrindooErrorState(message: "Ricerca non riuscita") {
                    Task { await search() }
                }
            } else if results.isEmpty {
                BrindooEmptyState(
                    icon: "magnifyingglass",
                    title: "Nessuna offerta adatta",
                    message: "Prova ad alzare il budget o a togliere la data."
                )
            } else {
                Text("\(results.count) offerte adatte, dalla più conveniente")
                    .font(BrindooFont.titleSmall)
                    .foregroundStyle(Color.brindooTextPrimary)
                ForEach(results) { offer in
                    resultRow(offer)
                }
            }
        }
    }

    @ViewBuilder
    private func resultRow(_ offer: ServiceOffer) -> some View {
        NavigationLink {
            OfferDetailView(offer: offer)
        } label: {
            HStack(spacing: BrindooSpacing.sm) {
                thumbnail(offer)

                VStack(alignment: .leading, spacing: 2) {
                    Text(offer.title)
                        .font(BrindooFont.bodyMedium.weight(.semibold))
                        .foregroundStyle(Color.brindooTextPrimary)
                        .lineLimit(1)
                    Text(offer.coverageArea)
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(offer.priceDisplay)
                    .font(BrindooFont.bodyMedium.weight(.semibold))
                    .foregroundStyle(Color.brindooCoral)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.brindooTextSecondary)
            }
            .padding(BrindooSpacing.md)
            .background(Color.brindooSurface)
            .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func thumbnail(_ offer: ServiceOffer) -> some View {
        Group {
            if let urlString = offer.imageUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Color.brindooBorder.opacity(0.3)
                    }
                }
            } else {
                ZStack {
                    Color.brindooCoral.opacity(0.1)
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.brindooCoral)
                }
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
    }

    // MARK: - Ricerca

    private func search() async {
        guard let catId = selectedCategoryId else { return }
        isSearching = true
        searchFailed = false
        defer {
            isSearching = false
            hasSearched = true
        }
        do {
            var offers = try await ServiceOfferService.shared
                .fetchActiveOffers(categoryFilters: [catId])

            if hasDate {
                let busy = (try? await AvailabilityService.shared
                    .fetchBusyOrganizerIds(on: eventDate)) ?? []
                offers.removeAll { busy.contains($0.organizerId) }
            }

            if let max = Double(budget.replacingOccurrences(of: ",", with: ".")), max > 0 {
                offers.removeAll { $0.price > max }
            }

            results = offers.sorted { $0.price < $1.price }
        } catch {
            searchFailed = true
            BrindooLog.error("Preventivo guidato: \(error)")
        }
    }
}
