//
//  ResponseInsightsTests.swift
//  BrindooTests
//
//  Rete di sicurezza sul calcolo del tempo di risposta in chat.
//

import XCTest
@testable import Brindoo

final class ResponseInsightsTests: XCTestCase {

    private let me = UUID()
    private let other = UUID()
    private let conv1 = UUID()
    private let conv2 = UUID()
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func msg(_ conv: UUID, _ sender: UUID, minute: Double) -> (conversation: UUID, sender: UUID, at: Date) {
        (conversation: conv, sender: sender, at: t0.addingTimeInterval(minute * 60))
    }

    func test_rispostaSemplice_misuraAttesa() {
        let samples = ResponseInsightsService.responseSamples(
            messages: [
                msg(conv1, other, minute: 0),
                msg(conv1, me, minute: 30)
            ],
            me: me
        )
        XCTAssertEqual(samples, [30 * 60])
    }

    func test_piuMessaggiAltrui_contaDalPrimoSenzaRisposta() {
        let samples = ResponseInsightsService.responseSamples(
            messages: [
                msg(conv1, other, minute: 0),
                msg(conv1, other, minute: 20),
                msg(conv1, me, minute: 60)
            ],
            me: me
        )
        XCTAssertEqual(samples, [60 * 60])
    }

    func test_conversazioniSeparate_nonSiMischiano() {
        let samples = ResponseInsightsService.responseSamples(
            messages: [
                msg(conv1, other, minute: 0),
                msg(conv2, other, minute: 5),
                msg(conv2, me, minute: 10),
                msg(conv1, me, minute: 40)
            ],
            me: me
        )
        XCTAssertEqual(Set(samples), [5 * 60, 40 * 60])
    }

    func test_mieiMessaggiSenzaDomanda_nonProduconoCampioni() {
        let samples = ResponseInsightsService.responseSamples(
            messages: [
                msg(conv1, me, minute: 0),
                msg(conv1, me, minute: 10)
            ],
            me: me
        )
        XCTAssertTrue(samples.isEmpty)
    }

    func test_messaggioAltruiSenzaMiaRisposta_nonConta() {
        let samples = ResponseInsightsService.responseSamples(
            messages: [msg(conv1, other, minute: 0)],
            me: me
        )
        XCTAssertTrue(samples.isEmpty)
    }

    // MARK: - Mediana

    func test_medianaDispari() {
        XCTAssertEqual(ResponseInsightsService.medianMinutes([600, 60, 6000]), 10)
    }

    func test_medianaPari_mediaDeiCentrali() {
        // 10 e 20 minuti al centro → 15
        XCTAssertEqual(ResponseInsightsService.medianMinutes([600, 1200, 60, 90000]), 15)
    }

    func test_medianaVuota_nil() {
        XCTAssertNil(ResponseInsightsService.medianMinutes([]))
    }
}
