//
//  TypingIndicatorView.swift
//  Brindoo
//
//  Indicatore animato "sta scrivendo..." con tre pallini bouncing.
//

import SwiftUI
import Combine

struct TypingIndicatorView: View {
    let name: String?

    @State private var phase: Int = 0
    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: BrindooSpacing.xs) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.brindooCoral)
                        .frame(width: 6, height: 6)
                        .opacity(phase == i ? 1.0 : 0.35)
                        .scaleEffect(phase == i ? 1.3 : 1.0)
                        .animation(BrindooAnimation.snappy, value: phase)
                }
            }
            .padding(.horizontal, BrindooSpacing.sm)
            .padding(.vertical, BrindooSpacing.xs)
            .background(Color.brindooSurface)
            .clipShape(Capsule())

            if let name {
                Text("\(name) sta scrivendo…")
                    .font(BrindooFont.caption)
                    .foregroundStyle(Color.brindooTextSecondary)
            }
        }
        .onReceive(timer) { _ in
            phase = (phase + 1) % 3
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}
