//
//  BrindooConfettiView.swift
//  Brindoo
//
//  Breve pioggia di coriandoli per i momenti di festa (trattativa conclusa).
//  Si anima da sola all'apparizione e non intercetta i tocchi.
//

import SwiftUI

private let confettiPalette: [Color] = [
    Color(red: 1.00, green: 0.45, blue: 0.38),  // corallo
    Color(red: 1.00, green: 0.72, blue: 0.30),  // oro
    Color(red: 0.35, green: 0.78, blue: 0.60),  // verde
    Color(red: 0.42, green: 0.60, blue: 0.98),  // blu
    Color(red: 0.95, green: 0.55, blue: 0.85)   // rosa
]

struct BrindooConfettiView: View {

    /// Un singolo coriandolo con traiettoria pre-calcolata.
    private struct Piece: Identifiable {
        let id = UUID()
        let x: CGFloat          // posizione orizzontale relativa (0–1)
        let delay: Double
        let duration: Double
        let size: CGFloat
        let color: Color
        let rotations: Double
        let isCircle: Bool
        let drift: CGFloat      // spostamento orizzontale durante la caduta
    }

    private let pieces: [Piece] = (0..<36).map { _ in
        Piece(
            x: .random(in: 0.02...0.98),
            delay: .random(in: 0...0.35),
            duration: .random(in: 1.4...2.2),
            size: .random(in: 7...12),
            color: confettiPalette.randomElement() ?? .orange,
            rotations: .random(in: 1.5...4) * (Bool.random() ? 1 : -1),
            isCircle: Bool.random(),
            drift: .random(in: -60...60)
        )
    }

    @State private var falling = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    Group {
                        if piece.isCircle {
                            Circle().fill(piece.color)
                        } else {
                            RoundedRectangle(cornerRadius: 2).fill(piece.color)
                        }
                    }
                    .frame(width: piece.size, height: piece.size * (piece.isCircle ? 1 : 0.55))
                    .rotationEffect(.degrees(falling ? piece.rotations * 360 : 0))
                    .position(
                        x: geo.size.width * piece.x + (falling ? piece.drift : 0),
                        y: falling ? geo.size.height + 30 : -30
                    )
                    .opacity(falling ? 0.9 : 1)
                    .animation(
                        .easeIn(duration: piece.duration).delay(piece.delay),
                        value: falling
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .onAppear { falling = true }
        .accessibilityHidden(true)
    }
}

#Preview {
    ZStack {
        Color.white
        BrindooConfettiView()
    }
}
