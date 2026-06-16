//
//  LocalCacheStoreTests.swift
//  BrindooTests
//
//  Smoke test della cache locale (round-trip JSON).
//

import XCTest
@testable import Brindoo

final class LocalCacheStoreTests: XCTestCase {

    struct Sample: Codable, Equatable {
        let id: UUID
        let name: String
        let date: Date
    }

    func test_saveAndLoadRoundTrip() async {
        let key = "brindoo_test_\(UUID().uuidString)"
        let sample = Sample(id: UUID(), name: "Brindoo", date: Date(timeIntervalSince1970: 1_700_000_000))

        await LocalCacheStore.shared.save(sample, for: key)
        let loaded = await LocalCacheStore.shared.load(Sample.self, for: key)

        XCTAssertEqual(loaded, sample)
        await LocalCacheStore.shared.remove(for: key)
    }

    func test_removeClearsValue() async {
        let key = "brindoo_test_\(UUID().uuidString)"
        await LocalCacheStore.shared.save("hello", for: key)
        await LocalCacheStore.shared.remove(for: key)
        let loaded = await LocalCacheStore.shared.load(String.self, for: key)
        XCTAssertNil(loaded)
    }
}
