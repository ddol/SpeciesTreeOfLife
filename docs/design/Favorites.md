# Species: Tree of Life — Favourites Feature Spec

**Status:** Draft v0.1  
**Date:** 2026-02-26  
**Audience:** iOS/macOS engineers, product, App Store review  

**See also:**
- [Architecture](SpeciesTreeOfLife.md) — module layout, `FavoritesService` protocol definition
- [Data Loading Spec](DataLoading.md) — taxonomy DB files, bundled vs. reference DB
- [Visual Design](VisualDesign.md) — heart icon animation, FavouritesView composition

---

## Table of Contents

1. [Feature Summary](#1-feature-summary)
2. [Privacy Analysis](#2-privacy-analysis)
3. [Storage Design](#3-storage-design)
4. [Schema](#4-schema)
5. [Service API Spec](#5-service-api-spec)
6. [UI Specification](#6-ui-specification)
7. [Data Lifecycle](#7-data-lifecycle)
8. [Risks & Mitigations](#8-risks--mitigations)
9. [Test Scenarios](#9-test-scenarios)
10. [Implementation Guidance](#10-implementation-guidance)

---

## 1. Feature Summary

Users can mark any species as a **favourite** by tapping a heart icon on the species detail screen. Favourites are collected in a dedicated **FavouritesView** tab. The list can be sorted, shared (species names only), and cleared.

### Goals

- One-tap save/unsave from any species detail screen.
- Persistent across app restarts and device reboots.
- Survives taxonomy DB switching (bundled ↔ reference DB).
- Works entirely offline; no account, no sync, no network.
- Fully user-deletable; no hidden data residue after "Clear All".

### Non-Goals

- Cross-device sync (iCloud Drive, CloudKit).
- Sharing favourites with other users.
- Categorising or organising favourites into folders.
- Recommendation or "similar to your favourites" features (out of scope for v1).

---

## 2. Privacy Analysis

### 2.1 What is Stored

| Field | Type | Description |
|---|---|---|
| `taxon_id` | `INTEGER` | Opaque integer key from the species database (e.g., `12345` = *Panthera leo*) |
| `created_at` | `TEXT` | ISO-8601 UTC timestamp with fractional seconds (e.g., `2026-02-26T10:15:30.123Z`) |

That is the complete data model. Nothing else is recorded.

### 2.2 Is Any of This PII?

**`taxon_id`:** No. It is a species database key — a number that identifies a biological taxon, not a person. It cannot be linked to an individual user without additional information that the app never collects.

**`created_at`:** No, in isolation. A sequence of timestamps with no associated user identifier cannot identify a natural person. The data never leaves the device.

**Combination:** Even in combination, `(taxon_id, created_at)` tuples describe "a species was saved at a time" — not "a named person saved a species at a time." There is no device ID, session ID, or any linking field.

### 2.3 Privacy Invariants

| Invariant | Enforcement |
|---|---|
| No PII stored | Schema has exactly two columns; enforced by unit test that introspects `PRAGMA table_info(favorites)` |
| Data stays on device | `FavoritesService` has no network methods; no URLSession call anywhere in `STOLFavorites` |
| No iCloud Drive / CloudKit sync | `favorites.sqlite` is **not** enrolled in iCloud Drive or CloudKit; standard OS backup is permitted (encrypted, user-owned) |
| User can delete all data | `clearAllFavourites()` removes every row; `storageBytes()` returns 0 after clear |
| Export contains names only | The "Export Favourites" action resolves `taxon_id` → display name before exporting; the exported text contains no IDs, no timestamps |

### 2.4 App Store Privacy Label

No change to the "No Data Collected" declaration. Favourites data:
- Never transmitted off device.
- Not linked to a user identity.
- Fully user-deletable.
- Not used for tracking, profiling, or advertising.

---

## 3. Storage Design

### 3.1 File Location

```
<Application Support>/Favorites/favorites.sqlite
```

The `Favorites/` subdirectory is created by `FavoritesServiceImpl` on first use. The `favorites.sqlite` file is created with `SQLite OPEN_READWRITE | OPEN_CREATE` flags.

### 3.2 Why a Separate File?

Favourites are stored in a **separate SQLite file**, not in the taxonomy DB. Reasons:

1. **Independence from DB switching.** When the user switches between the bundled and reference taxonomy DBs, their favourites are unaffected. The same `taxon_id` values are valid across both taxonomy DBs (they reference the same stable biological IDs).
2. **Write isolation.** The taxonomy DBs are opened read-only. A separate file avoids any risk of accidental writes to the taxonomy data.
3. **Targeted deletion.** The user can delete favourites without affecting any taxonomy data, and vice versa.

### 3.3 Backup Behaviour

| Mechanism | Behaviour |
|---|---|
| Standard iOS/macOS backup (encrypted) | **Allowed.** The file is backed up automatically. This is the user's own encrypted backup; no data reaches our servers. |
| iCloud Drive | **Excluded.** The `Favorites/` directory is not enrolled in iCloud Drive. |
| CloudKit | **Not implemented.** No CloudKit container is defined for this data. |
| `NSURLIsExcludedFromBackupKey` | **Not set.** We allow the standard OS backup so users can restore their favourites when moving to a new device. |

---

## 4. Schema

```sql
-- favorites.sqlite
-- Privacy: only opaque taxon IDs and creation timestamps.
-- No user identifiers, no device IDs, no PII of any kind.

CREATE TABLE favorites (
    taxon_id    INTEGER PRIMARY KEY,
    created_at  TEXT NOT NULL
        -- Fractional seconds guarantee stable ordering when multiple
        -- favourites are added in rapid succession (sub-second).
        DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

-- Enables ORDER BY created_at DESC for "most recently added" sort.
CREATE INDEX idx_favorites_created ON favorites(created_at DESC);
```

### Schema Version

`favorites.sqlite` does not use a `schema_version` table (the schema is intentionally minimal and unlikely to change). If a migration is ever needed, `FavoritesServiceImpl` should add a `user_version` PRAGMA:

```
PRAGMA user_version = 1;   -- increment on each schema change
```

The implementation checks `PRAGMA user_version` on open and runs any needed migrations before use.

---

## 5. Service API Spec

The `FavoritesService` protocol is defined in `STOLData` so all packages can reference `FavouriteEntry` without depending on `STOLFavorites`.

### 5.1 `FavouriteEntry`

```
FavouriteEntry
  id: TaxonID       -- same as taxon_id; used by SwiftUI List for diffing
  taxonID: TaxonID  -- opaque species key
  createdAt: Date   -- when this species was favourited; for ordering only
```

No display fields (name, rank, image) are stored in `FavouriteEntry`. Views resolve the display information by passing `taxonID` to `TaxonomyStore`.

### 5.2 `FavoritesService` Protocol Surface

| Method | Description | Throws? | Async? |
|---|---|---|---|
| `isFavourite(taxonID:)` | O(1) check using in-memory cache. Returns `Bool`. | No | No |
| `addFavourite(taxonID:)` | Inserts row if absent. No-op if already favourited. | Yes | Yes |
| `removeFavourite(taxonID:)` | Deletes row if present. No-op if absent. | Yes | Yes |
| `toggleFavourite(taxonID:)` | Adds if absent, removes if present. Returns new state (`true` = now favourited). | Yes | Yes |
| `allFavourites()` | Returns all entries ordered by `created_at DESC`. | Yes | Yes |
| `favouritesCount()` | O(1) from in-memory cache. | No | No |
| `clearAllFavourites()` | `DELETE FROM favorites`. Clears cache. | Yes | Yes |
| `storageBytes()` | `PRAGMA page_count * PRAGMA page_size`. | Yes | Yes |

### 5.3 In-Memory Cache

`FavoritesServiceImpl` maintains a `Set<TaxonID>` cache warmed from the DB on first init. This makes `isFavourite` and `favouritesCount` synchronous and free of disk I/O — important for rendering heart icons in list cells without blocking the main thread.

All mutations update both the DB and the cache atomically (within the actor's serialised context). If the app is force-quit after a DB write but before the cache update, the cache is re-warmed from the DB on the next launch.

### 5.4 Ordering

`allFavourites()` always returns rows `ORDER BY created_at DESC` — most recently added first. The fractional-second timestamp format (`%f`) ensures stable ordering even when multiple species are added in rapid succession (< 1 second apart).

---

## 6. UI Specification

### 6.1 Favourite Button (Species Detail Screen)

- **Location:** Top-right of the species detail header, inline with the species name.
- **Icon:** SF Symbol `heart` (outline = not favourited) / `heart.fill` (filled = favourited).
- **Colour:** `accentCoralRed` (#E8553A) when filled; `accentPebbleGrey` (#8A8A8A) when outline.
- **Interaction:** Single tap toggles. No confirmation required for add (it is easily reversible). No confirmation required for individual remove from the detail screen.
- **Animation:** On add — heart scales to 1.3× then springs back to 1.0; 3–5 small dot particles radiate outward and fade (300 ms spring). On remove — heart scales down to 0.9× then back to 1.0; colour drains (200 ms ease-out). See [VisualDesign.md §7.2](VisualDesign.md#72-transition-vocabulary).
- **Accessibility:** `.accessibilityLabel` = `"Add to favourites"` / `"Remove from favourites"`. `.accessibilityTrait(.button)`.

### 6.2 Favourites Tab / Sidebar Item

- **Icon:** SF Symbol `heart` (outline) when count = 0; `heart.fill` when count > 0.
- **Label:** "Favourites" (iOS tab bar / macOS sidebar).
- **Badge:** None. Count is shown inside the view header.

### 6.3 FavouritesView

```
┌────────────────────────────────────────────────────────────┐
│  ♥ Favourites                      [Sort ▾]  [Edit]  [⬆]  │
│  12 species                                                 │
├────────────────────────────────────────────────────────────┤
│  [40×40 img]  Panthera leo                                 │
│               Lion  ·  [Species ●]  ·  [EN ●]             │
├────────────────────────────────────────────────────────────┤
│  [40×40 img]  Quercus robur                                │
│               English Oak  ·  [Species ●]  ·  [LC ●]      │
│  …                                                         │
└────────────────────────────────────────────────────────────┘
```

**Sort options (Sort ▾ picker):**
- Most recently added (default)
- A–Z by scientific name
- A–Z by common name

**Share button (⬆):**
- Exports a plain-text list of species display names (no taxon IDs, no timestamps).
- Presented via `UIActivityViewController` (iOS) / `NSSharingServicePicker` (macOS).
- Example export content:

  ```
  My Favourite Species — Species: Tree of Life

  1. Panthera leo (Lion)
  2. Quercus robur (English Oak)
  …
  ```

**Edit mode:**
- Activated by tapping "Edit".
- Each row gains a leading delete button (red circle minus icon).
- "Select All" and "Delete Selected" buttons appear in the toolbar.
- On iOS, standard swipe-to-delete is also available outside of Edit mode.

**Empty state:**
- Illustrated empty state: a single soft-outlined heart form on the deep-canopy gradient.
- Text: "Tap ♥ on any species to save it here."
- No action buttons.

**Tapping a row:** Navigates to `SpeciesDetailView` for that taxon.

### 6.4 Settings — Favourites Group

```
Settings → Favourites
  ├── Favourites count: "12 species saved"
  ├── [Export Favourites…]         → share sheet (names only, no IDs/timestamps)
  └── [Clear All Favourites]       → confirmation sheet → clearAllFavourites()
```

**Clear All confirmation sheet:**
- Title: "Clear all favourites?"
- Message: "This will remove all 12 saved species. This cannot be undone."
- Destructive button: "Clear All"
- Cancel button: "Cancel"

### 6.5 Settings — Storage Group

The Storage section shows favourites storage separately:

```
Settings → Storage
  ├── Bundled Database:   18 MB    (not deletable)
  ├── Reference Database: 24 MB    (deletable)
  ├── Favourites:          < 1 MB  (managed via Settings → Favourites → Clear All)
  └── Media Packs:        [list with individual delete buttons]
```

---

## 7. Data Lifecycle

### 7.1 First Launch

On first launch, `FavoritesServiceImpl.init(appSupportURL:)` creates the `Favorites/` directory and `favorites.sqlite`, runs the schema migration (idempotent `CREATE TABLE IF NOT EXISTS`), and warms the in-memory cache (empty Set on first launch).

### 7.2 Normal Use

```
User taps heart on Species Detail
    → FavoritesService.toggleFavourite(taxonID: id)
        [actor-serialised]
        ├─ UPDATE cache
        ├─ INSERT OR DELETE row in favorites.sqlite
        └─ Return new Bool state
    → SpeciesDetailView updates heart icon
    → FavouritesView (if visible) refreshes its list
```

### 7.3 App Restart

On next launch, `FavoritesServiceImpl.init` reads all `taxon_id` values from the DB and populates the in-memory cache. Cold-start time impact: negligible (< 1 ms for < 10 000 rows).

### 7.4 Taxonomy DB Switch

When the active taxonomy DB switches (bundled ↔ reference):

- `favorites.sqlite` is **unchanged**.
- `taxon_id` values in `favorites.sqlite` reference the same stable biological IDs present in both DBs.
- `FavouritesView` refreshes display names from the newly active `TaxonomyStore`.
- If a favourited `taxon_id` does not exist in the newly active DB (edge case if datasets differ significantly), the species row shows a "Not found in active database" placeholder. The favourite record is **not deleted** — the user can switch back and it reappears.

### 7.5 Clear All

```
User confirms "Clear All Favourites"
    → FavoritesService.clearAllFavourites()
        [actor-serialised]
        ├─ DELETE FROM favorites (all rows)
        └─ cachedIDs.removeAll()
    → FavouritesView shows empty state immediately
```

After clear, `storageBytes()` returns the SQLite file overhead (~4–8 KB for the empty file). The file itself is not deleted; only the rows are removed. This avoids a brief window where the file is absent and a concurrent read would fail.

---

## 8. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| `favorites.sqlite` corruption on force-quit mid-write | Low | Low | SQLite WAL mode + rollback journal prevents half-written transactions from being visible. On next launch, the DB is either in the pre-write or post-write state; never partially written. Run `PRAGMA integrity_check` on open; if it fails, recreate an empty DB (user can re-add favourites). |
| `taxon_id` not found in active taxonomy DB after DB switch | Low | Low | Show "Not available in active database" placeholder row. Preserve the favourite record — do not auto-delete. |
| Multiple rapid favourites with identical timestamps | Low | Low | Using fractional-second timestamps (`%f` = milliseconds) reduces collision likelihood to ~1 ms windows. For edge cases, add a secondary sort by `taxon_id ASC` as a deterministic tie-breaker. |
| App Store review concern: "is this tracking?" | Low | Medium | §2 Privacy Analysis is the exact evidence for the "No Data Collected" declaration. Settings → Data & Privacy shows a plain-language explanation. No behavioural analytics, no user identity linkage. |
| User accidentally clears all favourites | Low | Low | Confirmation sheet with count ("12 species"). No undo. Acceptable for v1; undo/recycle bin is a v2 consideration. |

---

## 9. Test Scenarios

These scenarios must be covered by unit tests in `STOLFavoritesTests`:

| # | Scenario | Expected result |
|---|---|---|
| T1 | Add a taxon ID | `isFavourite(id)` = true; `favouritesCount()` = 1 |
| T2 | Add same taxon ID twice | No error; count remains 1 |
| T3 | Remove a taxon ID | `isFavourite(id)` = false; count = 0 |
| T4 | Remove a taxon ID not in favourites | No error |
| T5 | Toggle adds when absent | Returns `true`; count increments |
| T6 | Toggle removes when present | Returns `false`; count decrements |
| T7 | `allFavourites()` ordering | IDs added in sequence A, B, C returned in order C, B, A |
| T8 | `allFavourites()` when empty | Returns empty array; no error |
| T9 | Clear all | Count = 0; `allFavourites()` returns empty |
| T10 | `storageBytes()` > 0 after insert | Returns positive integer |
| T11 | Schema PII invariant | `PRAGMA table_info(favorites)` returns exactly columns `taxon_id` and `created_at`; no other columns |
| T12 | Persistence across reinit | Add IDs; create new `FavoritesServiceImpl` with same URL; IDs still present |

---

## 10. Implementation Guidance

### Module

`STOLFavorites` Swift Package (`Packages/STOLFavorites/`).

**Dependencies:**
- `STOLData` — for `TaxonID` type alias and `FavouriteEntry` struct.
- `GRDB.swift` (≥ 6.0, MIT licence) — SQLite wrapper; no network, no PII risk.

### Key Design Decisions

1. **`FavoritesServiceImpl` is a Swift `actor`** — serialises all DB mutations and cache updates. No locks or `DispatchQueue` needed.

2. **In-memory `Set<TaxonID>` cache** — warmed on init, updated on every mutation. Makes `isFavourite` and `favouritesCount` synchronous and allocation-free for SwiftUI rendering.

3. **WAL mode** — enable SQLite WAL journal mode (`PRAGMA journal_mode=WAL`) for better concurrent read performance and crash safety.

4. **Fractional-second timestamps** — use `strftime('%Y-%m-%dT%H:%M:%fZ','now')` for `created_at` to guarantee stable `ORDER BY created_at DESC` ordering even when multiple items are added sub-second.

5. **Schema introspection in tests** — unit tests must use `PRAGMA table_info(favorites)` to assert the column set is exactly `{taxon_id, created_at}`. This is the machine-readable privacy invariant that ensures no developer accidentally adds a PII-carrying column.

6. **Separate from taxonomy DBs** — `FavoritesServiceImpl` opens its own `DatabaseQueue` pointing to `favorites.sqlite`. It does not share a connection with `DatabaseActor`. This keeps the favourites write path entirely isolated from read-only taxonomy connections.

### Sequence Diagram: Toggle Favourite

```
SpeciesDetailView          FavoritesService        favorites.sqlite
       │                         │                        │
       │  toggleFavourite(id)    │                        │
       │────────────────────────►│                        │
       │                         │  isFavourite? (cache)  │
       │                         │  ─────────── No        │
       │                         │                        │
       │                         │  INSERT OR IGNORE      │
       │                         │───────────────────────►│
       │                         │  OK                    │
       │                         │◄───────────────────────│
       │                         │  cache.insert(id)      │
       │                         │  ──────────────        │
       │  returns true           │                        │
       │◄────────────────────────│                        │
       │                         │                        │
  [heart icon → filled]          │                        │
```
