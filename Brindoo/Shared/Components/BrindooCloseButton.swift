//
//  BrindooCloseButton.swift
//  Brindoo
//
//  La "X" che chiude una foto a schermo intero, l'anteprima prima dell'invio
//  o una barra della chat.
//
//  Era ricopiata in quattro punti con misure diverse: in uno l'area toccabile
//  scendeva sotto i 44 pt richiesti dalle linee guida, e su una foto scura
//  finiva sopra un fondo qualsiasi senza garanzia di contrasto.
//

import SwiftUI

struct BrindooCloseButton: View {

    enum Style {
        /// Sopra una foto o un fondo scuro: bianca, con alone scuro dietro
        /// perché resti visibile anche su un'immagine chiara.
        case overlay
        /// Dentro una barra dell'app: grigia, sul colore di sfondo normale.
        case inline
    }

    let style: Style
    let action: () -> Void

    init(style: Style = .overlay, action: @escaping () -> Void) {
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            icon
                .frame(
                    width: BrindooLayout.minimumTapTarget,
                    height: BrindooLayout.minimumTapTarget
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(BrindooText.close)
    }

    @ViewBuilder
    private var icon: some View {
        switch style {
        case .overlay:
            Image(systemName: BrindooIcon.closeCircle)
                .font(BrindooFont.scaled(28, relativeTo: .title2))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .black.opacity(0.5))
        case .inline:
            Image(systemName: BrindooIcon.closeCircle)
                .font(BrindooFont.scaled(22, relativeTo: .title3))
                .foregroundStyle(Color.brindooTextSecondary)
        }
    }
}

#Preview {
    VStack(spacing: BrindooSpacing.lg) {
        BrindooCloseButton {}
            .padding()
            .background(.black)
        BrindooCloseButton(style: .inline) {}
    }
}
