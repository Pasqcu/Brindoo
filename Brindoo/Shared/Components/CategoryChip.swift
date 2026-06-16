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
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

#Preview {
    HStack {
        CategoryChip(category: nil, isSelected: true) {}
        CategoryChip(category: .preview, isSelected: false) {}
    }
    .padding()
}
