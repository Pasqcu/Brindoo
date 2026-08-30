//
//  PortfolioPagerView.swift
//  Brindoo
//
//  Visore a tutto schermo delle foto del portfolio, con scorrimento
//  orizzontale. Separato dalla galleria per tenere i due file corti.
//

import SwiftUI
import AVKit

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
    /// La pagina si segue per identità della foto, non per numero: è quello
    /// che `scrollPosition` sa restituire, e non si sfasa se l'elenco cambia.
    @State private var currentItemID: PortfolioItem.ID?
    @State private var itemToReport: PortfolioItem?

    /// Di quanto la foto è stata spostata dal dito mentre si chiude. Segue il
    /// dito anche di lato: durante la chiusura la foto è un oggetto che si
    /// sposta, non una pagina che scorre.
    @State private var drag: CGSize = .zero

    /// Asse deciso. Appena il gesto si rivela verticale lo scorrimento
    /// orizzontale viene spento: senza questo, muovendo il dito di traverso
    /// mentre si trascina giù, la pagina continuava a scorrere e spuntava la
    /// foto vicina accanto a quella che si sta chiudendo.
    @State private var isDismissing = false

    /// Oltre questa distanza si chiude; sotto, la foto torna al suo posto.
    private static let dismissDistance: CGFloat = 140

    /// Stacco fra una foto e l'altra: si vede solo mentre si sfoglia, e serve
    /// a non far sembrare due foto accostate una cosa sola.
    private static let pageGap: CGFloat = 24

    /// Da 0 (ferma) a 1 (sul punto di chiudersi): rimpicciolisce la foto e
    /// smorza le scritte sopra, così il gesto si vede mentre lo si fa.
    private var dragProgress: CGFloat {
        min(max(drag.height, 0) / (Self.dismissDistance * 2), 1)
    }

    /// Trascinamento verso il basso per chiudere, come nelle Foto di iOS.
    /// È `simultaneousGesture` perché sotto c'è uno scorrimento orizzontale:
    /// i due non si escludono. L'asse si decide una volta sola, al primo
    /// movimento utile, e non cambia più fino al rilascio: così un gesto
    /// storto resta quello che era all'inizio invece di fare le due cose
    /// insieme.
    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                if !isDismissing {
                    guard value.translation.height > 0,
                          abs(value.translation.height) > abs(value.translation.width)
                    else { return }
                    isDismissing = true
                }
                drag = CGSize(
                    width: value.translation.width,
                    height: max(0, value.translation.height)
                )
            }
            .onEnded { value in
                guard isDismissing else { return }
                let lanciata = value.predictedEndTranslation.height > Self.dismissDistance * 2
                if drag.height > Self.dismissDistance || (drag.height > 0 && lanciata) {
                    dismiss()
                } else {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        drag = .zero
                    }
                }
                isDismissing = false
            }
    }

    init(items: [PortfolioItem], startIndex: Int, isOwner: Bool = false) {
        self.items = items
        self.startIndex = startIndex
        self.isOwner = isOwner
        self._currentItemID = State(initialValue: items[safe: startIndex]?.id)
    }

    private var currentItem: PortfolioItem? {
        items.first { $0.id == currentItemID }
    }

    private var currentIndex: Int {
        items.firstIndex { $0.id == currentItemID } ?? 0
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Scorrimento orizzontale con aggancio a pagina.
            //
            // Prima qui c'era un `TabView` in stile `.page`: con le foto
            // ridimensionate a proporzione (che lasciano margini neri) non si
            // fermava mai esatto sul bordo, e restava a schermo una striscia
            // della foto seguente — l'accavallamento che si vedeva sfogliando,
            // riprodotto e misurato in un pager di prova. Lo scorrimento con
            // `.scrollTargetBehavior(.paging)` si ferma al pixel giusto e
            // ritaglia ogni pagina alla larghezza dello schermo.
            GeometryReader { geo in
                ScrollView(.horizontal) {
                    LazyHStack(spacing: Self.pageGap) {
                        ForEach(items) { item in
                            Group {
                                if item.isVideo {
                                    PortfolioVideoPage(urlString: item.imageUrl)
                                } else {
                                    photoView(item, maxSide: max(geo.size.width, geo.size.height))
                                }
                            }
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                            .id(item.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                // `.viewAligned` invece di `.paging`: con lo stacco fra le
                // foto, l'aggancio va fatto sul bordo della foto, non su
                // multipli della larghezza dello schermo — altrimenti a ogni
                // pagina il disallineamento cresce dello stacco.
                .scrollTargetBehavior(.viewAligned)
                .scrollIndicators(.hidden)
                .scrollPosition(id: $currentItemID)
                .scrollDisabled(isDismissing)
            }
            .ignoresSafeArea()
            .offset(x: drag.width, y: drag.height)
            .scaleEffect(1 - dragProgress * 0.12)
            .simultaneousGesture(dismissDrag)

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

                    if !isOwner, let current = currentItem {
                        Menu {
                            Button(role: .destructive) {
                                itemToReport = current
                            } label: {
                                Label(current.isVideo ? "Segnala video" : "Segnala foto",
                                      systemImage: "exclamationmark.bubble")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle.fill")
                                .font(.system(size: 28))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .black.opacity(0.5))
                        }
                        .accessibilityLabel("Altre azioni")
                    }

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.5))
                    }
                    .accessibilityLabel("Chiudi")
                }
                .padding(.horizontal, BrindooSpacing.md)
                .padding(.top, BrindooSpacing.sm)

                Spacer()

                // Caption (se presente)
                if let caption = currentItem?.caption, !caption.isEmpty {
                    Text(caption)
                        .font(BrindooFont.bodyLarge)
                        .foregroundStyle(.white)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.5))
                }
            }
            // Mentre si trascina per chiudere, le scritte si tolgono di mezzo.
            .opacity(1 - dragProgress)
        }
        .presentationBackground(.black)
        .sheet(item: $itemToReport) { item in
            ReportSheet(
                targetType: .portfolioItem,
                targetId: item.id,
                targetLabel: item.isVideo ? "questo video" : "questa foto"
            )
        }
    }
    
    /// `maxSide` e' il lato lungo dello schermo in punti: piu' di cosi' non
    /// si vede, e decodificare oltre costa solo memoria.
    @ViewBuilder
    private func photoView(_ item: PortfolioItem, maxSide: CGFloat) -> some View {
        BrindooCachedImage(url: URL(string: item.imageUrl), maxPixelSize: maxSide) { phase in
            switch phase {
            case .empty:
                ProgressView().tint(.white)
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failure:
                Image(systemName: BrindooIcon.photo)
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

// MARK: - Pagina video

/// Una pagina del pager che riproduce un video del portfolio.
/// Il player nasce all'apparire e si ferma sfogliando via.
private struct PortfolioVideoPage: View {

    let urlString: String
    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
            } else {
                ProgressView().tint(.white)
            }
        }
        .onAppear {
            if player == nil, let url = URL(string: urlString) {
                player = AVPlayer(url: url)
            }
            player?.play()
        }
        .onDisappear { player?.pause() }
    }
}
