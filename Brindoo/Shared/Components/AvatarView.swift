//
//  AvatarView.swift
//  Brindoo
//
//  Vista riutilizzabile per l'avatar di un utente.
//  Mostra l'immagine se presente l'avatarUrl, altrimenti le iniziali su gradient corallo.
//

import SwiftUI

struct AvatarView: View {
    
    let url: String?
    let name: String?
    let size: CGFloat
    /// Anello disegnato attorno al cerchio: serve a staccare l'avatar
    /// dallo sfondo quando sborda su una card.
    let ringWidth: CGFloat
    let ringColor: Color

    init(url: String?, name: String?, size: CGFloat = 56,
         ringWidth: CGFloat = 0, ringColor: Color = .clear) {
        self.url = url
        self.name = name
        self.size = size
        self.ringWidth = ringWidth
        self.ringColor = ringColor
    }

    var body: some View {
        Group {
            if let urlString = url, !urlString.isEmpty, let validUrl = URL(string: urlString) {
                // L'avatar è piccolo: chiediamo un'anteprima leggera.
                BrindooCachedImage(url: validUrl, maxPixelSize: max(size, 120)) { phase in
                    switch phase {
                    case .empty:
                        loadingPlaceholder
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        initialsPlaceholder
                    @unknown default:
                        initialsPlaceholder
                    }
                }
            } else {
                initialsPlaceholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .padding(ringWidth)
        .background(ringColor, in: Circle())
    }
    
    @ViewBuilder
    private var loadingPlaceholder: some View {
        ZStack {
            Circle()
                .fill(Color.brindooSurface)
            ProgressView()
                .tint(.brindooCoral)
                .scaleEffect(size > 80 ? 1.0 : 0.7)
        }
    }
    
    @ViewBuilder
    private var initialsPlaceholder: some View {
        ZStack {
            Circle()
                .fill(BrindooGradient.coral)
            
            Text(initials)
                .font(.system(size: size * 0.40, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
    
    private var initials: String { BrindooText.initials(from: name) }
}

#Preview {
    HStack(spacing: 20) {
        AvatarView(url: nil, name: "Mario Rossi", size: 40)
        AvatarView(url: nil, name: "Anna", size: 60)
        AvatarView(url: nil, name: nil, size: 80)
        AvatarView(url: nil, name: "DJ Eventi Roma", size: 100)
    }
    .padding()
}
