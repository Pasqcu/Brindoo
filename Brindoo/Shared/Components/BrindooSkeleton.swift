//
//  BrindooSkeleton.swift
//  Brindoo
//
//  Skeleton loader animato per stati di caricamento.
//

import SwiftUI

struct BrindooSkeleton: View {
    let cornerRadius: CGFloat
    @State private var shimmer = false

    init(cornerRadius: CGFloat = BrindooRadius.sm) {
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.brindooSurface)
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(0.45),
                        Color.white.opacity(0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .blendMode(.plusLighter)
                .rotationEffect(.degrees(20))
                .offset(x: shimmer ? 200 : -200)
                .mask(RoundedRectangle(cornerRadius: cornerRadius))
            )
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    shimmer = true
                }
            }
    }
}

/// Linea skeleton standard
struct BrindooSkeletonLine: View {
    let width: CGFloat?
    let height: CGFloat

    init(width: CGFloat? = nil, height: CGFloat = 14) {
        self.width = width
        self.height = height
    }

    var body: some View {
        BrindooSkeleton(cornerRadius: height / 2)
            .frame(width: width, height: height)
    }
}

/// Skeleton di una card (es. lista chat, offerte)
struct BrindooSkeletonCard: View {
    var body: some View {
        BrindooCard(style: .flat) {
            HStack(spacing: BrindooSpacing.md) {
                BrindooSkeleton(cornerRadius: 26)
                    .frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: BrindooSpacing.xs) {
                    BrindooSkeletonLine(width: 140, height: 14)
                    BrindooSkeletonLine(width: 220, height: 12)
                    BrindooSkeletonLine(width: 80, height: 10)
                }
                Spacer()
            }
        }
    }
}

#Preview {
    VStack(spacing: BrindooSpacing.md) {
        BrindooSkeletonCard()
        BrindooSkeletonCard()
        BrindooSkeletonCard()
    }
    .padding()
}
