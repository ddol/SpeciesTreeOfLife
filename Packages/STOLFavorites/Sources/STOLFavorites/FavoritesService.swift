// FavoritesService.swift — STOLFavorites
//
// Privacy guarantees (enforced by design):
//   • Stores only opaque taxon IDs (Int64 species DB keys) and ISO-8601 creation
//     timestamps. Neither field identifies a person.
//   • Data is written to a dedicated favorites.sqlite inside the app's Application
//     Support sandbox. It never leaves the device via any app-initiated network call.
//   • Standard OS backup (encrypted, user-owned) is permitted; CloudKit / iCloud
//     Drive sync is NOT enabled — no server ever receives this data from us.
//   • All data is user-deletable via clearAllFavourites() or Settings → Favourites
//     → Clear All.

import Foundation
import STOLData   // for TaxonID

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Public types
// ─────────────────────────────────────────────────────────────────────────────

/// A single favourite record. Contains no PII.
public struct FavouriteEntry: Identifiable, Sendable, Hashable {
    /// Stable identity for SwiftUI list diffing.
    public var id: TaxonID { taxonID }
    /// Opaque species database key. Not a user identifier.
    public let taxonID: TaxonID
    /// When this species was favourited. Used for display ordering only;
    /// never transmitted, exported, or included in diagnostics.
    public let createdAt: Date
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Protocol
// ─────────────────────────────────────────────────────────────────────────────

/// Local-only, privacy-safe favourites storage.
///
/// All methods are `async` so callers can be written uniformly regardless of
/// whether the concrete implementation uses a background actor (it does).
public protocol FavoritesService: AnyObject, Sendable {

    // MARK: Querying

    /// Returns `true` if the taxon is currently marked as a favourite.
    func isFavourite(taxonID: TaxonID) async -> Bool

    /// All favourited entries, ordered by most recently added first.
    func allFavourites() async throws -> [FavouriteEntry]

    /// Total number of favourited taxa.
    func favouritesCount() async -> Int

    // MARK: Mutations

    /// Add a taxon to favourites. No-op if already favourited.
    func addFavourite(taxonID: TaxonID) async throws

    /// Remove a taxon from favourites. No-op if not favourited.
    func removeFavourite(taxonID: TaxonID) async throws

    /// Toggle favourite status.
    /// - Returns: The new state — `true` if now favourited, `false` if removed.
    @discardableResult
    func toggleFavourite(taxonID: TaxonID) async throws -> Bool

    /// Permanently delete every favourite entry.
    /// This is an explicit user-initiated action; no automatic triggers.
    func clearAllFavourites() async throws

    // MARK: Storage

    /// Approximate on-disk size of the favourites database in bytes.
    func storageBytes() async throws -> Int64
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Implementation
// ─────────────────────────────────────────────────────────────────────────────

/// Concrete implementation backed by a private SQLite database via GRDB.swift.
///
/// The actor serialises all database access. An in-memory `Set<TaxonID>` is
/// maintained as a hot cache for O(1) `isFavourite` checks without disk I/O.
public actor FavoritesServiceImpl: FavoritesService {

    // MARK: Private state

    /// GRDB DatabaseQueue for favorites.sqlite.
    /// Declared as `Any` here so this file compiles without GRDB imported at
    /// the module level — the concrete type is resolved in the implementation body.
    /// In a real build, replace `Any` with `DatabaseQueue` and `import GRDB`.
    private let dbQueue: Any   // DatabaseQueue (GRDB)

    /// Hot-cache of favourited IDs for O(1) reads.
    private var cachedIDs: Set<TaxonID> = []

    // MARK: Initialisation

    /// - Parameter appSupportURL: The app's Application Support directory URL.
    ///   A `Favorites/` subdirectory is created automatically if absent.
    public init(appSupportURL: URL) throws {
        let dir = appSupportURL.appendingPathComponent("Favorites", isDirectory: true)
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true, attributes: nil
        )
        let dbURL = dir.appendingPathComponent("favorites.sqlite")

        // Stub: in production, replace with:
        //   self.dbQueue = try DatabaseQueue(path: dbURL.path)
        //   followed by the schema migration below.
        _ = dbURL          // silence unused-variable warning in stub
        self.dbQueue = ()  // placeholder

        // Schema (run once at init; idempotent):
        //   CREATE TABLE IF NOT EXISTS favorites (
        //       taxon_id    INTEGER PRIMARY KEY,
        //       created_at  TEXT NOT NULL
        //           DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
        //   );
        //   CREATE INDEX IF NOT EXISTS idx_favorites_created
        //       ON favorites(created_at DESC);
        //
        // Warm in-memory cache:
        //   cachedIDs = Set(try dbQueue.read { db in
        //       try TaxonID.fetchAll(db, sql: "SELECT taxon_id FROM favorites")
        //   })
    }

    // MARK: FavoritesService — Querying

    public func isFavourite(taxonID: TaxonID) -> Bool {
        cachedIDs.contains(taxonID)
    }

    public func allFavourites() throws -> [FavouriteEntry] {
        // SELECT taxon_id, created_at FROM favorites ORDER BY created_at DESC
        fatalError("stub — implement with GRDB DatabaseQueue.read")
    }

    public func favouritesCount() -> Int {
        cachedIDs.count
    }

    // MARK: FavoritesService — Mutations

    public func addFavourite(taxonID: TaxonID) throws {
        guard !cachedIDs.contains(taxonID) else { return }
        // INSERT OR IGNORE INTO favorites (taxon_id) VALUES (?)
        fatalError("stub — implement with GRDB DatabaseQueue.write")
        // cachedIDs.insert(taxonID)
    }

    public func removeFavourite(taxonID: TaxonID) throws {
        guard cachedIDs.contains(taxonID) else { return }
        // DELETE FROM favorites WHERE taxon_id = ?
        fatalError("stub — implement with GRDB DatabaseQueue.write")
        // cachedIDs.remove(taxonID)
    }

    @discardableResult
    public func toggleFavourite(taxonID: TaxonID) throws -> Bool {
        if cachedIDs.contains(taxonID) {
            try removeFavourite(taxonID: taxonID)
            return false
        } else {
            try addFavourite(taxonID: taxonID)
            return true
        }
    }

    public func clearAllFavourites() throws {
        // DELETE FROM favorites
        fatalError("stub — implement with GRDB DatabaseQueue.write")
        // cachedIDs.removeAll()
    }

    // MARK: FavoritesService — Storage

    public func storageBytes() throws -> Int64 {
        // PRAGMA page_count * PRAGMA page_size
        fatalError("stub — implement with GRDB DatabaseQueue.read")
    }
}
