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

### Implementation Status

#### ✅ Completed

**New files in `source/extra/`** (auto-copied into `build-meta/extra/` by `sync_meta.sh`, compiled as part of the flat build):

| File | Status | Notes |
|---|---|---|
| `GoogleReader.h` | Done | Tiger-compatible interface; `MA_GoogleReader_Folder`/`IsGoogleReaderFolder` in `Folder.h` |
| `GoogleReader.m` | Done | Full port — see details below |
| `JSONKit.h` | Done | Extracted from v3.0.0; no changes needed |
| `JSONKit.m` | Done | One fix: `@autoreleasepool` → `NSAutoreleasePool` for Tiger |

**Patches to existing Vienna files:**

| File | Status | Changes |
|---|---|---|
| `Folder.h` | Done | Added `MA_GoogleReader_Folder 7`, `IsGoogleReaderFolder(f)` macro |
| `Database.h` | Done | Added `addGoogleReaderFolder:`, `markUnreadArticlesFromFolder:guidArray:`, `markStarredArticlesFromFolder:guidArray:` |
| `Database.m` | Done | Implemented all three new methods; `MA_GoogleReader_Folder` handled same as `MA_RSS_Folder` in `addFolder:` |
| `Preferences.h/.m` | Done | Added `syncGoogleReader`, `syncServer`, `syncingUser` prefs backed by NSUserDefaults |
| `AppController.h/.m` | Done | Added `createNewGoogleReaderSubscription:underFolder:withTitle:afterChild:` |

**`GoogleReader.m` port — what changed from v3.0.0:**

1. **`GRRequest` replaces `ASIHTTPRequest`** — A thin context object (defined at the top of `GoogleReader.m`) that acts as its own `AICURLConnection` delegate. It accumulates response data, then calls back to `GoogleReader` via a stored `finishSelector`/`failSelector`. Exposes `responseData`, `responseStatusCode`, `userInfo`, `originalURL`, `error` — the same surface `ASIHTTPRequest` provided to callbacks.

2. **All async GETs** use `startGRRequest:withTarget:finishSelector:failSelector:userInfo:` — a private helper that builds an authenticated `NSMutableURLRequest`, creates an `AICURLConnection`, and starts it. Three chained requests fire per feed (content → unread IDs → starred IDs).

3. **All sync POSTs** (login, getToken, subscribeToFeed, unsubscribeFromFeed, setFolderName, markRead, markStarred) use `AICURLConnection sendSynchronousRequest:returningResponse:error:` with manually constructed `application/x-www-form-urlencoded` bodies.

4. **GCD removed** — All `dispatch_async(queue, ^{})` wrappers removed (callbacks run directly). `dispatch_async(dispatch_get_main_queue(), ^{})` for UI replaced with `performSelectorOnMainThread:@selector(notifyArticleCountUpdate)` which calls `setStatusMessage:nil persist:NO` and `showUnreadCountOnApplicationIconAndWindowTitle` on the main thread.

5. **`doTransactionWithBlock:` removed** → `beginTransaction`/`commitTransaction` pairs.

6. **Fast enumeration removed** → `NSEnumerator` throughout.

7. **`@property`/`@synthesize` removed** → manual ivars and getter/setter methods.

8. **`APPCONTROLLER` macro** → `(AppController *)[NSApp delegate]` (the pattern used throughout 2.6.0).

**Build result:** Compiles cleanly for both PPC and i386 slices.

#### 🔲 Not Yet Done

| File | Work remaining |
|---|---|
| `SyncPreferences.m/h` | Port the preferences UI panel (NSWindowController, no GCD) — needed for user to configure server/credentials |
| `KnownSyncServers.plist` | Copy into bundle resources so the UI can populate the server dropdown |
| `RefreshManager.m` | Wire `GoogleReader` into the refresh cycle — call `refreshFeed:withLog:shouldIgnoreArticleLimit:` for each GR folder during a refresh |
| `AppController.m` | Add sync menu items and notification handlers |
| `Folder.h` / `Database.m` | Ensure GR folders are loaded correctly on startup (type 7 round-trips through DB) |
| Integration testing | Deploy to imac-rsa and verify authentication + feed sync against a real Open Reader server (FreshRSS, TheOldReader, etc.) |
