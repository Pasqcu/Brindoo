//
//  BrindooNetworkBar.swift
//  Brindoo
//
//  Banner persistente quando l'app è offline.
//

import SwiftUI

struct BrindooNetworkBar: View {
    let isOffline: Bool

    var body: some View {
        if isOffline {
            HStack(spacing: BrindooSpacing.xs) {
                Image(systemName: BrindooIcon.offline)
                    .font(.system(size: 13, weight: .bold))
                Text("Sei offline — alcune funzioni sono limitate")
                    .font(BrindooFont.bodySmall.weight(.semibold))
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, BrindooSpacing.md)
            .padding(.vertical, BrindooSpacing.xs)
            .background(Color.brindooError)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
