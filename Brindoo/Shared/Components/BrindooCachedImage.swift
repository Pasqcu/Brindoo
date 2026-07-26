//
//  BrindooCachedImage.swift
//  Brindoo
//
//  Immagine da rete con memoria: tiene le foto già scaricate in RAM e su
//  disco, e le ridimensiona alla misura che serve davvero.
//
//  Perché: scorrendo la bacheca o la galleria, `AsyncImage` riscarica e
//  ridisegna ogni volta (lampeggio grigio + consumo). Qui la seconda volta
//  la foto compare istantanea.
//
//  Si usa esattamente come `AsyncImage` (stesse due forme), quindi la
//  sostituzione nelle viste è un semplice cambio di nome.
//

import SwiftUI
import UIKit
import ImageIO
import CryptoKit

// MARK: - Vista

struct BrindooCachedImage<Content: View>: View {

    private let url: URL?
    private let maxPixelSize: CGFloat
    private let content: (AsyncImagePhase) -> Content

    @State private var phase: AsyncImagePhase = .empty

    /// Forma con le tre fasi (vuoto / riuscito / fallito), come `AsyncImage`.
    init(
        url: URL?,
        maxPixelSize: CGFloat = 1400,
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content
    ) {
        self.url = url
        self.maxPixelSize = maxPixelSize
        self.content = content
    }

    var body: some View {
        content(phase)
            .task(id: url) { await load() }
    }

    private func load() async {
        guard let url else {
            phase = .empty
            return
        }
        // Se è già in memoria evitiamo pure il fotogramma vuoto.
        if let cached = BrindooImageLoader.shared.cachedInMemory(url: url, maxPixelSize: maxPixelSize) {
            phase = .success(Image(uiImage: cached))
            return
        }
        phase = .empty
        let image = await BrindooImageLoader.shared.image(for: url, maxPixelSize: maxPixelSize)
        guard !Task.isCancelled else { return }
        if let image {
            withAnimation(BrindooAnimation.quickEase) {
                phase = .success(Image(uiImage: image))
            }
        } else {
            phase = .failure(BrindooImageError.notLoaded)
        }
    }
}

extension BrindooCachedImage {
    /// Forma con contenuto + segnaposto, come `AsyncImage(url:content:placeholder:)`.
    init<I: View, P: View>(
        url: URL?,
        maxPixelSize: CGFloat = 1400,
        @ViewBuilder content: @escaping (Image) -> I,
        @ViewBuilder placeholder: @escaping () -> P
    ) where Content == _ConditionalContent<I, P> {
        self.init(url: url, maxPixelSize: maxPixelSize) { phase -> _ConditionalContent<I, P> in
            if case .success(let image) = phase {
                return ViewBuilder.buildEither(first: content(image))
            } else {
                return ViewBuilder.buildEither(second: placeholder())
            }
        }
    }
}

enum BrindooImageError: Error {
    case notLoaded
}

// MARK: - Magazzino foto

/// Tiene le immagini in RAM (svuotata dal sistema se serve memoria) e su
/// disco per una settimana. Ridimensiona in fase di lettura, così una foto
/// da 4000px non occupa memoria per un riquadro da 180px.
final class BrindooImageLoader: @unchecked Sendable {

    static let shared = BrindooImageLoader()

    private let memory = NSCache<NSString, UIImage>()
    private let folder: URL
    private let queue = DispatchQueue(label: "brindoo.imageloader", attributes: .concurrent)
    private var inFlight: [String: Task<UIImage?, Never>] = [:]
    private let lock = NSLock()

    private static let maxDiskAge: TimeInterval = 7 * 24 * 60 * 60

    private init() {
        memory.totalCostLimit = 60 * 1024 * 1024 // ~60 MB di anteprime
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        folder = base.appendingPathComponent("BrindooImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        purgeOldFilesInBackground()
    }

    private func key(_ url: URL, _ maxPixelSize: CGFloat) -> String {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let hex = digest.compactMap { String(format: "%02x", $0) }.joined()
        return "\(hex)-\(Int(maxPixelSize))"
    }

    /// Immagine già in RAM, se c'è (per evitare il lampeggio al riuso).
    func cachedInMemory(url: URL, maxPixelSize: CGFloat) -> UIImage? {
        memory.object(forKey: key(url, maxPixelSize) as NSString)
    }

    /// Restituisce la richiesta già in corso per questa foto, oppure ne
    /// registra una nuova. Tutto dentro un metodo non asincrono: prendere
    /// un lucchetto in un contesto asincrono è un errore in Swift 6, perché
    /// il lavoro potrebbe fermarsi proprio mentre lo tiene.
    private func existingOrNewTask(
        for k: String,
        make: () -> Task<UIImage?, Never>
    ) -> Task<UIImage?, Never> {
        lock.lock()
        defer { lock.unlock() }
        if let running = inFlight[k] { return running }
        let task = make()
        inFlight[k] = task
        return task
    }

    private func clearInFlight(_ k: String) {
        lock.lock()
        defer { lock.unlock() }
        inFlight[k] = nil
    }

    func image(for url: URL, maxPixelSize: CGFloat) async -> UIImage? {
        let k = key(url, maxPixelSize)
        if let hit = memory.object(forKey: k as NSString) { return hit }

        // Una sola richiesta per foto anche se dieci celle la chiedono insieme.
        let task = existingOrNewTask(for: k) {
            Task<UIImage?, Never> { [weak self] in
                guard let self else { return nil }
                let image = await self.fetch(url: url, key: k, maxPixelSize: maxPixelSize)
                self.clearInFlight(k)
                return image
            }
        }
        return await task.value
    }

    private func fetch(url: URL, key k: String, maxPixelSize: CGFloat) async -> UIImage? {
        let fileURL = folder.appendingPathComponent(k)

        if let data = try? Data(contentsOf: fileURL),
           let image = Self.downsample(data: data, maxPixelSize: maxPixelSize) {
            store(image, for: k)
            touch(fileURL)
            return image
        }

        guard let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true,
              let image = Self.downsample(data: data, maxPixelSize: maxPixelSize)
        else { return nil }

        try? data.write(to: fileURL, options: .atomic)
        store(image, for: k)
        return image
    }

    private func store(_ image: UIImage, for key: String) {
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        memory.setObject(image, forKey: key as NSString, cost: cost)
    }

    private func touch(_ url: URL) {
        queue.async {
            try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
        }
    }

    /// Ridisegna la foto alla misura utile: meno memoria, scorrimento fluido.
    private static func downsample(data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize * UIScreen.main.scale
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private func purgeOldFilesInBackground() {
        let folder = self.folder
        queue.async {
            let fm = FileManager.default
            guard let files = try? fm.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: [.contentModificationDateKey]
            ) else { return }
            let limit = Date().addingTimeInterval(-Self.maxDiskAge)
            for file in files {
                let date = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                if let date, date < limit { try? fm.removeItem(at: file) }
            }
        }
    }

    /// Svuota tutto (usato all'uscita dall'account).
    func clear() {
        memory.removeAllObjects()
        try? FileManager.default.removeItem(at: folder)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }
}
