//
//  ShareCard.swift
//  Brindoo
//
//  "Cartolina" di condivisione: quando si condivide un profilo o un'offerta
//  viene generata un'immagine con foto, nome e valutazione (invece del solo
//  link nudo), più bella su WhatsApp e social.
//
//  Le immagini remote vanno pre-scaricate (ImageRenderer è sincrono).
//

import SwiftUI
import UIKit

// MARK: - Cartolina profilo professionista

struct ProfileShareCard: View {

    let name: String
    let city: String?
    let categories: [String]
    let rating: OrganizerRating?
    let isPro: Bool
    let avatar: UIImage?

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text("Brindoo")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, 22)

                if let avatar {
                    Image(uiImage: avatar)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 130, height: 130)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(.white, lineWidth: 4))
                } else {
                    ZStack {
                        Circle().fill(.white.opacity(0.25))
                        Text(String(name.prefix(1)).uppercased())
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 130, height: 130)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 4))
                }

                HStack(spacing: 6) {
                    Text(name)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if isPro {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 20)

                if !categories.isEmpty {
                    Text(categories.prefix(3).joined(separator: " · "))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                        .padding(.horizontal, 20)
                }

                if let rating, rating.reviewCount > 0 {
                    HStack(spacing: 5) {
                        ForEach(0..<5, id: \.self) { i in
                            Image(systemName: Double(i) < rating.avgRating.rounded() ? "star.fill" : "star")
                                .font(.system(size: 15))
                        }
                        Text(String(format: "%.1f", rating.avgRating))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        Text("(\(rating.reviewCount))")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .opacity(0.85)
                    }
                    .foregroundStyle(.white)
                }

                if let city, !city.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse").font(.system(size: 12))
                        Text(city).font(.system(size: 14, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.9))
                }

                Spacer(minLength: 12)
            }
            .frame(maxWidth: .infinity)

            ShareCardFooter(text: "Trovami su Brindoo · feste ed eventi nel Lazio")
        }
        .frame(width: 360, height: 440)
        .background(ShareCardBackground())
    }
}

// MARK: - Cartolina offerta

struct OfferShareCard: View {

    let title: String
    let priceDisplay: String
    let organizerName: String?
    let cover: UIImage?

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                if let cover {
                    Image(uiImage: cover)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 360, height: 200)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(.white.opacity(0.18))
                        .frame(width: 360, height: 200)
                        .overlay(
                            Image(systemName: "party.popper.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(.white.opacity(0.7))
                        )
                }

                Text("Brindoo")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.35))
                    .clipShape(Capsule())
                    .padding(12)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack {
                    if let organizerName, !organizerName.isEmpty {
                        Text("di \(organizerName)")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(priceDisplay)
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer(minLength: 0)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)

            ShareCardFooter(text: "Scoprila su Brindoo · feste ed eventi nel Lazio")
        }
        .frame(width: 360, height: 380)
        .background(ShareCardBackground())
    }
}

// MARK: - Pezzi comuni

private struct ShareCardBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 1.00, green: 0.45, blue: 0.38),
                Color(red: 0.93, green: 0.30, blue: 0.33)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct ShareCardFooter: View {
    let text: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "party.popper.fill").font(.system(size: 13))
            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
            Spacer()
            Text("brindoo.app")
                .font(.system(size: 13, weight: .bold, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .background(.black.opacity(0.22))
    }
}

// MARK: - Renderer

@MainActor
enum ShareCardRenderer {

    /// Trasforma una card SwiftUI in immagine (3x, forzata in modalità chiara).
    static func render<V: View>(_ card: V) -> UIImage? {
        let renderer = ImageRenderer(content: card.environment(\.colorScheme, .light))
        renderer.scale = 3
        return renderer.uiImage
    }

    /// Scarica un'immagine remota da usare nella card (best effort).
    static func loadImage(from urlString: String?) async -> UIImage? {
        guard let urlString, let url = URL(string: urlString) else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return UIImage(data: data)
    }
}

// MARK: - Foglio di condivisione (immagine + link insieme)

/// Wrapper di UIActivityViewController: permette di condividere in un colpo
/// solo cartolina e link (ShareLink accetta un solo tipo di contenuto).
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
