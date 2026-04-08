# Vienna Sync: Upgrade vs. Backport Analysis

## Background

Vienna 3.0.0 introduced syncing with Google Reader and compatible services (OpenReader, TheOldReader, InoReader). This document analyzes whether it is better to upgrade the current Tiger-compatible 2.6.0 build to 3.0.0, or to backport the sync feature into 2.6.0.

---

## Scale of the 2.6.0 → 3.0.0 Change

- **2,413 commits**, **2,477 files changed**, **231K insertions / 158K deletions**

This is not a minor bump — it is a near-complete rewrite of the networking and article display layers.

---

## Option A: Upgrade to 3.0.0

### Architectural Changes

| Area | Change |
|---|---|
| **Networking** | `AsyncConnection.m` (the existing curl wrapper) deleted. Replaced with `ASIHTTPRequest` — a large 3rd-party library (~6K lines) that explicitly states it **requires 10.5+** |
| **Database** | Custom `SQLDatabase`/`SQLRow`/`SQLResult` layer deleted. Replaced with `FMDatabase` (~1,800 lines, uses `dispatch_sync` GCD blocks throughout) |
| **Article list UI** | `UnifiedDisplayView.m` completely rewritten (1,143 lines new vs. 299 old) using `PXListView`, a new custom cell-based list view component (~2,500 lines of new 3rd-party code) |
| **Sync logic** | New `GoogleReader.m` (1,005 lines) uses `dispatch_async`/`dispatch_queue` (GCD), blocks (`^{}`), `@property`, and `@synchronized` throughout |
| **Deployment target** | Xcode project explicitly targets **10.10** |

### Blockers for Tiger

1. **GCD (`dispatch_async`/`dispatch_sync`)** — used in 36+ call sites across the new core files. GCD does not exist on 10.4. Backporting this would require reimplementing it with NSThread/NSOperationQueue or finding a GCD compatibility shim — significant work.
2. **Blocks (`^{}`)** — 59 block literals in `src/`. Plausible Blocks can shim this, but adds another layer of complexity and build infrastructure.
3. **ASIHTTPRequest** — self-described as 10.5+ minimum. The project already has a working `libcurl`-based network stack; replacing it is pure overhead.
4. **FMDatabase** — wraps sqlite with GCD queues internally. Would require ripping it out and re-plugging in the old `SQLDatabase` layer or rewriting FMDatabase's threading model.
5. **Fast enumeration** — 85 new loops to convert to NSEnumerator (vs. 11 for 2.5.0 and 2 for 2.6.0).

### Assessment

Upgrading to 3.0.0 means fighting GCD, blocks, ASIHTTPRequest's OS minimum, and a new database layer — on top of all the usual fast-enumeration and API reverts. The surface area is 10–15× larger than the 2.5.0 or 2.6.0 upgrades. This path is very risky and may not be achievable without a GCD shim.

---

## Option B: Backport Sync to 2.6.0

### The Sync Feature Is Surprisingly Self-Contained

| File | Lines | Role |
|---|---|---|
| `GoogleReader.m` | 1,005 | Core sync engine — all Google/OpenReader API calls |
| `GoogleReader.h` | 45 | Interface |
| `SyncPreferences.m` | 265 | Preferences UI panel for sync settings |
| `SyncPreferences.h` | 26 | Interface |
| `SubscriptionModel.m` | 75 | Small helper for subscription operations |

**Total: ~1,400 lines of new code.**

Integration into existing files is also small and measurable:

| File | Additions | Nature |
|---|---|---|
| `RefreshManager.m` | ~27 lines | Calls into GoogleReader on refresh |
| `Database.m` | ~31 lines | New fields for `serverArticleID` tracking |
| `AppController.m` | ~51 lines | Menu items, sync state notifications |
| `Preferences.m` | ~48 lines | New sync preference keys and accessors |

### Blockers for a Backport

1. **GCD and blocks in `GoogleReader.m`** — async operations use `dispatch_async` and `^{}` blocks. These need to be replaced with NSThread/NSOperationQueue + delegate callbacks, following the same `AsyncConnection` pattern already in the codebase. Approximately 15–20 call sites.
2. **`@property`/`@synthesize`** in `GoogleReader.h` — straightforward to convert to manual getters and setters.
3. **ASIHTTPRequest networking** — HTTP calls in `GoogleReader.m` would need to be rewritten using the existing `AsyncConnection`/`libcurl` stack. The mapping is direct: same HTTP operations, different API.
4. **JSONKit** (~3K lines) — used to parse Google Reader API responses. JSONKit is MRC-compatible and should work on 10.4. Alternatively, since the API responses are straightforward JSON, a simpler parser could be substituted.

---

## Recommendation: Backport

The backport path is clearly better. Reasons:

- **Contained scope**: ~1,400 lines of new code vs. 231K+ lines of changes in the full upgrade
- **No database layer swap**: 2.6.0's `SQLDatabase` stays intact
- **No UI rewrite**: The article list view stays as-is
- **GCD surface is small and local**: Only `GoogleReader.m` uses GCD heavily — ~15–20 `dispatch_async` calls replaced with `NSThread`/delegate patterns using the `AsyncConnection` model already in the codebase
- **Networking is swappable**: The HTTP calls in `GoogleReader.m` map directly to `AsyncConnection` requests — same pattern, different API
- **JSONKit is MRC-compatible**: Drops in cleanly or can be substituted
- **Full control over the result**: Sync on Tiger without dragging in 10.10-targeted infrastructure

The main effort is rewriting `GoogleReader.m`'s async networking from ASIHTTPRequest+GCD to AsyncConnection+delegates. This is focused, well-scoped work on a single file with a clear existing pattern to follow.

---

## Source Version: v3.0.0

