//
//  VoiceAndVideoLogicTests.swift
//  BrindooTests
//
//  Logica pura delle novità: riconoscimento vocali/video dall'URL,
//  etichette di durata, copertina dei video del portfolio.
//

import XCTest
@testable import Brindoo

final class VoiceAndVideoLogicTests: XCTestCase {

    // MARK: - Vocali

    func test_urlVocaleRiconosciuto() {
        XCTAssertTrue(VoiceMessage.isVoiceURL("https://x.co/storage/abc.m4a"))
        XCTAssertFalse(VoiceMessage.isVoiceURL("https://x.co/storage/abc.jpg"))
        XCTAssertFalse(VoiceMessage.isVoiceURL(nil))
        XCTAssertFalse(VoiceMessage.isVoiceURL(""))
    }

    func test_etichettaDurata() {
        XCTAssertEqual(VoiceMessage.durationLabel(0), "0:00")
        XCTAssertEqual(VoiceMessage.durationLabel(42), "0:42")
        XCTAssertEqual(VoiceMessage.durationLabel(65), "1:05")
        XCTAssertEqual(VoiceMessage.durationLabel(120), "2:00")
        // Niente durate negative in etichetta, qualunque cosa arrivi.
        XCTAssertEqual(VoiceMessage.durationLabel(-3), "0:00")
    }

    func test_contenutoMessaggioPortaLaDurata() {
        XCTAssertEqual(VoiceMessage.contentLabel(duration: 42), "🎤 Messaggio vocale · 0:42")
    }

    // MARK: - Video portfolio

    private func item(url: String) -> PortfolioItem {
        PortfolioItem(
            id: UUID(), organizerId: UUID(),
            imageUrl: url, storagePath: "u/p",
            caption: nil, sortOrder: 0, createdAt: Date()
        )
    }

    func test_videoRiconosciutoDallEstensione() {
        XCTAssertTrue(item(url: "https://x.co/p/clip.mp4").isVideo)
        XCTAssertFalse(item(url: "https://x.co/p/foto.jpg").isVideo)
    }

    func test_copertinaVideoAccantoAlFile() {
        XCTAssertEqual(item(url: "https://x.co/p/clip.mp4").thumbnailUrl, "https://x.co/p/clip.mp4.jpg")
        // Le foto restano se stesse.
        XCTAssertEqual(item(url: "https://x.co/p/foto.jpg").thumbnailUrl, "https://x.co/p/foto.jpg")
    }
}
