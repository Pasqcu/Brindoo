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
    
    init(url: String?, name: String?, size: CGFloat = 56) {
        self.url = url
        self.name = name
        self.size = size
    }
    
    var body: some View {
        Group {
            if let urlString = url, !urlString.isEmpty, let validUrl = URL(string: urlString) {
                AsyncImage(url: validUrl) { phase in
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
                .fill(
                    LinearGradient(
                        colors: [Color.brindooCoral, Color.brindooCoralDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(initials)
                .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
    
    private var initials: String {
        guard let name, !name.isEmpty else { return "?" }
        let parts = name.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first?.uppercased() }.joined()
    }
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
