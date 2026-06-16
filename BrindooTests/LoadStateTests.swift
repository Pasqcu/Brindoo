//
//  LoadStateTests.swift
//  BrindooTests
//

import XCTest
@testable import Brindoo

final class LoadStateTests: XCTestCase {

    func test_idleHasNoValue() {
        let s: LoadState<Int> = .idle
        XCTAssertNil(s.value)
        XCTAssertFalse(s.isLoading)
    }

    func test_loadingFlag() {
        let s: LoadState<Int> = .loading
        XCTAssertTrue(s.isLoading)
        XCTAssertNil(s.value)
    }

    func test_loadedExposesValue() {
        let s: LoadState<Int> = .loaded(42)
        XCTAssertEqual(s.value, 42)
        XCTAssertFalse(s.isLoading)
    }

    func test_emptyHasNoValue() {
        let s: LoadState<Int> = .empty
        XCTAssertNil(s.value)
    }

    func test_errorHasNoValue() {
        let s: LoadState<Int> = .error("boom")
        XCTAssertNil(s.value)
        XCTAssertFalse(s.isLoading)
    }
}
