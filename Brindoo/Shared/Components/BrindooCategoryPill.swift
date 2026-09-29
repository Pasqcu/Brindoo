//
//  BrindooCategoryPill.swift
//  Brindoo
//
//  Pillola di una categoria di servizio (scelta nei moduli e nel preventivo).
//

import SwiftUI

/// Pastiglia corallo per scegliere una categoria dentro un modulo: creazione
/// offerta, richiesta del cliente, preventivo guidato.
///
/// Diversa dai filtri della bacheca, che usano la tinta di ogni categoria:
/// qui il corallo pieno dice "l'ho scelta". Va dentro un `Button`, che
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
        .background(isSelected ? Color.brindooCoralFill : Color.brindooCoral.opacity(0.1))
        .clipShape(Capsule())
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    VStack {
        HStack {
            BrindooCategoryPill(category: .preview, isSelected: true)
            BrindooCategoryPill(category: .preview, isSelected: false)
        }
    }
    .padding()
}
