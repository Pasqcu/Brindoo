//
//  PortfolioPagerView.swift
//  Brindoo
//
//  Visore a tutto schermo delle foto del portfolio, con scorrimento
//  orizzontale. Separato dalla galleria per tenere i due file corti.
//

import SwiftUI

// MARK: - Preview swipe (FIX #15)

/// Vista pager fullscreen che permette swipe orizzontale tra le foto.
/// Stile galleria iOS Photos: sfondo nero, dot pagination, X per chiudere.
struct PortfolioPagerView: View {

    let items: [PortfolioItem]
    let startIndex: Int
    /// True se la galleria appartiene all'utente loggato: nasconde l'opzione
    /// "Segnala" (non ha senso segnalare le proprie foto).
    var isOwner: Bool = false

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int
    @State private var itemToReport: PortfolioItem?

    init(items: [PortfolioItem], startIndex: Int, isOwner: Bool = false) {
        self.items = items
        self.startIndex = startIndex
        self.isOwner = isOwner
        self._currentIndex = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Pager con swipe orizzontale
            TabView(selection: $currentIndex) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    photoView(item)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            // Overlay: header con X + contatore
            VStack {
                HStack {
                    Text("\(currentIndex + 1) di \(items.count)")
                        .font(BrindooFont.bodyMedium.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, BrindooSpacing.md)
                        .padding(.vertical, BrindooSpacing.xs)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Capsule())

                    Spacer()

                    if !isOwner, let current = items[safe: currentIndex] {
                        Menu {
                            Button(role: .destructive) {
                                itemToReport = current
                            } label: {
                                Label("Segnala foto", systemImage: "exclamationmark.bubble")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle.fill")
                                .font(.system(size: 28))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .black.opacity(0.5))
                        }
                    }

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.5))
                    }
                }
                .padding(.horizontal, BrindooSpacing.md)
                .padding(.top, BrindooSpacing.sm)

                Spacer()

                // Caption (se presente)
                if let caption = items[safe: currentIndex]?.caption, !caption.isEmpty {
                    Text(caption)
                        .font(BrindooFont.bodyLarge)
                        .foregroundStyle(.white)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.5))
                }
            }
        }
        .presentationBackground(.black)
        .sheet(item: $itemToReport) { item in
            ReportSheet(
                targetType: .portfolioItem,
                targetId: item.id,
                targetLabel: "questa foto"
            )
        }
    }
    
    @ViewBuilder
    private func photoView(_ item: PortfolioItem) -> some View {
        BrindooCachedImage(url: URL(string: item.imageUrl)) { phase in
            switch phase {
            case .empty:
                ProgressView().tint(.white)
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failure:
                Image(systemName: "photo")
                    .font(.system(size: 64))
                    .foregroundStyle(.white)
            @unknown default:
                EmptyView()
            }
        }
    }
}

// Helper subscript sicuro per array
private extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
