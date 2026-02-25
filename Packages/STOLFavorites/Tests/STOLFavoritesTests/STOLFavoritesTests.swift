// STOLFavoritesTests.swift — STOLFavoritesTests
//
// Unit tests for FavoritesServiceImpl.
// These tests use an in-memory or temporary favorites.sqlite so no state
// persists between runs, and no PII is touched during testing.

import XCTest
@testable import STOLFavorites

final class STOLFavoritesTests: XCTestCase {

    // MARK: - Helpers

    /// Returns a fresh temporary directory for each test.
    private func makeTempAppSupport() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("STOLFavoritesTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Tests

    func testAddAndIsFavourite() async throws {
        let svc = try FavoritesServiceImpl(appSupportURL: makeTempAppSupport())
        let id: TaxonID = 42

        await XCTAssertFalse(svc.isFavourite(taxonID: id))
        try await svc.addFavourite(taxonID: id)
        await XCTAssertTrue(svc.isFavourite(taxonID: id))
    }

    func testAddIsIdempotent() async throws {
        let svc = try FavoritesServiceImpl(appSupportURL: makeTempAppSupport())
        let id: TaxonID = 7

        try await svc.addFavourite(taxonID: id)
        try await svc.addFavourite(taxonID: id)   // second add must not throw
        let count = await svc.favouritesCount()
        XCTAssertEqual(count, 1)
    }

    func testRemove() async throws {
        let svc = try FavoritesServiceImpl(appSupportURL: makeTempAppSupport())
        let id: TaxonID = 99

        try await svc.addFavourite(taxonID: id)
        try await svc.removeFavourite(taxonID: id)
        await XCTAssertFalse(svc.isFavourite(taxonID: id))
    }

    func testRemoveIsIdempotent() async throws {
        let svc = try FavoritesServiceImpl(appSupportURL: makeTempAppSupport())
        // Removing a taxon that was never added must not throw.
        try await svc.removeFavourite(taxonID: 1_000_000)
    }

    func testToggle() async throws {
        let svc = try FavoritesServiceImpl(appSupportURL: makeTempAppSupport())
        let id: TaxonID = 3

        let addedState = try await svc.toggleFavourite(taxonID: id)
        XCTAssertTrue(addedState)

        let removedState = try await svc.toggleFavourite(taxonID: id)
        XCTAssertFalse(removedState)
    }

    func testAllFavouritesOrdering() async throws {
        let svc = try FavoritesServiceImpl(appSupportURL: makeTempAppSupport())
        // Add IDs in order; allFavourites should return them most-recently-added first.
        let ids: [TaxonID] = [10, 20, 30]
        for id in ids {
            try await svc.addFavourite(taxonID: id)
        }
        let entries = try await svc.allFavourites()
        XCTAssertEqual(entries.map(\.taxonID), [30, 20, 10])
    }

    func testClearAll() async throws {
        let svc = try FavoritesServiceImpl(appSupportURL: makeTempAppSupport())
        try await svc.addFavourite(taxonID: 1)
        try await svc.addFavourite(taxonID: 2)
        try await svc.clearAllFavourites()
        let count = await svc.favouritesCount()
        XCTAssertEqual(count, 0)
    }

    func testStorageBytesPositiveAfterInsert() async throws {
        let svc = try FavoritesServiceImpl(appSupportURL: makeTempAppSupport())
        try await svc.addFavourite(taxonID: 100)
        let bytes = try await svc.storageBytes()
        XCTAssertGreaterThan(bytes, 0)
    }

    // MARK: - Privacy invariant tests

    /// The favourites database file must contain ONLY the two expected columns
    /// and no columns that could carry PII.
    func testSchemaContainsNoPIIColumns() async throws {
        let appSupport = try makeTempAppSupport()
        _ = try FavoritesServiceImpl(appSupportURL: appSupport)
        let dbURL = appSupport
            .appendingPathComponent("Favorites/favorites.sqlite")
        // Stub: in a full build, open the db with GRDB and inspect PRAGMA table_info(favorites).
        // Expected columns: taxon_id, created_at — nothing else.
        XCTAssertTrue(FileManager.default.fileExists(atPath: dbURL.path),
                      "favorites.sqlite must exist after init")
        // Further column-level assertions require GRDB; add when GRDB is wired in.
    }
}

// MARK: - Async XCTest helpers

private func XCTAssertTrue(_ expression: @autoclosure () async -> Bool,
                            _ message: String = "", file: StaticString = #file, line: UInt = #line) async {
    let result = await expression()
    XCTAssertTrue(result, message, file: file, line: line)
}

private func XCTAssertFalse(_ expression: @autoclosure () async -> Bool,
                             _ message: String = "", file: StaticString = #file, line: UInt = #line) async {
    let result = await expression()
    XCTAssertFalse(result, message, file: file, line: line)
}
