//
//  PortfolioGalleryView.swift
//  Brindoo
//
//  Galleria fotografica del portfolio organizzatore.
//  - Griglia 3 colonne stile Instagram con dimensioni proporzionali
//  - Bottone X visibile per cancellare (solo owner)
//  - Tap su foto apre preview con swipe orizzontale tra tutte le foto
//

import SwiftUI
import PhotosUI

struct PortfolioGalleryView: View {
    
    let organizerId: UUID
    let isOwner: Bool
    
    @State private var state: LoadState<[PortfolioItem]> = .loading
    @State private var errorMessage: String?

    private var items: [PortfolioItem] {
        get { state.value ?? [] }
        nonmutating set { state = newValue.isEmpty ? .empty : .loaded(newValue) }
    }
    
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isUploading: Bool = false
    @State private var uploadProgress: String = ""
    
    @State private var previewStartIndex: Int? = nil
    @State private var itemToDelete: PortfolioItem? = nil
    @State private var showDeleteAlert: Bool = false
    @State private var showLimitPaywall: Bool = false
    @State private var limitMessage: String = ""
    @State private var showPaywallSheet: Bool = false
    
    /// Spazio tra le celle della griglia
    private let gridSpacing: CGFloat = 4
    
    /// Numero di colonne della griglia
    private let columnCount: Int = 3
    
