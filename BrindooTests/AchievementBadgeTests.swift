//
//  AchievementBadgeTests.swift
//  BrindooTests
//
//  Rete di sicurezza su distintivi dei traguardi e velocità di risposta.
//

import XCTest
@testable import Brindoo

final class AchievementBadgeTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func earned(
        reviewCount: Int = 0,
        avgRating: Double = 0,
        verifiedReviewCount: Int = 0,
        portfolioCount: Int = 0,
        memberSinceDaysAgo: Double = 0,
        responseSpeed: ResponseSpeed? = nil
    ) -> [String] {
        AchievementBadge.earned(
            reviewCount: reviewCount,
            avgRating: avgRating,
            verifiedReviewCount: verifiedReviewCount,
            portfolioCount: portfolioCount,
            memberSince: now.addingTimeInterval(-memberSinceDaysAgo * 24 * 60 * 60),
            responseSpeed: responseSpeed,
            now: now
        ).map(\.id)
    }

    func test_profiloNuovo_nessunDistintivo() {
        XCTAssertTrue(earned().isEmpty)
    }

    func test_valutazioniAlTop_serveMediaEValutazioniMinime() {
        XCTAssertFalse(earned(reviewCount: 4, avgRating: 5.0).contains("top_rated"))
        XCTAssertFalse(earned(reviewCount: 10, avgRating: 4.5).contains("top_rated"))
        XCTAssertTrue(earned(reviewCount: 5, avgRating: 4.8).contains("top_rated"))
    }

    func test_eventiVerificati_daTreInSu() {
        XCTAssertFalse(earned(verifiedReviewCount: 2).contains("verified_events"))
        XCTAssertTrue(earned(verifiedReviewCount: 3).contains("verified_events"))
    }

    func test_moltoRichiesto_daDieciRecensioni() {
        XCTAssertFalse(earned(reviewCount: 9).contains("in_demand"))
        XCTAssertTrue(earned(reviewCount: 10).contains("in_demand"))
    }

    func test_veterano_dopoUnAnno() {
        XCTAssertFalse(earned(memberSinceDaysAgo: 200).contains("veteran"))
        XCTAssertTrue(earned(memberSinceDaysAgo: 400).contains("veteran"))
    }

    func test_risposteFulminee_soloEntroUnOra() {
        XCTAssertTrue(earned(responseSpeed: .withinHour).contains("fast_replies"))
        XCTAssertFalse(earned(responseSpeed: .sameDay).contains("fast_replies"))
    }

    // MARK: - ResponseSpeed

    func test_fasceVelocitaRisposta() {
        XCTAssertEqual(ResponseSpeed(minutes: 10), .withinHour)
        XCTAssertEqual(ResponseSpeed(minutes: 60), .withinHour)
        XCTAssertEqual(ResponseSpeed(minutes: 61), .sameDay)
        XCTAssertEqual(ResponseSpeed(minutes: 24 * 60), .sameDay)
        XCTAssertEqual(ResponseSpeed(minutes: 25 * 60), .fewDays)
        XCTAssertNil(ResponseSpeed(minutes: 4 * 24 * 60), "oltre 3 giorni: meglio non mostrare nulla")
        XCTAssertNil(ResponseSpeed(minutes: nil))
        XCTAssertNil(ResponseSpeed(minutes: -5))
    }
}
