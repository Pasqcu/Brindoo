//
//  CategoryChip.swift
//  Brindoo
//
//  Chip orizzontale per la lista categorie nella tab Esplora.
//

import SwiftUI

struct CategoryChip: View {
    
    let category: ServiceCategory?  // nil = "Tutte"
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: BrindooSpacing.xs) {
                if let category {
                    Image(systemName: category.icon)
                        .font(.system(size: 14, weight: .medium))
                }
                
                Text(category?.name ?? "Tutte")
                    .font(BrindooFont.bodySmall.weight(.medium))
            }
            .foregroundStyle(isSelected ? .white : Color.brindooTextPrimary)
            .padding(.horizontal, BrindooSpacing.md)
            .padding(.vertical, BrindooSpacing.xs)
            .background(
                isSelected ? Color.brindooCoral : Color.brindooSurface
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? Color.clear : Color.brindooBorder,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(BrindooAnimation.quickEase, value: isSelected)
    }
}

/// Pastiglia corallo per scegliere una categoria dentro un modulo: creazione
/// offerta, richiesta del cliente, preventivo guidato.
///
/// Diversa da `CategoryChip`, che filtra la bacheca: lì il colore dice "sto
/// guardando questa", qui dice "l'ho scelta". Va dentro un `Button`, che
/// gestisce il tocco; qui restano aspetto e stato per VoiceOver — che prima
/// mancava, quindi a voce le categorie scelte non si distinguevano.
struct BrindooCategoryPill: View {
    let category: ServiceCategory
    let isSelected: Bool

    var body: some View {
        HStack(spacing: BrindooSpacing.xxs) {
            Image(systemName: category.icon)
                .font(BrindooFont.scaled(12, relativeTo: .caption1))
            Text(category.name)
                .font(BrindooFont.bodySmall.weight(.medium))
        }
        .padding(.horizontal, BrindooSpacing.sm)
        .padding(.vertical, BrindooSpacing.xs)
        .foregroundStyle(isSelected ? .white : Color.brindooCoral)
        .background(isSelected ? Color.brindooCoral : Color.brindooCoral.opacity(0.1))
        .clipShape(Capsule())
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    VStack {
        HStack {
            CategoryChip(category: nil, isSelected: true) {}
            CategoryChip(category: .preview, isSelected: false) {}
        }
        HStack {
            BrindooCategoryPill(category: .preview, isSelected: true)
            BrindooCategoryPill(category: .preview, isSelected: false)
        }
    }
    .padding()
}
