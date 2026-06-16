//
//  AvatarFullScreenView.swift
//  Brindoo
//
//  Visualizzazione fullscreen dell'avatar (foto profilo) con sfondo nero
//  e pulsante di chiusura. Se l'avatar non è disponibile, mostra le iniziali
//  ingrandite riusando lo stile di AvatarView.
//

import SwiftUI

struct AvatarFullScreenView: View {

    let url: String?
    let name: String?
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            Group {
                if let urlString = url, !urlString.isEmpty, let validUrl = URL(string: urlString) {
                    AsyncImage(url: validUrl) { phase in
                        switch phase {
                        case .empty:
                            ProgressView().tint(.white)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button { onClose() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.5))
            }
            .padding()
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
                .frame(width: 260, height: 260)

            Text(initials)
                .font(.system(size: 110, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private var initials: String {
        guard let name, !name.isEmpty else { return "?" }
        let parts = name.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first?.uppercased() }.joined()
    }
}
