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
        if mode == .input {
            HStack(spacing: spacing) {
                ForEach(1...maxRating, id: \.self) { index in
                    starView(for: index)
                }
            }
        } else {
            // In sola lettura VoiceOver legge il voto una volta, non cinque
            // "stella" di fila.
            HStack(spacing: spacing) {
                ForEach(1...maxRating, id: \.self) { index in
                    starView(for: index)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Valutazione \(BrindooFormat.rating(rating)) su \(maxRating)")
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
                        try? await Task.sleep(for: .milliseconds(280))
                        bouncingIndex = nil
                    }
                } label: {
                    starImage(filled: isFilled, half: false)
                        .scaleEffect(bouncingIndex == index ? 1.35 : 1.0)
                        .rotationEffect(.degrees(bouncingIndex == index ? -8 : 0))
                        .animation(.spring(response: 0.25, dampingFraction: 0.45), value: bouncingIndex)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(index == 1 ? "1 stella" : "\(index) stelle")
                .accessibilityAddTraits(Int(rating) == index ? [.isSelected] : [])
            } else {
                starImage(filled: isFilled, half: isHalf)
            }
        }
    }
    
    @ViewBuilder
    private func starImage(filled: Bool, half: Bool) -> some View {
        Image(systemName: half ? BrindooIcon.starHalf : (filled ? BrindooIcon.starFilled : BrindooIcon.star))
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(filled || half ? color : Color.brindooBorder)
    }
}

#Preview {
    VStack(spacing: 20) {
        StarRatingView(rating: 4.5, mode: .display, size: 20)
        StarRatingView(rating: 3.0, mode: .input, size: 28) { newValue in
        }
    }
    .padding()
}