### Which version of GoogleReader.m to use

The file has three distinct eras:

| Tag | Date | Lines | Auth | MRC | GCD blocks | Status |
|---|---|---|---|---|---|---|
| `v/3.0.0_beta7` | Dec 2012 | 826 | GTMOAuth2 (Google) | ✓ | None in file | **Unusable** — targets dead Google Reader |
| `v/3.0.0` | Nov 2014 | 1,005 | Username/password (Open Reader) | ✓ | ~15–20 sites | **Use this** |
| `v/3.1.0+` | 2015+ | 1,066+ | Username/password | ✗ (ARC) | Heavy | **Unusable** — ARC requires 10.6+ |

**Use `v/3.0.0`**. It is the last MRC version, uses simple keychain-based auth compatible with all current Open Reader servers, and its GCD/ASI surface is exactly what the backport plan accounts for.

`v/3.1.0` introduced ARC (via Xcode's automatic conversion tool) and replaced JSONKit with `NSJSONSerialization` (10.7+ only) — both fatal for Tiger.

### Supported Sync Services (from `KnownSyncServers.plist`)

All use the same Google Reader API protocol with username/password auth:

| Service | Host |
|---|---|
| TheOldReader | `theoldreader.com` |
| BazQux | `www.bazqux.com` |
| FeedHQ | `feedhq.org` |
| InoReader | `www.inoreader.com` |
| Other (custom) | any self-hosted server (FreshRSS, Miniflux, etc.) |

---

## Backport Implementation Strategy

### The API Protocol

All communication uses HTTPS to `https://{server}/reader/api/0/`. Two tokens are required:

- **`clientAuthToken`** — obtained once via `POST /accounts/ClientLogin`. Sent as `Authorization: GoogleLogin auth={token}` header on every request.
- **`T` token** — a per-request CSRF token fetched from `GET /reader/api/0/token` before any write operation.

### Sync Flows

**Subscription sync** (fires once on connect):
```
GET /subscription/list
  → create missing folders/feeds in db
  → delete local feeds not on server
  → update homepage metadata for existing feeds
```

**Article sync** (fires per feed, 3 chained requests):
```
1. GET /stream/contents/feed/{url}?n=1000
     → db.createArticle() for each item
     → read/starred state from JSON "categories" array

2. GET /stream/items/ids?xt=.../read   (unread IDs)
     → db.markUnreadArticlesFromFolder:guidArray:

3. GET /stream/items/ids?it=.../starred  (starred IDs)
     → db.markStarredArticlesFromFolder:guidArray:
```

Requests 2 and 3 reconcile read/starred state against the server's authoritative list, which may cover older articles than the 1000-item content window in request 1.

**Write-back** (fire-and-forget, triggered by user actions):

| Action | Endpoint |
|---|---|
| Mark read/unread | `POST /edit-tag` with `a`/`r=user/-/state/com.google/read` |
| Star/unstar | `POST /edit-tag` with `a`/`r=user/-/state/com.google/starred` |
| Subscribe | `POST /subscription/quickadd` |
| Unsubscribe | `POST /subscription/edit ac=unsubscribe` |
| Move to folder | `POST /subscription/edit ac=edit a=user/-/label/{name}` |

### Porting Work (file by file)

#### `GoogleReader.m` (the main effort)

1. **Replace ASIHTTPRequest with AsyncConnection/AICURLConnection**
   - All `ASIHTTPRequest` GET requests → `AsyncConnection` delegate pattern (already used by `RefreshManager`)
   - All `ASIFormDataRequest` POST requests → `AICURLConnection` with manually constructed `application/x-www-form-urlencoded` body
   - Delegate callbacks map directly: `requestFinished:` → `connectionDidFinishLoading:`, `requestFailed:` → `connection:didFailWithError:`

2. **Remove GCD blocks (~15–20 sites)**
   - `dispatch_async(queue, ^{ ... })` wrappers around callback bodies → remove the wrapper, run inline (AsyncConnection already dispatches on the right thread via its delegate)
   - `dispatch_async(dispatch_get_main_queue(), ^{ ... })` for UI updates → `performSelectorOnMainThread:withObject:waitUntilDone:`

3. **Replace `doTransactionWithBlock:`**
   - `[db doTransactionWithBlock:^(BOOL *rollback) { ... }]` → `[db beginTransaction]; ...; [db commitTransaction];` (both exist in 2.6.0's `Database.m`)

4. **Convert fast enumeration**
   - `for (x in collection)` → `NSEnumerator` pattern (same as done for AppController.m, PluginManager.m, etc.)

5. **Convert `@property` (nonatomic, retain) to manual ivar + getter/setter**

#### New Database methods needed

These methods exist in v3.0.0's `Database.m` but not in 2.6.0's. They need to be added via the patch system:

| Method | What it does |
|---|---|
| `createArticle:folderId:article:guidHistory:` | Insert article with GUID dedup tracking |
| `markUnreadArticlesFromFolder:guidArray:` | Bulk reconcile read state from server list |
| `markStarredArticlesFromFolder:guidArray:` | Bulk reconcile starred state from server list |

#### Other files

| File | Work |
|---|---|
| `SyncPreferences.m/h` | Port as-is — it's a simple NSWindowController with no GCD/blocks |
| `KnownSyncServers.plist` | Copy directly into bundle resources |
| `RefreshManager.m` | Add ~27 lines to call `GoogleReader` singleton on refresh |
| `AppController.m` | Add menu items and sync notification handlers (~51 lines) |
| `Preferences.m/h` | Add sync preference keys (`syncGoogleReader`, `syncServer`, `syncingUser`) |
| `JSONKit.m/h` | Drop in as a new source file — MRC-compatible, works on 10.4 |