    var body: some View {
        Group {
            if state.isLoading {
                VStack {
                    Spacer()
                    ProgressView().tint(.brindooCoral)
                    Spacer()
                }
            } else if case .error(let message) = state {
                BrindooErrorState(message: message) {
                    Task { await loadPortfolio() }
                }
            } else if items.isEmpty {
                emptyView
            } else {
                galleryGrid
            }
        }
        .background(Color.brindooBackground)
        .navigationTitle(isOwner ? "Il mio portfolio" : "Portfolio")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isOwner {
                ToolbarItem(placement: .topBarTrailing) {
                    PhotosPicker(
                        selection: $pickerItems,
                        maxSelectionCount: 10,
                        matching: .images,
                        preferredItemEncoding: .compatible,
                        photoLibrary: .shared()
                    ) {
                        if isUploading {
                            ProgressView()
                                .tint(.brindooCoral)
                        } else {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.brindooCoral)
                        }
                    }
                    .disabled(isUploading)
                }
            }
        }
        .task {
            await loadPortfolio()
        }
        .refreshable {
            await loadPortfolio()
        }
        .onChange(of: pickerItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task { await uploadSelectedPhotos(newItems) }
        }
        // FIX #15: preview con swipe orizzontale
        .fullScreenCover(item: Binding(
            get: { previewStartIndex.map { IndexWrapper(index: $0) } },
            set: { previewStartIndex = $0?.index }
        )) { wrapper in
            PortfolioPagerView(
                items: items,
                startIndex: wrapper.index,
                isOwner: isOwner
            )
        }
        .alert("Eliminare foto?", isPresented: $showDeleteAlert) {
            Button("Annulla", role: .cancel) { itemToDelete = nil }
            Button("Elimina", role: .destructive) {
                if let item = itemToDelete {
                    Task { await deleteItem(item) }
                }
                itemToDelete = nil
            }
        } message: {
            Text("Questa foto sarà rimossa dal tuo portfolio definitivamente.")
        }
        .alert("Limite raggiunto", isPresented: $showLimitPaywall) {
            Button("Annulla", role: .cancel) {}
            Button("Scopri Pro") {
                showLimitPaywall = false
                showPaywallSheet = true
            }
        } message: {
            Text(limitMessage)
        }
        .sheet(isPresented: $showPaywallSheet) {
            PaywallView()
        }
    }
    
    // MARK: - Empty
    
    @ViewBuilder
    private var emptyView: some View {
        VStack(spacing: BrindooSpacing.md) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.brindooCoral.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.brindooCoral)
            }
            
            Text(isOwner ? "Aggiungi le tue foto migliori" : "Nessuna foto")
                .font(BrindooFont.titleMedium)
            
            Text(isOwner
                 ? "Mostra ai clienti i tuoi lavori. Le foto fanno la differenza."
                 : "Questo organizzatore non ha ancora pubblicato foto")
                .font(BrindooFont.bodyMedium)
                .foregroundStyle(Color.brindooTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, BrindooSpacing.xl)
            
            if isOwner {
                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: 10,
                    matching: .images,
                    preferredItemEncoding: .compatible,
                    photoLibrary: .shared()
                ) {
                    HStack(spacing: BrindooSpacing.xs) {
                        Image(systemName: "plus")
                        Text("Aggiungi foto")
                    }
                    .font(BrindooFont.button)
                    .foregroundStyle(.white)
                    .frame(height: 56)
                    .padding(.horizontal, BrindooSpacing.xl)
                    .background(Color.brindooCoral)
                    .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
                }
                .padding(.top, BrindooSpacing.md)
                .disabled(isUploading)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Griglia
    
    @ViewBuilder
    private var galleryGrid: some View {
        // FIX #14: calcoliamo dinamicamente la dimensione delle celle dalla larghezza disponibile
        GeometryReader { geometry in
            let totalSpacing = gridSpacing * CGFloat(columnCount + 1)
            let cellSize = (geometry.size.width - totalSpacing) / CGFloat(columnCount)
            
            ScrollView {
                VStack(spacing: BrindooSpacing.sm) {
                    if isUploading {
                        uploadingBanner
                            .padding(.horizontal, BrindooSpacing.md)
                            .padding(.top, BrindooSpacing.sm)
                    }
                    
                    // Griglia con celle quadrate ben definite
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(.fixed(cellSize), spacing: gridSpacing),
                            count: columnCount
                        ),
                        spacing: gridSpacing
                    ) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            photoCell(item, size: cellSize, index: index)
                        }
                    }
                    .padding(.horizontal, gridSpacing)
                    .padding(.top, gridSpacing)
                }
                .padding(.bottom, BrindooSpacing.lg)
            }
        }
    }
    
    @ViewBuilder
    private func photoCell(_ item: PortfolioItem, size: CGFloat, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            // Foto
            Button {
                // FIX #15: apri preview a partire dall'indice toccato
                previewStartIndex = index
            } label: {
                AsyncImage(url: URL(string: item.imageUrl)) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            Color.brindooSurface
                            ProgressView().tint(.brindooCoral)
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        ZStack {
                            Color.brindooSurface
                            Image(systemName: "photo")
                                .foregroundStyle(Color.brindooTextSecondary)
                        }
                    @unknown default:
                        Color.brindooSurface
                    }
                }
                .frame(width: size, height: size)
                .clipped()
            }
            .buttonStyle(.plain)
            
            // FIX #14: Bottone X ben visibile per cancellare (solo owner)
            if isOwner {
                Button {
                    itemToDelete = item
                    showDeleteAlert = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 28, height: 28)
                        Image(systemName: "trash.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .padding(6)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.sm))
    }
    
    @ViewBuilder
    private var uploadingBanner: some View {
        HStack(spacing: BrindooSpacing.sm) {
            ProgressView()
                .tint(.brindooCoral)
            Text(uploadProgress)
                .font(BrindooFont.bodyMedium.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BrindooSpacing.md)
        .background(Color.brindooCoral.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: BrindooRadius.md))
    }
    
    // MARK: - Caricamento
    
    private func loadPortfolio() async {
        if state.value == nil { state = .loading }
        do {
            items = try await PortfolioService.shared.fetchPortfolio(organizerId: organizerId)
        } catch {
            BrindooLog.error("Errore caricamento portfolio: \(error)")
            if state.value == nil {
                state = .error("Impossibile caricare il portfolio")
            } else {
                errorMessage = "Impossibile aggiornare il portfolio"
            }
        }
    }
    
    private func uploadSelectedPhotos(_ pickerItems: [PhotosPickerItem]) async {
        isUploading = true
        defer {
            isUploading = false
            self.pickerItems = []
        }
        
        var uploadedCount = 0
        let total = pickerItems.count
        
        for (index, pickerItem) in pickerItems.enumerated() {
            uploadProgress = "Caricamento \(index + 1) di \(total)..."
            
            do {
                guard let data = try await pickerItem.loadTransferable(type: Data.self),
                      let uiImage = UIImage(data: data) else {
                    continue
                }
                
                _ = try await PortfolioService.shared.addPhoto(uiImage)
                uploadedCount += 1
            } catch let limitError as BrindooLimitError {
                limitMessage = limitError.errorDescription ?? "Limite raggiunto."
                showLimitPaywall = true
                break
            } catch {
                BrindooLog.error("Errore upload foto \(index): \(error)")
            }
        }

        await loadPortfolio()

        if uploadedCount < total && !showLimitPaywall {
            errorMessage = "Caricate \(uploadedCount) di \(total) foto. Alcune sono fallite."
        }
    }
    
    private func deleteItem(_ item: PortfolioItem) async {
        do {
            try await PortfolioService.shared.deletePhoto(item)
            items.removeAll { $0.id == item.id }
        } catch {
            errorMessage = "Impossibile eliminare la foto"
            BrindooLog.error("\(error)")
        }
    }
}

// MARK: - Wrapper per fullScreenCover con Int

private struct IndexWrapper: Identifiable {
    let index: Int
    var id: Int { index }
}

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
        AsyncImage(url: URL(string: item.imageUrl)) { phase in
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
