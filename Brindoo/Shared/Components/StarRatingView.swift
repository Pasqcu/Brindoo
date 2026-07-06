//
//  StarRatingView.swift
//  Brindoo
//
//  Componente riutilizzabile per visualizzare/selezionare un rating a stelle.
//

import SwiftUI

/// Modalità: solo display (read-only) o input interattivo
enum StarRatingMode {
    case display
    case input
}

struct StarRatingView: View {
    
    let rating: Double
    var maxRating: Int = 5
    var mode: StarRatingMode = .display
    var size: CGFloat = 16
    var spacing: CGFloat = 2
    var color: Color = .brindooCoral
    
    /// Binding usato solo in modalità input
    var onChange: ((Int) -> Void)? = nil

    /// Stella appena toccata: rimbalza per un attimo (solo input).
    @State private var bouncingIndex: Int? = nil

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(1...maxRating, id: \.self) { index in
                starView(for: index)
            }
        }
    }

    @ViewBuilder
    private func starView(for index: Int) -> some View {
        let value = Double(index)
        let isFilled = rating >= value
        let isHalf = !isFilled && rating >= value - 0.5

        Group {
            if mode == .input {
                Button {
                    BrindooHaptics.impact(.light)
                    bouncingIndex = index
                    onChange?(index)
                    Task {
                        try? await Task.sleep(nanoseconds: 280_000_000)
                        bouncingIndex = nil
                    }
                } label: {
                    starImage(filled: isFilled, half: false)
                        .scaleEffect(bouncingIndex == index ? 1.35 : 1.0)
                        .rotationEffect(.degrees(bouncingIndex == index ? -8 : 0))
                        .animation(.spring(response: 0.25, dampingFraction: 0.45), value: bouncingIndex)
                }
                .buttonStyle(.plain)
            } else {
                starImage(filled: isFilled, half: isHalf)
            }
        }
    }
    
    @ViewBuilder
    private func starImage(filled: Bool, half: Bool) -> some View {
        Image(systemName: half ? "star.leadinghalf.filled" : (filled ? "star.fill" : "star"))
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(filled || half ? color : Color.brindooBorder)
    }
}

// MARK: - Compact rating (stella + numero)

/// Mostra rating compatto: "★ 4.7 (12)"
struct CompactRatingView: View {
    let rating: OrganizerRating
    var size: CGFloat = 14
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: size - 2))
                .foregroundStyle(rating.reviewCount > 0 ? Color.brindooCoral : Color.brindooBorder)
            
            if rating.reviewCount > 0 {
                Text(rating.displayRating)
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(Color.brindooTextPrimary)
                
                Text("(\(rating.reviewCount))")
                    .font(.system(size: size - 1))
                    .foregroundStyle(Color.brindooTextSecondary)
            } else {
                Text("Nuovo")
                    .font(.system(size: size - 1))
                    .foregroundStyle(Color.brindooTextSecondary)
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        StarRatingView(rating: 4.5, mode: .display, size: 20)
        StarRatingView(rating: 3.0, mode: .input, size: 28) { newValue in
            print("Tap: \(newValue)")
        }
        CompactRatingView(rating: OrganizerRating(organizerId: UUID(), avgRating: 4.7, reviewCount: 23))
        CompactRatingView(rating: OrganizerRating(organizerId: UUID(), avgRating: 0, reviewCount: 0))
    }
    .padding()
}
