# Species: Tree of Life — Engineering Design Document

**Status:** Draft v0.1  
**Date:** 2026-02-24  
**Audience:** iOS/macOS engineers, data engineers, product, App Store review  

**Related Documentation:**
- [Visual Design Spec](VisualDesign.md) — colour system, typography, shape language, motion, SwiftUI tokens
- [Data Loading Spec](DataLoading.md) — DB format, pipeline, import/validation, search indexing
- [Favourites Feature Spec](Favorites.md) — privacy-safe local favourites: schema, service API, UI, risks

---

## Table of Contents

1. [Goals](#1-goals)
2. [Non-Goals](#2-non-goals)
3. [Product Overview](#3-product-overview)
4. [Privacy & Permissions (Hard Requirements)](#4-privacy--permissions-hard-requirements)
5. [Architecture Decisions](#5-architecture-decisions)
6. [Architecture Diagram](#6-architecture-diagram)
7. [Data Model & Schema](#7-data-model--schema)
8. [DB Strategy](#8-db-strategy)
9. [Data Pipeline](#9-data-pipeline)
10. [Swift API Design](#10-swift-api-design)
11. [UI Structure](#11-ui-structure)
12. [CompareService & Top-N Algorithm](#12-compareservice--top-n-algorithm)
13. [Risks & Mitigations](#13-risks--mitigations)
14. [Milestone Plan](#14-milestone-plan)
15. [Repo & Swift Package Layout](#15-repo--swift-package-layout)

---

## 1. Goals

| # | Goal |
|---|------|
| G1 | Multiplatform Swift app: **iOS + iPadOS + macOS** from one repo (separate build artifacts per platform). |
| G2 | **Offline-first** kids learning app: fully usable with the bundled dataset and no network. |
| G3 | **Privacy is a core tenet** (see §4 for hard requirements). |
| G4 | Bundled default species database ships inside the app bundle (immutable, always available). |
| G5 | Optional ability to load a second/newer "reference database" (user-provided file, or optional explicit download). |
| G6 | **Species comparison**: show taxonomic distance + explanatory path + **top-N closest relatives**. |
| G7 | Consistent SwiftUI rendering across platforms with minimal platform shims. |
| G8 | **Local-only favourites**: users can save species to a private on-device favourites list. No PII stored; no sync or remote storage. |

---

## 2. Non-Goals

- Shipping a single universal binary; separate artifacts per platform are expected and acceptable.
- Cloud dependency for core features (no iCloud required; CloudKit is out of scope for v1).
- Social or community features; any sharing is local-only with no account requirement.
- Location tracking, contacts, photo library access, microphone, or camera use.
- Remote crash reporting or analytics in v1 (even "anonymous"); local-only debug logs only.
- Background refresh, push notifications, or widgets in v1.

---

## 3. Product Overview

**Species: Tree of Life** displays a navigable taxonomy tree (Domain → Kingdom → Phylum → Class → Order → Family → Genus → Species). Users can:

- **Browse** the full tree top-down or jump to any rank.
- **Search** by scientific name, common name, and synonyms (with fuzzy matching).
- **Filter** by rank, habitat, or conservation status.
- **View detail pages**: images, traits, habitat, conservation status, references/citations.
- **Compare** two species: taxonomic distance, shared ancestor path, trait deltas.
- **Discover top-N closest relatives** to any species.
- **Favourite** species to a private local list; view, reorder, and clear favourites at any time.

The primary target audience is children and students; the UX must be safe, ad-free, and require no account.

---

## 4. Privacy & Permissions (Hard Requirements)

### 4.1 What Counts as PII

For this app, PII includes (but is not limited to): name, email, device ID, advertising ID (IDFA/IDFV), IP address, precise or coarse location, browsing history linked to a person, or any combination of data that could identify a natural person.

**We do not collect, store, transmit, or process any PII. Ever.**

### 4.2 Permission Matrix

| Permission | Status | Justification |
|---|---|---|
| Network / Internet (app networking behaviour) | **No networking features in v1 on iOS/iPadOS. No macOS network sandbox entitlements requested in v1.** Any future download/sync feature is gated behind an explicit in-app setting — not an OS permission prompt. | See §4.3. |
| Location (precise) | **Never requested.** | Non-goal; prohibited. |
| Location (coarse) | **Never requested.** | Same. |
| Contacts | **Never requested.** | Non-goal. |
| Photos Library | **Never requested.** | Non-goal. |
| Camera | **Never requested.** | Non-goal. |
| Microphone | **Never requested.** | Non-goal. |
| Face ID / Touch ID | **Never requested.** | No auth, no account. |
| Advertising tracking (ATT) | **Never requested.** | No ads, no ad-tech SDKs. |
| Background App Refresh | **Off by default.** Not requested in v1. | No background tasks needed. |
| Push Notifications | **Never requested.** | Non-goal. |
| Local Network | **Never requested.** | Non-goal. |

### 4.3 Optional Network Access Rules

If the app offers an optional "download newer reference DB" feature (future milestone), it **must** comply with all of the following:

1. **Off by default.** The feature is disabled until the user explicitly enables it in Settings.
2. **User-initiated only.** No background fetch, no silent downloads.
3. **Clearly explained.** A disclosure screen before any download describes exactly what is fetched, from where, and why. No dark patterns.
4. **No tracking identifiers.** Requests must not include IDFA, IDFV, device serial, or any per-user token.
5. **HTTPS only** with certificate pinning (or App Transport Security default; no ATS exceptions).
6. **Checksum verification** of downloaded file before use (see §9).
7. **No ATS exceptions or extra networking capabilities.** No `NSAppTransportSecurity` exceptions are declared in `Info.plist`, and no additional networking-related entitlements or feature code paths are compiled in for builds where this optional download feature is disabled.

### 4.4 Telemetry, Logging, and Analytics

- **Zero remote telemetry.** No Firebase, Amplitude, Mixpanel, Sentry, Crashlytics, or equivalent.
- **Zero analytics SDKs.** No third-party SDK may phone home.
- **Local logging only** via `os_log` / `Logger` (OSLog framework). Logs are never written to disk in release builds unless the user explicitly enables a "Diagnostics" mode.
- **In-app diagnostics export** (v1.1+): user-initiated, exports a plain-text file with no PII, presented via the standard share sheet so the user controls the destination.
- Local debug logs are deletable from Settings → Storage → Delete Diagnostics.

### 4.5 App Store Privacy Nutrition Label Declarations

| Category | Collected? | Notes |
|---|---|---|
| Contact Info | No | |
| Health & Fitness | No | |
| Financial Info | No | |
| Location | No | |
| Sensitive Info | No | |
| Contacts | No | |
| User Content | No | |
| Browsing History | No | |
| Search History | No | Searches are local-only; not logged or persisted beyond the current session. |
| Identifiers | No | |
| Purchases | No | |
| Usage Data | No | |
| Diagnostics | No | No remote crash/performance reporting. |

**Result:** "No Data Collected" declaration on the App Store privacy label.

### 4.6 Favourites Privacy

Favourites are stored **entirely on-device** in a dedicated SQLite file (`favorites.sqlite`) inside the app's Application Support sandbox. The following invariants hold:

| Property | Detail |
|---|---|
| What is stored | `taxon_id` (opaque `INTEGER` database key) + `created_at` (ISO-8601 timestamp). Nothing else. |
| What is NOT stored | Any user identifier, device ID, name, account, IP address, or behavioural profile. |
| Is `taxon_id` PII? | No. It is a species database key (e.g., `12345` = *Panthera leo*). It cannot identify a person. |
| Is `created_at` PII? | No, by itself. A sequence of timestamps in isolation cannot identify a person. The data never leaves the device. |
| Network transmission | Never. Favourites are strictly local. |
| iCloud backup | Allowed by default (standard OS backup is encrypted and belongs to the user). The favourites file is **not** enrolled in iCloud Drive or CloudKit sync — no server ever receives it from us. |
| User control | Users can delete individual favourites or wipe all favourites from Settings → Favourites → Clear All. The operation is immediate and permanent. |
| Export | "Export Favourites" (user-initiated) produces a plain-text list of species names — no timestamps, no IDs. Presented via the OS share sheet; destination is the user's choice. |

---

## 5. Architecture Decisions

### 5A. Platform Strategy

**Decision: SwiftUI Multiplatform with separate Xcode targets sharing Swift Packages.**

| Option | Pros | Cons |
|---|---|---|
| SwiftUI Multiplatform template (single target) | Less boilerplate | Harder to customize per platform; one Info.plist |
| **Separate targets + shared Swift Packages** ✅ | Clean per-platform Info.plist, entitlements, icons; better CI control | Slightly more initial setup |
| Mac Catalyst | Reuse iOS build directly | UIKit shims hurt macOS UX; not native-feel for kids |

**Rationale:** Separate targets share all business logic and most UI via Swift Packages. Mac Catalyst is rejected because it produces a noticeably worse macOS experience (menu bar, window management, scrolling). Native macOS via SwiftUI `#if os(macOS)` conditionals gives a far better result for the kid UX and performance goal.

### 5B. Storage

**Decision: SQLite with FTS5, accessed via GRDB.swift (thin wrapper, no ORM overhead).**

| Option | Pros | Cons |
|---|---|---|
| **SQLite + FTS5 (GRDB.swift)** ✅ | Proven, cross-platform, excellent FTS, bundled read-only possible, tiny footprint | Requires schema migration management |
| Core Data | Apple-native, CloudKit sync available | CloudKit violates privacy goals; complex for read-only bundle; harder FTS |
| File-based snapshots (JSON/plist) | Simple | No FTS, slow search, large memory footprint for big datasets |

**Bundled DB:** Shipped as a prebuilt `.sqlite` file inside the app bundle, opened with `SQLITE_OPEN_READONLY`. Never written to.  
**Secondary DB:** Stored in `Application Support/Databases/reference.sqlite`. Read-only or read-write (we choose read-only to prevent accidental corruption; writes only via controlled migration steps).

### 5C. Data Ingestion

- **Bundled DB format:** Prebuilt SQLite (`bundled.sqlite`) committed to the repo or generated by the data pipeline CI job and embedded in the app bundle.
- **Reference DB format:** A gzip-compressed SQLite file (`.stol` extension, MIME `application/x-stol-db`) signed with an Ed25519 key. The app verifies the signature and SHA-256 checksum before opening.
- **Schema versioning:** A `schema_version` table with a single `version INTEGER` row. The app refuses to open a DB whose schema version is ahead of what it understands.
- **Atomic import:** Download/copy to a `.tmp` file → verify checksum + signature → rename to final path. If any step fails, `.tmp` is deleted; the working DB is never touched.

### 5D. Search

- **Primary index:** FTS5 virtual table over `scientific_name`, `common_name` (all languages), and `synonyms`.
- **Rank filtering:** Standard B-tree index on `taxa.rank`.
- **Fuzzy search:** FTS5 prefix queries (`term*`) for autocomplete; for deeper fuzzy matching, a trigram index (`fts5vocab`) or client-side Levenshtein on top-5 FTS candidates.
- **Synonyms:** Stored in the `names` table (see §7) and included in the FTS index.

### 5E. Media

- **Bundled images:** Optional image assets compiled into a separate asset catalog or a bundled `MediaPack.bundle`. Images are served directly from the bundle; no network needed.
- **Optional media packs:** User-downloadable `.stol-media` packages (same signing/checksum flow as DB). Stored in `Application Support/Media/`.
- **Storage limits & eviction:** User can view storage usage in Settings. Optional media packs can be deleted individually. Bundled assets are not deletable.
- **No network image loading** in v1 (no Kingfisher, SDWebImage, etc.).

### 5F. Comparison / Similarity

See §12 for full algorithm details.

- **Primary metric:** Taxonomic distance via LCA (Lowest Common Ancestor) path length in the taxonomy tree.
- **Secondary metric (optional):** Attribute-based similarity (trait/habitat overlap) when trait data is available.
- **LCA strategy:** Euler-tour + sparse table (RMQ) precomputed at DB load time for O(1) LCA queries on in-memory tree. For DB sizes > 500 k nodes, fallback to on-demand path-to-root comparison.
- **Top-N nearest neighbors:** Precomputed `top_n_relatives` table populated by an offline pipeline (see §7.5 and §12).

### 5G. App Architecture

See §6 and §10.

- **Module boundaries:** Strict Swift Package per concern (Core, Data, Search, Compare, Media, UI-shared, UI-iOS, UI-macOS).
- **Concurrency:** Swift `async`/`await` throughout; actors for shared mutable state (`DatabaseActor`, `MediaCacheActor`).
- **Dependency injection:** Protocol-based DI; concrete implementations injected at app startup. No singleton service locator.

### 5H. Testing & CI

- **Unit tests:** DB switching, import validation (happy path + corrupt file), search (FTS + fuzzy), comparison (LCA distance, top-N).
- **Performance tests:** Cold start time < 2 s, search latency < 100 ms for FTS queries, compare latency < 50 ms for LCA, DB load time < 3 s for 500 k taxa.
- **CI:** GitHub Actions; build matrix: `xcodebuild` for iOS Simulator + macOS. No remote secrets required (no signing keys in CI for test builds).

### 5I. Observability (Local-Only)

- **OSLog subsystem:** `com.species.treeoflife` with categories: `db`, `search`, `compare`, `ui`, `import`.
- **Log levels:** `.debug` and `.info` emitted in Debug builds only. `.error` and `.fault` always emitted, never remote.
- **In-app debug screen:** Hidden behind Settings → Developer (enabled only in Debug builds). Shows recent log entries, DB stats, cache size.
- **Export diagnostics:** Settings → Storage → Export Diagnostics. Produces a plain `.txt` file via `UIActivityViewController` / `NSSharingServicePicker`. File contains only log lines + app version + OS version. No device ID, no IDFA.

---

## 6. Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        App Targets                              │
│  ┌─────────────────────┐     ┌────────────────────────────┐    │
│  │  SpeciesTreeOfLife  │     │  SpeciesTreeOfLife-macOS   │    │
│  │  (iOS/iPadOS target)│     │  (macOS target)            │    │
│  └──────────┬──────────┘     └──────────────┬─────────────┘    │
│             │                               │                   │
│  ┌──────────▼───────────────────────────────▼─────────────┐    │
│  │                   STOLAppCore (Swift Package)           │    │
│  │   AppCoordinator · DI Container · Navigation Router    │    │
│  └─┬──────────┬─────────────┬─────────────┬──────────────┘    │
│    │          │             │             │                     │
│  ┌─▼──────┐ ┌─▼──────────┐ ┌▼──────────┐ ┌▼─────────────┐ ┌▼────────────┐  │
│  │STOLData│ │STOLSearch  │ │STOLCompare│ │STOLMedia     │ │STOLFavorites│  │
│  │        │ │            │ │           │ │              │ │             │  │
│  │· DB    │ │· FTS engine│ │· LCA      │ │· MediaCache  │ │· Favorites  │  │
│  │  actor │ │· Fuzzy     │ │· Top-N    │ │  actor       │ │  actor      │  │
│  │· Schema│ │· Rank flt. │ │· Trait    │ │· Pack loader │ │· Local SQLite│ │
│  │· Import│ │            │ │  similarity│ │              │ │  (no PII)   │  │
│  └─┬──────┘ └────────────┘ └───────────┘ └──────────────┘ └─────────────┘  │
│    │                                                           │
│  ┌─▼──────────────────────┐                                   │
│  │  STOLSharedUI          │  (SwiftUI views shared by both    │
│  │  (Swift Package)       │   targets with #if os() shims)    │
│  │  · TreeBrowser         │                                   │
│  │  · SearchView          │                                   │
│  │  · SpeciesDetail       │                                   │
│  │  · CompareView         │                                   │
│  │  · FavouritesView      │                                   │
│  │  · SettingsView        │                                   │
│  └────────────────────────┘                                   │
└─────────────────────────────────────────────────────────────────┘

Dependency direction: Targets → AppCore → Data/Search/Compare/Media/Favorites
                      SharedUI → AppCore (protocols only)
                      No circular dependencies.
```

---

## 7. Data Model & Schema

### 7.1 `taxa` Table

```sql
CREATE TABLE taxa (
    id              INTEGER PRIMARY KEY,      -- internal stable ID
    parent_id       INTEGER REFERENCES taxa(id),
    rank            TEXT    NOT NULL,         -- 'domain','kingdom','phylum','class',
                                              --   'order','family','genus','species'
    scientific_name TEXT    NOT NULL,
    author          TEXT,                     -- taxonomic authority string
    year            INTEGER,                  -- year of description
    status          TEXT    NOT NULL          -- 'accepted','synonym','doubtful'
        CHECK (status IN ('accepted','synonym','doubtful')),
    conservation    TEXT,                     -- IUCN status code: 'LC','NT','VU','EN','CR','EW','EX','NE'
    created_at      TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at      TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

CREATE INDEX idx_taxa_parent   ON taxa(parent_id);
CREATE INDEX idx_taxa_rank     ON taxa(rank);
CREATE INDEX idx_taxa_status   ON taxa(status);
CREATE INDEX idx_taxa_name     ON taxa(scientific_name);
```

### 7.2 `names` Table

```sql
CREATE TABLE names (
    id          INTEGER PRIMARY KEY,
    taxon_id    INTEGER NOT NULL REFERENCES taxa(id) ON DELETE CASCADE,
    name        TEXT    NOT NULL,
    lang        TEXT    NOT NULL,   -- BCP-47 language tag, e.g. 'en', 'es', 'zh-Hans'
    name_type   TEXT    NOT NULL    -- 'common', 'synonym', 'vernacular', 'trade'
        CHECK (name_type IN ('common','synonym','vernacular','trade')),
    is_preferred INTEGER NOT NULL DEFAULT 0  -- 1 if this is the preferred common name for the lang
);

CREATE INDEX idx_names_taxon   ON names(taxon_id);
CREATE INDEX idx_names_lang    ON names(lang);
CREATE INDEX idx_names_type    ON names(name_type);
```

### 7.3 `references` (Citations) Table

```sql
CREATE TABLE refs (
    id          INTEGER PRIMARY KEY,
    taxon_id    INTEGER NOT NULL REFERENCES taxa(id) ON DELETE CASCADE,
    citation    TEXT    NOT NULL,   -- full citation string
    url         TEXT,               -- optional DOI or URL (static reference, not fetched)
    ref_type    TEXT    NOT NULL    -- 'taxonomy','ecology','morphology','conservation'
        CHECK (ref_type IN ('taxonomy','ecology','morphology','conservation','other'))
);

CREATE INDEX idx_refs_taxon ON refs(taxon_id);
```

### 7.4 `traits` Table (Optional)

```sql
CREATE TABLE traits (
    id          INTEGER PRIMARY KEY,
    taxon_id    INTEGER NOT NULL REFERENCES taxa(id) ON DELETE CASCADE,
    trait_key   TEXT    NOT NULL,   -- e.g. 'habitat', 'diet', 'locomotion', 'body_length_mm'
    trait_value TEXT    NOT NULL,   -- free text or controlled vocabulary value
    unit        TEXT,               -- SI unit if numeric, NULL if categorical
    source_ref  INTEGER REFERENCES refs(id)
);

CREATE INDEX idx_traits_taxon ON traits(taxon_id);
CREATE INDEX idx_traits_key   ON traits(trait_key);
```

### 7.5 Precomputed LCA Helper Tables

#### `euler_tour`

```sql
-- Euler tour sequence for RMQ-based O(1) LCA.
-- Populated by the offline data pipeline; not modified at runtime.
CREATE TABLE euler_tour (
    seq         INTEGER PRIMARY KEY,  -- position in the tour (0-indexed)
    taxon_id    INTEGER NOT NULL REFERENCES taxa(id),
    depth       INTEGER NOT NULL      -- depth in the tree (root = 0)
);

-- first_occurrence[taxon_id] = first seq index where taxon_id appears in the tour
CREATE TABLE first_occurrence (
    taxon_id    INTEGER PRIMARY KEY REFERENCES taxa(id),
    seq         INTEGER NOT NULL
);
```

#### `top_n_relatives`

```sql
-- Precomputed top-N closest relatives per species (by LCA taxonomic distance).
-- N is configurable at pipeline time (default 10).
-- Only populated for leaf taxa (rank = 'species').
CREATE TABLE top_n_relatives (
    taxon_id        INTEGER NOT NULL REFERENCES taxa(id),
    relative_id     INTEGER NOT NULL REFERENCES taxa(id),
    rank_order      INTEGER NOT NULL,   -- 1 = closest, 2 = second closest, …
    lca_id          INTEGER NOT NULL REFERENCES taxa(id),
    lca_depth       INTEGER NOT NULL,
    distance        INTEGER NOT NULL,   -- path length: (depth_a - lca_depth) + (depth_b - lca_depth)
    PRIMARY KEY (taxon_id, rank_order)
);

CREATE INDEX idx_top_n_taxon ON top_n_relatives(taxon_id);
```

### 7.6 `schema_version` Table

```sql
CREATE TABLE schema_version (
    version     INTEGER NOT NULL,
    applied_at  TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);
-- Always contains exactly one row.
INSERT INTO schema_version (version) VALUES (1);
```

### 7.7 FTS5 Virtual Table

```sql
-- Full-text search across scientific names, common names, and synonyms.
CREATE VIRTUAL TABLE fts_taxa USING fts5(
    taxon_id UNINDEXED,
    scientific_name,
    common_names,        -- space-separated concatenation of names.name where name_type IN ('common','vernacular')
    synonyms,            -- space-separated concatenation of names.name where name_type = 'synonym'
    content='',          -- contentless FTS for lower storage; rebuilt by pipeline
    tokenize='unicode61 remove_diacritics 2'
);
```

### 7.8 `favorites` Table

Stored in a **separate** `favorites.sqlite` file (Application Support), not in the taxonomy DB. This keeps favourites independent of taxonomy DB switching and avoids any write access to the read-only taxonomy DBs.

```sql
-- Privacy note: only opaque taxon IDs and creation timestamps are stored.
-- No user identifiers, no device IDs, no PII of any kind.
CREATE TABLE favorites (
    taxon_id    INTEGER PRIMARY KEY,   -- opaque species DB key; not a user identifier
    created_at  TEXT NOT NULL          -- ISO-8601 UTC with fractional seconds; used for "most recently added" ordering only
        DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

-- Supports ordered retrieval by recency.
CREATE INDEX idx_favorites_created ON favorites(created_at DESC);
```

**Storage characteristics:**

| Property | Value |
|---|---|
| File location | `<Application Support>/Favorites/favorites.sqlite` |
| Open flags | `SQLITE_OPEN_READWRITE \| SQLITE_OPEN_CREATE` |
| Max expected rows | Unbounded; practically < 10 000 for a typical user |
| Size per row | ~30 bytes → 10 000 favourites ≈ 300 KB |
| iCloud backup | Yes (standard OS backup; no app-level sync) |
| Excluded from iCloud Drive | Yes (not enrolled in CloudKit or iCloud Drive) |
```

---

## 8. DB Strategy

### 8.1 Bundled (Immutable) DB

| Property | Value |
|---|---|
| File name | `bundled.sqlite` |
| Location | App bundle (`Bundle.main.url(forResource:withExtension:)`) |
| Open flags | `SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX` |
| Write protection | File is read-only by OS; no write path exists in code |
| Availability | Always available; cannot be deleted by user action |

### 8.2 Reference (Secondary) DB

| Property | Value |
|---|---|
| File name | `reference.sqlite` |
| Location | `<Application Support>/Databases/reference.sqlite` |
| Open flags | `SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX` |
| Write protection | Opened read-only; written only by the atomic import flow |
| Activation | User explicitly enables in Settings; stored in `UserDefaults` (key: `useReferenceDB`) |
| Fallback | If reference DB is corrupt/missing, app silently falls back to bundled DB |

### 8.3 DB Activation Flow

```
User taps "Use Reference Database" in Settings
    → DatabaseProvider.activateReferenceDB()
    → Verifies schema_version compatibility
    → Sets useReferenceDB = true in UserDefaults
    → DatabaseActor switches active connection
    → Posts .databaseDidSwitch notification
    → All open ViewModels refresh their data
```

### 8.4 Safe Delete Plan (Optional Advanced Action)

The reference DB can be deleted to free storage. The bundled DB is **never** deletable.

```
User taps "Delete Reference Database" (behind confirmation sheet)
    → App warns: "The app will revert to the built-in database."
    → User confirms
    → DatabaseActor.deactivateReferenceDB()
        → Sets useReferenceDB = false
        → Closes reference DB connection
        → Deletes reference.sqlite
    → App reverts to bundled DB
    → User can re-import a reference DB at any time
```

Safety invariant: The bundled DB is **never touched** by any delete operation. Code review must enforce this with a lint rule or dedicated test.

---

## 9. Data Pipeline

### 9.1 Initial Install

```
App first launch
    └─ DatabaseProvider.initialize()
        ├─ Locate bundled.sqlite in app bundle
        ├─ Open read-only connection
        ├─ Verify schema_version == expected
        └─ Ready
```

### 9.2 Adding a New Reference DB

```
User taps "Import Reference Database"
    └─ Presents document picker (UTType: com.species.stol-db)
    └─ User selects .stol file
    └─ ImportService.importReferenceDB(url:)
        ├─ Copy to <tmp>/import_candidate.sqlite.gz
        ├─ Verify SHA-256 checksum (embedded in file header or .sha256 sidecar)
        ├─ Verify Ed25519 signature against hardcoded public key
        ├─ Decompress to <tmp>/import_candidate.sqlite
        ├─ Open candidate DB, verify schema_version
        ├─ Run integrity check: PRAGMA integrity_check
        ├─ [If any step fails] → delete tmp files → throw ImportError → show user alert
        ├─ Move to <Application Support>/Databases/reference.sqlite (atomic rename)
        ├─ Activate reference DB (§8.3)
        └─ Delete tmp files
```

### 9.3 Validation Checklist

| Check | Method | Failure action |
|---|---|---|
| File extension / UTType | OS document picker filter | Picker prevents wrong types |
| File size sanity | `> 0`, `< 2 GB` | `ImportError.fileTooLarge` |
| SHA-256 checksum | Compare header bytes vs computed | `ImportError.checksumMismatch` |
| Ed25519 signature | CryptoKit `Curve25519.Signing` | `ImportError.signatureInvalid` |
| Schema version | `SELECT version FROM schema_version` | `ImportError.incompatibleSchema` |
| SQLite integrity | `PRAGMA integrity_check` returns `ok` | `ImportError.databaseCorrupt` |

### 9.4 Rollback

If any validation step fails:
1. Delete all files in `<tmp>/import_*`.
2. Leave `reference.sqlite` untouched (or absent if this was a fresh import).
3. Leave `useReferenceDB` flag unchanged.
4. Surface a localized error message to the user. No crash, no silent failure.

---

## 10. Swift API Design

All protocols are defined in `STOLData` or `STOLSearch`/`STOLCompare` packages. Concrete implementations are injected at app startup.

### 10.1 `DatabaseProvider` Protocol

```swift
/// Manages access to the active species database.
public protocol DatabaseProvider: AnyObject, Sendable {
    /// The currently active database configuration.
    var activeConfig: DatabaseConfig { get async }

    /// Whether a reference database is currently active.
    var isReferenceDBActive: Bool { get async }

    /// Read-only access to the active database.
    func read<T: Sendable>(_ block: @Sendable (Database) throws -> T) async throws -> T

    /// Activate the reference database (must already be imported).
    func activateReferenceDB() async throws

    /// Deactivate and optionally delete the reference database.
    func deactivateReferenceDB(delete: Bool) async throws
}

public struct DatabaseConfig: Sendable {
    public let source: DatabaseSource
    public let schemaVersion: Int
    public let taxaCount: Int
    public let sizeBytes: Int64
}

public enum DatabaseSource: Sendable {
    case bundled
    case reference(url: URL)
}
```

### 10.2 `TaxonomyStore` Protocol

```swift
/// High-level access to taxonomy tree data.
public protocol TaxonomyStore: AnyObject, Sendable {
    /// Fetch a taxon by its stable ID.
    func taxon(id: TaxonID) async throws -> Taxon?

    /// Fetch direct children of a taxon.
    func children(of parentID: TaxonID) async throws -> [Taxon]

    /// Fetch ancestors of a taxon from root to (but not including) the taxon itself.
    func ancestors(of taxonID: TaxonID) async throws -> [Taxon]

    /// Fetch all names (common, synonym) for a taxon.
    func names(for taxonID: TaxonID, lang: String?) async throws -> [TaxonName]

    /// Fetch traits for a taxon.
    func traits(for taxonID: TaxonID) async throws -> [Trait]

    /// Fetch references for a taxon.
    func references(for taxonID: TaxonID) async throws -> [TaxonReference]
}
```

### 10.3 `SearchService` Protocol

```swift
/// Full-text and filtered search over the taxonomy database.
public protocol SearchService: AnyObject, Sendable {
    /// Search for taxa matching the query string.
    /// - Parameters:
    ///   - query: Free-text query (scientific name, common name, synonym).
    ///   - rank: Optional rank filter.
    ///   - maxResults: Maximum number of results to return (default 50).
    func search(
        query: String,
        rank: TaxonRank?,
        maxResults: Int
    ) async throws -> [SearchResult]

    /// Autocomplete suggestions for a partial query.
    func autocomplete(prefix: String, maxResults: Int) async throws -> [String]
}

public struct SearchResult: Identifiable, Sendable {
    public let id: TaxonID
    public let scientificName: String
    public let matchedName: String      // the name that matched (may be synonym or common name)
    public let matchType: MatchType     // .scientific, .common, .synonym
    public let rank: TaxonRank
    public let conservationStatus: String?
    public let relevanceScore: Double
}

public enum MatchType: Sendable { case scientific, common, synonym }
```

### 10.4 `CompareService` Protocol

```swift
/// Compares species by taxonomic distance and optional trait similarity.
public protocol CompareService: AnyObject, Sendable {
    /// Compute the comparison result between two taxa.
    func compare(
        taxonA: TaxonID,
        taxonB: TaxonID
    ) async throws -> ComparisonResult

    /// Return the top-N closest relatives of a taxon.
    /// - Parameters:
    ///   - taxonID: The focal species (must be rank = .species).
    ///   - n: Number of relatives to return (1…100).
    ///   - source: Whether to use precomputed table or compute on-the-fly.
    func topNRelatives(
        of taxonID: TaxonID,
        n: Int,
        source: TopNSource
    ) async throws -> [RelativeResult]
}

public enum TopNSource: Sendable {
    case precomputed            // fast O(1) from top_n_relatives table
    case computed(maxCandidates: Int)   // on-the-fly BFS/DFS; slower
}

public struct ComparisonResult: Sendable {
    public let taxonA: Taxon
    public let taxonB: Taxon
    public let lca: Taxon                  // lowest common ancestor
    public let pathFromA: [Taxon]          // A → LCA (inclusive of LCA)
    public let pathFromB: [Taxon]          // B → LCA (inclusive of LCA)
    public let taxonomicDistance: Int      // |pathFromA| + |pathFromB| - 2
    public let sharedCladeDescription: String  // human-readable: "Both are in order Carnivora"
    public let traitSimilarity: Double?    // 0.0–1.0 Jaccard; nil if trait data unavailable
}

public struct RelativeResult: Identifiable, Sendable {
    public let id: TaxonID
    public let taxon: Taxon
    public let rankOrder: Int               // 1 = closest
    public let lca: Taxon
    public let lcaDepth: Int
    public let distance: Int
}
```

### 10.5 `ImportService` Protocol

```swift
/// Handles import and validation of a reference database file.
public protocol ImportService: AnyObject, Sendable {
    func importReferenceDB(from url: URL) async throws
    func cancelImport() async
    var progress: AsyncStream<ImportProgress> { get }
}

public struct ImportProgress: Sendable {
    public enum Stage: Sendable {
        case copying, verifyingChecksum, verifyingSignature,
             openingDatabase, runningIntegrityCheck, finalizing
    }
    public let stage: Stage
    public let fractionCompleted: Double
}

public enum ImportError: LocalizedError, Sendable {
    case fileTooLarge(bytes: Int64)
    case checksumMismatch
    case signatureInvalid
    case incompatibleSchema(found: Int, expected: Int)
    case databaseCorrupt(detail: String)
    case importAlreadyInProgress
}
```

### 10.6 `MediaCache` Protocol

```swift
/// Provides images for taxa from the bundle or optional media packs.
public protocol MediaCache: AnyObject, Sendable {
    /// Return the image for a taxon, or nil if not available.
    func image(for taxonID: TaxonID) async -> PlatformImage?

    /// Return all available media packs.
    func availableMediaPacks() async -> [MediaPack]

    /// Total storage used by optional (non-bundled) media packs.
    func optionalMediaStorageBytes() async -> Int64

    /// Delete an optional media pack.
    func deleteMediaPack(id: MediaPackID) async throws
}

#if canImport(UIKit)
public typealias PlatformImage = UIImage
#elseif canImport(AppKit)
public typealias PlatformImage = NSImage
#endif
```

### 10.7 Core Data Types

```swift
public typealias TaxonID = Int64

public struct Taxon: Identifiable, Hashable, Sendable {
    public let id: TaxonID
    public let parentID: TaxonID?
    public let rank: TaxonRank
    public let scientificName: String
    public let author: String?
    public let year: Int?
    public let status: TaxonStatus
    public let conservationStatus: String?
}

public enum TaxonRank: String, CaseIterable, Sendable, Codable {
    case domain, kingdom, phylum, `class`, order, family, genus, species
}

public enum TaxonStatus: String, Sendable { case accepted, synonym, doubtful }

public struct TaxonName: Sendable {
    public let taxonID: TaxonID
    public let name: String
    public let lang: String
    public let nameType: NameType
    public let isPreferred: Bool
}

public enum NameType: String, Sendable { case common, synonym, vernacular, trade }

public struct Trait: Sendable {
    public let taxonID: TaxonID
    public let key: String
    public let value: String
    public let unit: String?
}

public struct TaxonReference: Sendable {
    public let taxonID: TaxonID
    public let citation: String
    public let url: String?
    public let refType: String
}
```

### 10.8 `FavoritesService` Protocol

```swift
/// Local-only, privacy-safe favourites storage.
///
/// Privacy guarantees (enforced by design, not just policy):
/// - Stores only opaque taxon IDs and creation timestamps.
/// - No user identifier, device ID, or any PII is stored or derivable.
/// - Data never leaves the device (no network calls, no CloudKit sync).
/// - All data is user-deletable on demand.
public protocol FavoritesService: AnyObject, Sendable {
    /// Returns true if the taxon is currently marked as a favourite.
    func isFavourite(taxonID: TaxonID) async -> Bool

    /// Add a taxon to favourites. No-op if already favourited.
    func addFavourite(taxonID: TaxonID) async throws

    /// Remove a taxon from favourites. No-op if not favourited.
    func removeFavourite(taxonID: TaxonID) async throws

    /// Toggle favourite status. Returns the new favourite state (true = now favourited).
    @discardableResult
    func toggleFavourite(taxonID: TaxonID) async throws -> Bool

    /// All favourited taxon IDs, ordered by most recently added first.
    func allFavourites() async throws -> [FavouriteEntry]

    /// Total number of favourited taxa.
    func favouritesCount() async throws -> Int

    /// Permanently delete all favourites. Requires explicit call; no accidental trigger.
    func clearAllFavourites() async throws

    /// Approximate on-disk size of the favourites database in bytes.
    func storageBytes() async throws -> Int64
}

/// A single favourite record. Contains no PII.
public struct FavouriteEntry: Identifiable, Sendable {
    public var id: TaxonID { taxonID }
    /// Opaque species database key. Not a user identifier.
    public let taxonID: TaxonID
    /// When the species was favourited. Used for ordering only; never transmitted or logged.
    public let createdAt: Date
}
```

---

## 11. UI Structure

All views are in the `STOLSharedUI` Swift Package. Platform-specific files use `#if os(iOS)` / `#if os(macOS)` or are placed in platform overlay packages.

### 11.1 Navigation

```
iOS/iPadOS: NavigationSplitView (sidebar + detail) or NavigationStack (compact)
macOS:      NavigationSplitView with three columns (tree / list / detail)
```

### 11.2 Tree Browser (`TreeBrowserView`)

- Root level shows Domain (or Kingdom if data starts there).
- Each row shows rank badge, scientific name, preferred common name.
- Tapping expands to children (lazy loaded, cached in ViewModel).
- Breadcrumb bar shows current path (tappable to jump up).
- Filter bar: rank selector, conservation status filter.
- "Jump to" button opens Search.

### 11.3 Search (`SearchView`)

- Single text field with autocomplete suggestions dropdown.
- Results list: taxon name, rank badge, matched name (highlighted), conservation status badge.
- Rank filter chips (domain / kingdom / … / species).
- Empty state distinguishes "no query" vs "no results".
- Search is purely local (no network).

### 11.4 Species Detail (`SpeciesDetailView`)

- Header: scientific name (italic), preferred common name, rank badge, conservation badge.
- **Favourite button** (heart/star icon, top-right of header): toggles favourite status immediately via `FavoritesService.toggleFavourite`. Filled icon = favourited; outline = not favourited. No confirmation required for add; swipe-to-delete or long-press available in FavouritesView.
- Image (from `MediaCache`; placeholder if unavailable).
- Taxonomy path (breadcrumb): Domain → … → Genus → **Species** (tappable).
- Traits section (collapsible): key-value grid.
- Synonyms & common names (grouped by language).
- References (collapsible): citation list with optional URL. **v1 behaviour:** URLs are displayed as text with a "Copy link" action only (no network access, no in-app browser). **Future (optional networking) milestone:** allow opening links in-app via `SafariServices.SFSafariViewController` on iOS or `NSWorkspace.open` on macOS when optional networking is explicitly enabled by the user.
- Action buttons: "Compare with…", "Find closest relatives".

### 11.5 Compare View (`CompareView`)

```
┌────────────────────────────────────────────────────────┐
│  [Species A picker]     ←→     [Species B picker]      │
├────────────────────────────────────────────────────────┤
│  Common ancestor: [LCA taxon name, rank]               │
│  Distance: N ranks apart                               │
│  Path A → LCA: A > Genus > Family > Order > LCA        │
│  Path B → LCA: B > Genus > Family > Order > LCA        │
│  Shared clade: "Both are in order Carnivora"           │
│  Trait similarity: 72% (if available)                  │
├────────────────────────────────────────────────────────┤
│  Top-N Closest Relatives to Species A                  │
│  1. [Relative name] — distance 2, same genus           │
│  2. [Relative name] — distance 4, same family          │
│  …                                                     │
└────────────────────────────────────────────────────────┘
```

Species pickers use `SearchView` in a sheet. Results update when either species changes.

### 11.6 Favourites View (`FavouritesView`)

Accessible from the main tab bar / sidebar as a top-level destination.

```
┌────────────────────────────────────────────────────────┐
│  ♥ Favourites                         [Edit] [Share]   │
├────────────────────────────────────────────────────────┤
│  [Species image]  Panthera leo                         │
│                   Lion · Species · LC                  │
├────────────────────────────────────────────────────────┤
│  [Species image]  Quercus robur                        │
│                   English Oak · Species · LC           │
│  …                                                     │
├────────────────────────────────────────────────────────┤
│  12 species  ·  Sorted: Most recently added ▾          │
└────────────────────────────────────────────────────────┘
```

- **Sort options:** Most recently added (default), A–Z by scientific name, A–Z by common name.
- **Swipe to delete** (iOS) / right-click → Remove (macOS): removes individual favourite immediately. No confirmation needed (the action is easily reversible by re-favouriting).
- **Edit mode:** Multi-select delete.
- **Share:** Exports a plain-text list of species names (no taxon IDs, no timestamps). Uses `UIActivityViewController` / `NSSharingServicePicker`. User controls destination.
- **Empty state:** Friendly illustration + "Tap ♥ on any species to save it here."

### 11.7 Settings (`SettingsView`)

```
Settings
  ├── About
  │     Version, build, dataset version, license
  ├── Data & Privacy
  │     "We collect no data." (plain language summary)
  │     Data sources: bundled DB version + reference DB version (if active)
  ├── Favourites
  │     Favourites count: N species saved
  │     [Export Favourites…]   (share sheet; exports names only, no IDs/timestamps)
  │     [Clear All Favourites] (destructive; confirmation required)
  ├── Database
  │     Active database (bundled / reference)
  │     [Import Reference Database…]
  │     [Delete Reference Database] (destructive, requires confirmation)
  ├── Storage
  │     Bundled DB: X MB (not deletable)
  │     Reference DB: X MB (deletable)
  │     Favourites DB: X KB (deletable via Clear All above)
  │     Media packs: list with delete buttons
  │     [Export Diagnostics] (debug builds only or always-visible in Settings)
  └── Developer  (Debug builds only)
        [Open Log Viewer]
        [Reset All Settings]
```

---

## 12. CompareService & Top-N Algorithm

### 12.1 Taxonomic Distance via LCA

**Definition:** Given two taxa A and B, let LCA(A,B) be their lowest common ancestor. Let depth(x) = number of edges from root to x.

```
distance(A, B) = (depth(A) − depth(LCA)) + (depth(B) − depth(LCA))
               = depth(A) + depth(B) − 2 × depth(LCA)
```

**In-memory LCA with Euler Tour + Sparse Table (RMQ):**

1. **Euler tour:** Perform a DFS of the taxonomy tree; record each node when first entered and when returning from a child. Length of tour = 2N − 1 nodes.
2. **Depth array:** Record depth of each node in the tour position.
3. **Sparse table:** Precompute `st[i][j]` = position in tour with minimum depth in range `[i, i + 2^j − 1]`. Build in O(N log N), query in O(1).
4. **LCA query:** `LCA(u, v)` → look up `first[u]`, `first[v]`, query sparse table for min-depth position in that range, return the node at that position.
5. **Distance query:** O(1) after O(N log N) build.

**Memory estimate:** For 500 k taxa, the tour has ~1 M entries. A logical payload of `Int64 nodeID + Int32 depth` is ≥ 12 bytes and will typically be padded to 16 bytes per entry in Swift, plus `Array`/sparse-table overhead. Conservatively budgeting ~20–30 MB of RAM for the Euler tour + depth + sparse table is reasonable on devices with ≥ 2 GB RAM. For trees > 1 M nodes (or on lower-memory devices), use the on-demand path-to-root approach (O(depth) per query, typically ≤ 20 hops).

**On-demand fallback (no precomputed tour):**

```
// ancestors(of:) returns the path from root up to (but not including) the taxon itself.
ancestorsA ← ancestors(of: a)   // root → parent(a)
ancestorsB ← ancestors(of: b)   // root → parent(b)

ancestorIDsA ← Set of IDs in ancestorsA
ancestorIDsB ← Set of IDs in ancestorsB

// If one taxon is a direct ancestor of the other, that taxon IS the LCA.
if ancestorIDsB contains a  → return taxon(a)
if ancestorIDsA contains b  → return taxon(b)

// Otherwise walk ancestorsA from deepest to root, returning the
// first node whose ID appears in ancestorIDsB.
for ancestor in ancestorsA (reversed, deepest first):
    if ancestorIDsB contains ancestor.id → return ancestor

throw CompareError.noCommonAncestor   // should be unreachable in a well-formed tree
```

### 12.2 Trait-Based Similarity (Optional)

When the `traits` table is populated, compute **Jaccard similarity** over trait key-value pairs:

```
similarity(A, B) = |traits(A) ∩ traits(B)| / |traits(A) ∪ traits(B)|
```

Trait sets are built as `Set<String>` where each element is `"key=value"`. This is O(T) where T is the number of traits per taxon (typically small, < 50).

### 12.3 Top-N Closest Relatives: Precomputed Strategy

**Goal:** Answer "what are the 10 closest species to *Panthera leo*?" in < 10 ms.

**Offline pipeline (runs at DB build time, not on device):**

```
For each species-rank leaf taxon L:
    1. Identify the species in the same genus (distance = 2).
    2. If |same genus| < N: extend to same family (distance = 4), same order (= 6), etc.
    3. Sort candidates by distance, break ties by scientific name.
    4. Store top N rows in top_n_relatives(taxon_id, relative_id, rank_order, lca_id, lca_depth, distance).
```

Complexity per taxon: O(siblings at each rank level), total O(S × N) where S is number of species. For 500 k species with N=10 this is ~5 M rows in `top_n_relatives` (~200 MB at ~40 bytes/row — acceptable; can be reduced to top-5 for 100 MB).

**On-device query:**

```swift
// O(1) — single indexed lookup
SELECT r.*, t.scientific_name, t.rank
  FROM top_n_relatives r
  JOIN taxa t ON t.id = r.relative_id
 WHERE r.taxon_id = ?
 ORDER BY r.rank_order
 LIMIT ?
```

**Runtime fallback (`TopNSource.computed`):**

Used when `top_n_relatives` table is absent or for species not in the precomputed set:

```
BFS from target species outward through the taxonomy tree:
    Level 1: siblings in same genus
    Level 2: cousins in same family
    …
    Until N candidates accumulated.
    Sort by distance, return top N.
```

Complexity: O(B^d) where B is branching factor and d is depth needed. In practice O(hundreds) for typical genera.

### 12.4 Distance Metric Configuration

```swift
public struct CompareConfig: Sendable {
    public var topN: Int = 10                   // configurable, 1…100
    public var includeTraitSimilarity: Bool = true
    public var topNSource: TopNSource = .precomputed
    public var maxRuntimeCandidates: Int = 5000  // guard for computed mode
}
```

---

## 13. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Dataset too large for app bundle (> 50 MB) | Medium | High | Use compressed SQLite (zstd page compression or gzip); target < 20 MB for bundled DB. Offer full DB as optional reference download. |
| DB migration breaks existing installs | Low | High | Schema versioning table; app refuses to open incompatible DB version gracefully. Never auto-migrate bundled DB. |
| Corrupt reference DB import | Medium | Medium | Atomic import with SHA-256 + signature check; full rollback on failure. |
| App Store privacy disclosure issues | Low | High | "No Data Collected" is fully defensible given our architecture. Document precisely. |
| LCA precomputation OOM on large trees | Low | Medium | Use on-demand LCA fallback for trees > 1 M nodes; document threshold. |
| Child safety (content) | Low | Medium | No user-generated content. All content is from trusted taxonomy databases (GBIF, ITIS). Content review at pipeline stage. |
| Licensing of species data | Medium | High | Use CC0 or CC BY datasets (GBIF, Open Tree of Life). Document all data licenses in Settings → About → Data Sources. |
| FTS5 index rebuild time on large DB | Low | Low | FTS index pre-built in offline pipeline; no rebuild on device. |
| macOS notarization / hardened runtime | Low | Medium | SQLite file access requires no special entitlements when within app sandbox. Use app sandbox for both platforms. |
| Favourites DB corruption on unexpected termination | Low | Low | GRDB uses WAL mode + SQLite's built-in rollback journal; uncommitted writes are never visible. On next launch, integrity_check is run and the file is re-created empty if corrupt (favourites are user-restorable by re-tapping). |
| Favourites misidentified as behavioural tracking | Low | Medium | Documented clearly in §4.6 and Settings → Data & Privacy. The data is opaque IDs only, never transmitted, and fully user-deletable. App Store label remains "No Data Collected". |

---

## 14. Milestone Plan

### v0 — Prototype (4–6 weeks)

- [ ] Repo setup: Swift Package structure, CI skeleton.
- [ ] Small bundled dataset (1 000 species, 5 ranks) as SQLite.
- [ ] Tree browser: browse → children (no media).
- [ ] Basic search (FTS5, scientific name only).
- [ ] Species detail (text only, no images).
- [ ] Runs on iOS Simulator and macOS.
- [ ] Zero permissions requested.

### v1 — MVP (8–12 weeks)

- [ ] Full bundled DB (GBIF backbone or ITIS subset, ~500 k taxa).
- [ ] Complete tree browser with all ranks.
- [ ] Full search: common names, synonyms, rank filter, autocomplete.
- [ ] Species detail with bundled images (asset catalog or bundle).
- [ ] **Favourites**: heart button on Species Detail; FavouritesView tab; sort + share + clear-all.
- [ ] **Favourites privacy**: favourites stored in dedicated local SQLite; documented in Settings → Data & Privacy.
- [ ] Privacy settings screen (data practices explanation).
- [ ] Storage management screen (includes favourites storage size + clear action).
- [ ] Unit tests: taxonomy store, search, favourites (add/remove/toggle/clear/export).
- [ ] Performance tests passing: cold start < 2 s, search < 100 ms.
- [ ] App Store ready: privacy label, no permissions.

### v1.1 — Reference DB + Diagnostics (4–6 weeks)

- [ ] Reference DB import flow (document picker, validation, rollback).
- [ ] DB switching UI and safe delete.
- [ ] Optional media packs (download + delete).
- [ ] In-app diagnostics export.
- [ ] Unit tests: import validation (all error cases), DB switching.

### v2 — Compare + Top-N (6–8 weeks)

**Justification for v2 vs v1.1:** The `top_n_relatives` precomputed table adds ~100–200 MB to the DB. This requires the full data pipeline to be mature (v1/v1.1) before committing to the table size. The LCA runtime code can land in v1.1 as a hidden feature for testing, promoted to v2 UI.

- [ ] CompareService: LCA distance, path display, clade description.
- [ ] Compare UI: two-species picker, result card, top-N list.
- [ ] Top-N precomputed table in full bundled DB.
- [ ] Trait similarity (if trait data available).
- [ ] "Find closest relatives" button on Species Detail.
- [ ] Unit + performance tests: compare latency < 50 ms, top-N < 10 ms.

---

## 15. Repo & Swift Package Layout

### 15.1 Folder Structure

```
SpeciesTreeOfLife-/            ← repository root (trailing hyphen is the repo name)
├── README.md
├── LICENSE
├── .gitignore
├── docs/
│   └── design/
│       └── SpeciesTreeOfLife.md          ← this file
├── App/
│   ├── iOS/
│   │   ├── SpeciesTreeOfLife.xcodeproj   (or part of workspace)
│   │   ├── SpeciesApp.swift
│   │   ├── Info.plist
│   │   └── Assets.xcassets
│   └── macOS/
│       ├── SpeciesTreeOfLife-macOS.xcodeproj
│       ├── SpeciesApp.swift
│       ├── Info.plist
│       └── Assets.xcassets
├── Packages/
│   ├── STOLData/                         ← DatabaseProvider, TaxonomyStore, models
│   │   ├── Package.swift
│   │   ├── Sources/STOLData/
│   │   └── Tests/STOLDataTests/
│   ├── STOLSearch/                       ← SearchService
│   │   ├── Package.swift
│   │   ├── Sources/STOLSearch/
│   │   └── Tests/STOLSearchTests/
│   ├── STOLCompare/                      ← CompareService, LCA, Top-N
│   │   ├── Package.swift
│   │   ├── Sources/STOLCompare/
│   │   └── Tests/STOLCompareTests/
│   ├── STOLMedia/                        ← MediaCache
│   │   ├── Package.swift
│   │   ├── Sources/STOLMedia/
│   │   └── Tests/STOLMediaTests/
│   ├── STOLImport/                       ← ImportService, validation
│   │   ├── Package.swift
│   │   ├── Sources/STOLImport/
│   │   └── Tests/STOLImportTests/
│   ├── STOLFavorites/                    ← FavoritesService, local SQLite (no PII)
│   │   ├── Package.swift
│   │   ├── Sources/STOLFavorites/
│   │   └── Tests/STOLFavoritesTests/
│   └── STOLSharedUI/                     ← SwiftUI views
│       ├── Package.swift
│       ├── Sources/STOLSharedUI/
│       └── Tests/STOLSharedUITests/
├── Pipeline/                             ← Offline DB build scripts (Python/Swift)
│   ├── build_db.py
│   ├── compute_top_n.py
│   └── sign_db.py
└── .github/
    └── workflows/
        ├── build-ios.yml
        └── build-macos.yml
```

### 15.2 Package Dependency Graph

```
STOLSharedUI  ──────► STOLData
                  └──► STOLSearch
                  └──► STOLCompare
                  └──► STOLMedia
                  └──► STOLFavorites

STOLSearch   ──────► STOLData
STOLCompare  ──────► STOLData
STOLImport   ──────► STOLData
STOLFavorites ─────► STOLData (for TaxonID type only; owns its own favorites.sqlite)
STOLMedia    ──────► STOLData (for TaxonID type)

External deps (STOLData only):
  GRDB.swift (SQLite wrapper, MIT license, no network, no PII risk)
  CryptoKit  (Apple system framework, for Ed25519 signature verification)
```

### 15.3 Build Settings (Key Items)

| Setting | iOS Target | macOS Target |
|---|---|---|
| `ENABLE_APP_SANDBOX` | YES (default) | YES |
| `com.apple.security.network.client` | *n/a — iOS sandbox handles this differently* | **absent** |
| `com.apple.security.network.server` | *n/a* | **absent** |
| `SWIFT_STRICT_CONCURRENCY` | `complete` | `complete` |
| `SWIFT_VERSION` | 6.0 | 6.0 |
| Deployment target | iOS 17+ | macOS 14+ |
| `DEBUG_INFORMATION_FORMAT` | `dwarf-with-dsym` | `dwarf-with-dsym` |

For v1, **no macOS network sandbox entitlements** (`com.apple.security.network.client`, `com.apple.security.network.server`) are requested. They are added only when the optional reference DB download feature is implemented (v1.1+), behind a compile-time feature flag. On iOS, networking behaviour is governed by App Transport Security settings and the absence of networking code paths — there is no user-granted network permission to request.

### 15.4 Package Implementation Responsibilities

Each Swift Package has a clearly bounded set of responsibilities. Implementation details are deferred to the coding phase; this section describes the contract each package must satisfy.

**`STOLData`**

- Owns the `DatabaseActor`: a Swift actor that serialises all SQLite access and holds two optional connection references (bundled read-only; reference read-only). All other packages access data exclusively through this actor.
- Owns all shared model types (`Taxon`, `TaxonRank`, `TaxonID`, `TaxonName`, `Trait`, `TaxonReference`, `FavouriteEntry`, etc.).
- Owns the `DatabaseProvider`, `TaxonomyStore`, and `ImportService` protocols.
- Manages schema-version checking; refuses to open a DB whose schema version is ahead of what the current build understands.
- Must compile on both iOS and macOS with Swift strict concurrency enabled.

**`STOLSearch`**

- Owns `SearchService` protocol and its implementation.
- Drives FTS5 queries through the `DatabaseActor` injected at construction time.
- No direct SQLite file access; all DB work goes through `STOLData`.

**`STOLCompare`**

- Owns `CompareService`, `LCAEngine`, and `CompareConfig`.
- `LCAEngine` builds an in-memory Euler-tour + sparse-table structure at startup (see §12.1). It receives the full taxon tree via `TaxonomyStore.children` traversal.
- For trees too large to fit in memory, falls back to on-demand path-to-root LCA (see §12.1 on-demand fallback pseudocode for the required ancestor-of-ancestor handling).
- All DB reads go through `DatabaseActor`.

**`STOLMedia`**

- Owns `MediaCache` protocol and `MediaCacheActor`.
- Serves images from the app bundle or optional installed media packs in Application Support.
- Exposes storage-size reporting and per-pack deletion for use by `SettingsView`.

**`STOLImport`**

- Owns `ImportService` and the atomic-import flow (copy → SHA-256 → Ed25519 → decompress → schema check → integrity check → atomic rename).
- Exposes an `AsyncStream<ImportProgress>` for progress reporting to the UI.
- On any validation failure: cleans up all temp files and throws a typed `ImportError`; never touches the active DB.

**`STOLFavorites`**

- Owns `FavoritesService` protocol and its actor-based implementation.
- Maintains its own `favorites.sqlite` in `<Application Support>/Favorites/` — entirely separate from taxonomy DBs.
- Keeps an in-memory `Set<TaxonID>` cache warm for O(1) `isFavourite` checks.
- All mutations (add, remove, clear) update both the cache and the DB atomically.
- Uses fractional-second ISO-8601 timestamps (`strftime('%Y-%m-%dT%H:%M:%fZ','now')`) to guarantee stable "most recently added" ordering even when multiple favourites are added in rapid succession.
- See `docs/design/Favorites.md` for the full feature spec.

**`STOLSharedUI`**

- Owns all SwiftUI views listed in §11. Imports only the protocol types from other packages (never concrete implementations).
- Uses `#if os(iOS)` / `#if os(macOS)` for the small number of platform-specific idioms (navigation column count, share-sheet APIs, window management).
- Never instantiates service implementations directly; receives them via the DI container at app startup.

---

## Appendix A: Data Licenses

The following open datasets are candidates for the bundled species database:

| Dataset | License | URL |
|---|---|---|
| GBIF Backbone Taxonomy | CC0 1.0 | https://www.gbif.org/dataset/d7dddbf4-2cf0-4f39-9b2a-bb099caae36c |
| Open Tree of Life (OTL) | CC0 1.0 | https://opentreeoflife.github.io/ |
| Integrated Taxonomic Information System (ITIS) | Public Domain | https://www.itis.gov/ |
| Catalogue of Life | CC BY 4.0 | https://www.catalogueoflife.org/ |

**Attribution requirements:** CC BY 4.0 data (Catalogue of Life) requires attribution in the app's About/Data Sources screen. CC0 and Public Domain data has no attribution requirement but we will credit sources as a matter of good practice.

---

## Appendix B: Glossary

| Term | Definition |
|---|---|
| LCA | Lowest Common Ancestor — the deepest node in the taxonomy tree that is an ancestor of both taxa. |
| FTS5 | Full-Text Search version 5 — SQLite's built-in full-text search extension. |
| RMQ | Range Minimum Query — algorithm for answering "what is the minimum value in a subarray?" in O(1) after O(N log N) preprocessing. Used for fast LCA computation. |
| Euler Tour | A traversal of a tree where each node is visited each time we enter or return from a subtree. Length = 2N − 1 nodes. Enables reduction of LCA to RMQ. |
| Taxon | A group of organisms classified at any rank (domain through species). |
| PII | Personally Identifiable Information. |
| STOL | Short for "Species Tree of Life" — used as Swift package name prefix. |
| Bundled DB | The SQLite database shipped inside the app bundle; always present; never modified. |
| Reference DB | An optional secondary SQLite database imported by the user; can be enabled/disabled/deleted. |
| Favourites DB | A small local SQLite file (`favorites.sqlite`) that stores only opaque taxon IDs and timestamps. No PII. Never transmitted. |
