//
//  OfferPackagesSection.swift
//  Brindoo
//
//  Pacchetti prezzo di un'offerta:
//  - OfferPackagesEditor: nel form di creazione (fino a 3 pacchetti)
//  - OfferPackagesDisplay: nel dettaglio offerta (con selezione lato cliente)
//

import SwiftUI

// MARK: - Bozza pacchetto (form di creazione)

struct DraftOfferPackage: Identifiable, Equatable {
    let id = UUID()
    var name: String = ""
    var price: String = ""
    var description: String = ""
}

// MARK: - Editor (CreateOfferView)

struct OfferPackagesEditor: View {
    @Binding var packages: [DraftOfferPackage]
    let isDisabled: Bool

    private static let suggestedNames = ["Base", "Completo", "Premium"]
    private let maxPackages = 3

    var body: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.sm) {
            Text("Pacchetti (opzionale)")
                .font(BrindooFont.bodySmall.weight(.medium))
                .foregroundStyle(Color.brindooTextSecondary)
            Text("Offri fino a 3 versioni del servizio (es. Base, Completo, Premium): i clienti scelgono e accettano più volentieri.")
                .font(BrindooFont.caption)
                .foregroundStyle(Color.brindooTextSecondary)

            ForEach($packages) { $package in
                VStack(spacing: BrindooSpacing.xs) {
                    HStack(spacing: BrindooSpacing.xs) {
                        TextField("Nome (es. Base)", text: $package.name)
                            .font(BrindooFont.bodyMedium)
                        TextField("€", text: $package.price)
                            .font(BrindooFont.bodyMedium)
                            .keyboardType(.numberPad)
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                        Button {
                            packages.removeAll { $0.id == package.id }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.brindooTextSecondary)
                        }
                        .disabled(isDisabled)
                    }
                    TextField("Cosa include (opzionale)", text: $package.description)
                        .font(BrindooFont.bodySmall)
                }
                .padding(BrindooSpacing.sm)
                .background(Color.brindooSurface)
                .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: BrindooRadius.sm)
                        .strokeBorder(Color.brindooBorder, lineWidth: 1)
                )
                .disabled(isDisabled)
            }

            if packages.count < maxPackages {
                Button {
                    var draft = DraftOfferPackage()
                    draft.name = Self.suggestedNames.indices.contains(packages.count)
                        ? Self.suggestedNames[packages.count] : ""
                    packages.append(draft)
                } label: {
                    Label(
                        packages.isEmpty ? "Aggiungi pacchetti" : "Aggiungi un altro pacchetto",
                        systemImage: "plus.circle"
                    )
                    .font(BrindooFont.bodySmall.weight(.semibold))
                    .foregroundStyle(Color.brindooCoral)
                }
                .buttonStyle(.plain)
                .disabled(isDisabled)
            }
        }
    }
}

// MARK: - Vetrina pacchetti (OfferDetailView)

struct OfferPackagesDisplay: View {
    let packages: [OfferPackage]
    /// Pacchetto selezionato dal cliente (nil = nessuna selezione / sola lettura).
    var selectedId: Binding<UUID?>? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
            Text("Pacchetti")
                .font(BrindooFont.titleSmall)

            ForEach(packages) { package in
                let isSelected = selectedId?.wrappedValue == package.id

                Group {
                    if let selectedId {
                        Button {
                            selectedId.wrappedValue = isSelected ? nil : package.id
                        } label: {
                            packageRow(package, isSelected: isSelected, selectable: true)
                        }
                        .buttonStyle(.plain)
                    } else {
                        packageRow(package, isSelected: false, selectable: false)
                    }
                }
            }

            if selectedId != nil {
                Text("Scegli un pacchetto oppure tratta sul prezzo base.")
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooTextSecondary)
            }
        }
    }

    @ViewBuilder
    private func packageRow(_ package: OfferPackage, isSelected: Bool, selectable: Bool) -> some View {
        HStack(alignment: .top, spacing: BrindooSpacing.sm) {
            if selectable {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Color.brindooCoral : Color.brindooTextTertiary)
                    .padding(.top, 2)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(package.name)
                    .font(BrindooFont.bodyMedium.weight(.semibold))
                    .foregroundStyle(Color.brindooTextPrimary)
                if let description = package.description, !description.isEmpty {
                    Text(description)
                        .font(BrindooFont.caption)
                        .foregroundStyle(Color.brindooTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            Text(package.priceDisplay)
                .font(BrindooFont.titleSmall)
                .foregroundStyle(Color.brindooCoral)
        }
        .padding(BrindooSpacing.md)
        .background(isSelected ? Color.brindooCoral.opacity(0.06) : Color.brindooSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: BrindooRadius.md)
                .strokeBorder(
                    isSelected ? Color.brindooCoral.opacity(0.5) : Color.brindooBorder,
                    lineWidth: isSelected ? 1.5 : 1
                )
        )
    }
}
