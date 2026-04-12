# Vienna 3.0.8 Upgrade Plan

## Goal

Upgrade the legacy PPC/i386 build from Vienna 2.2.0 to Vienna 3.0.8 (commit `074a131a`) without
modifying `vienna/` source files. All sync logic (mark-read, mark-starred, subscribe/unsubscribe)
comes for free from 3.0.8 — no more manual backporting.

## vienna/ submodule

Already checked out to `074a131a1fb50b3ed9d50df88e1b69d2a19f423a` (3.0.8).

---

## Dependency Changes

### Removed (stays removed)
| Dep | Reason |
|---|---|
| Sparkle | Auto-update — not needed on legacy hardware |
| Growl | Notification framework — removed in 3.x too |
| DisclosableView | Replaced by BJRVerticallyCenteredTextFieldCell |
| AsyncConnection | Replaced by ASIHTTPRequest in 3.0.8 |
| SQLDatabase | Replaced by FMDB in 3.0.8 |

### Kept as-is
| Dep | Location | Notes |
|---|---|---|
| PSMTabBarControl | `deps/PSMTabBarControl/` | Special PPC-fixed checkout, compiled as .dylib |
| JSONKit | `deps/JSONKit/` | Compiled from source, statically linked |

### New deps to compile from source (all source already present)
| Dep | Source location | What it replaces |
|---|---|---|
| **ASICURLRequest** | `altivec/libs/ASICURLRequest/` | Drop-in replacement for ASIHTTPRequest using libcurl |
| FMDB | `vienna/Pods/FMDB/src/fmdb/` | Replaces SQLDatabase (thin ObjC SQLite wrapper, 6 files) |
| MASPreferences | `vienna/Pods/MASPreferences/` | Replaces SS_PrefsController (2 files + 1 xib) |
| PXListView | `vienna/Pods/PXListView/Classes/` | New component for UnifiedDisplayView (4 files) |

### 3rdparty source files to add to build
| File | Source | Notes |
|---|---|---|
| `BJRVerticallyCenteredTextFieldCell.m` | `vienna/3rdparty/BJRVerticallyCenteredTextFieldCell/` | Used in folder tree |
| `VTPG_Common.m` | `vienna/3rdparty/VTPG/` | Required by Debug.h |
| `DSClickableURLTextField.m` | `vienna/3rdparty/DSClickableURLTextField/` | Still used in 3.0.8 |

---

## The Hard Parts

### 1. ASICURLRequest (new library — main work)

3.0.8's `GoogleReader.m` and `RefreshManager.m` use ASIHTTPRequest throughout. Rather than
compiling the real ASIHTTPRequest (which brings in its own threading model and complexity), we
build a drop-in replacement called **ASICURLRequest** that implements the same API surface
using libcurl — the same libcurl already powering our build.

**Location**: `altivec/libs/ASICURLRequest/`

**Files** (named to match ASI's `#import` statements exactly):
- `ASIHTTPRequestConfig.h` — error code constants (`ASIAuthenticationErrorType`, etc.)
- `ASIHTTPRequestDelegate.h` — `@protocol ASIHTTPRequestDelegate` with optional methods
- `ASIHTTPRequest.h/.m` — main request class (Tiger-safe NSThread, no NSOperationQueue)
- `ASIFormDataRequest.h/.m` — subclass for `application/x-www-form-urlencoded` POST
- `ASINetworkQueue.h/.m` — concurrency queue (NSMutableArray + NSLock, no GCD)
- `Makefile-mac` — builds `libASICURLRequest.a` (fat PPC+i386)

**API surface required** (from grep of 3.0.8 source):

`ASIHTTPRequest`:
- `+requestWithURL:`
- `-addRequestHeader:value:`, `-requestHeaders`, `-setRequestHeaders:`
- `-setUseCookiePersistence:`, `-setTimeOutSeconds:`
- `-setDelegate:`, `-setDidFinishSelector:`, `-setDidFailSelector:`
- `-setUserInfo:`, `-userInfo`
- `-startSynchronous`, `-clearDelegatesAndCancel`
- `-responseStatusCode`, `-responseData`, `-responseString`, `-responseHeaders`
- `-url`, `-originalURL`, `-error`, `-postBody`

`ASIFormDataRequest`:
- `+requestWithURL:`
- `-setPostValue:forKey:` (builds URL-encoded POST body)

`ASINetworkQueue`:
- `[[ASINetworkQueue alloc] init]`
- `-setShouldCancelAllRequestsOnFailure:`
- `-setDelegate:`, `-setRequestDidFinishSelector:`, `-setRequestDidStartSelector:`, `-setQueueDidFinishSelector:`
- `-setMaxConcurrentOperationCount:`
- `-addOperation:`, `-go`, `-cancelAllOperations`
- `-requestsCount`, `-operations` (returns NSArray for fast enumeration)

**Threading model** (Tiger-compatible):
- `ASIHTTPRequest` is a plain NSObject (not NSOperation — NSOperationQueue is 10.5+)
- `-startSynchronous`: runs libcurl on calling thread, no callbacks
- `-startAsync`: spawns `NSThread detachNewThreadSelector:` to run curl, then
  `performSelectorOnMainThread:withObject:waitUntilDone:NO` to fire delegate callbacks
- `ASINetworkQueue`: `NSMutableArray pendingRequests_` + `NSMutableArray activeRequests_`
  + `NSLock lock_` + int `maxConcurrent_`. When a request finishes it calls back to
  the queue to dequeue the next pending one.

### 2. GCD/Blocks in 4 source files

These 3.0.8 files use `dispatch_async`/`^{}` which are 10.6+:

| File | Usage | Fix |
|---|---|---|
| `RefreshManager.m` | `dispatch_queue_create`, `dispatch_async` for async refresh | Replace with NSThread + performSelectorOnMainThread |
| `Database.m` | Light GCD usage | Replace with direct calls or NSThread |
| `GoogleReader.m` | Minimal | Remove or replace |
| `NSNotificationAdditions.m` | `postNotificationOnMainThread` via GCD | Replace with performSelectorOnMainThread |

These go through the normal patch workflow: edit `build-stage/source/`, then `make patches`.

### 3. MASPreferences

**SS_PrefsController cannot be used directly.** It is a bundle-based plugin loader that scans
for `.preferencePane` bundles on disk. 3.0.8's AppController creates `NSViewController`
instances in code and passes them as an array — a completely different model.

**Plan**: Write a 2-file `MASPreferencesWindowController` that creates its window
programmatically (no XIB). The real logic in the original (toolbar, view switching, resizing)
does not touch the XIB at all — the XIB only creates a blank `NSWindow`. We replace the one
offending call using the Lapcat pattern:

```objc
// Original (requires XIB):
[super initWithWindowNibName:@"MASPreferencesWindow"]
// Replacement: override loadWindow, create NSWindow manually, call [self setWindow:]
```

**Files needed** (add to `src/custom/`):
- `MASPreferencesWindowController.h/.m` — programmatic window, otherwise identical to Pods version
- `MASPreferencesViewController.h` — protocol header only, no implementation needed

**Tiger blocker**: `NSViewController` was introduced in 10.5. All 4 preference pane files
inherit from it. Since Tiger's AppKit has no `NSViewController`, we define a minimal polyfill
in `CrossPlatform.h` — `initWithNibName:bundle:`, `-view`, `-setView:`. On 10.5+ the real
class is used at runtime.

### 4. FMDB replaces SQLDatabase

`Database.h` now imports `FMDatabase.h` instead of `SQLDatabase.h`. FMDB wraps SQLite with
an Objective-C API. 6 source files from `vienna/Pods/FMDB/src/fmdb/`. We already compile
SQLite from source — FMDB just sits on top of it.

One concern: FMDB may use `NSInteger` (10.5+ typedef). Check at compile time; patch if needed
using `XP_` pattern.

### 5. New source files in Makefile

Files in 3.0.8 not present in 2.2.0 that need to be added to `VIENNA_SOURCES`:
```
ArticleCellView.m
BJRWindowWithToolbar.m
BitlyAPIHelper.m
ClickableProgressIndicator.m
Debug.h (header only — included via -include or direct #import)
FilterView.m
GradientView.m
MessageListView.m
NSNotificationAdditions.m
NSURL+Utils.m
SquareWindow.m
SSTextField.m
StdEnclosureView.m
SubscriptionModel.m
ThinSplitView.m
ToolbarButton.m
ToolbarItem.m
UnifiedDisplayView.m
URLHandlerCommand.m
ViennaApp.m
ViewExtensions.m
XMLTag.m
Preferences/AdvancedPreferencesViewController.m
Preferences/AppearancePreferencesViewController.m
Preferences/GeneralPreferencesViewController.m
Preferences/SyncingPreferencesViewController.m
```

Files removed from 2.2.0 that need to come out of Makefile:
```
AdvancedPreferences.m
AppearancesPreferences.m
AsyncConnection.m
DSClickableURLTextField.m (moved to 3rdparty)
DisclosableView.m / SNDisclosableView.m / SNDisclosureButton.m
ExtDateFormatter.m
GeneralPreferences.m
Message.m (renamed to Article.m, already in models/)
NewPreferencesController.m
SQLDatabase.m / SQLDatabasePrivate.m / SQLResult.m / SQLRow.m
SyncPreferences.m
```

### 6. XIBs vs NIBs

3.0.8 uses `.xib` (XML) format. Our Tiger toolchain compiles `.xib` → `.nib` using `ibtool`
from the 10.5 SDK. Need to verify `ibtool` is available in the OSXCross environment.
If not, we pre-compile XIBs to NIBs on a Mac and commit the results to `src/nibs/`.

---

## Patches Still Needed

Even with 3.0.8 source, some Tiger-specific patches will still be required:

| Issue | Files affected | Fix |
|---|---|---|
| `NSInteger` / `NSUInteger` typedef | Various | Already handled by CrossPlatform.h |
| `numberWithInteger:` | Any file using it | `XP_numberWithInteger:` |
| `stringByReplacingOccurrencesOfString:` | Any file using it | `XP_stringByReplacingOccurrencesOfString:` |
| Fast enumeration `for (x in y)` | Widespread in 3.0.8 | gcc 4.0 on PPC supports it — should be OK |
| `@synchronized` | GoogleReader.m | Available on Tiger |
| `NSNotificationAdditions` GCD | NSNotificationAdditions.m | Patch to use performSelectorOnMainThread |

---

## Build Order

1. Build `libASICURLRequest.a` (new): `cd altivec/libs/ASICURLRequest && make -f Makefile-mac`
2. Build `libAICURLConnection.a` (existing): no change
3. `make stage` — stages all vienna/ files with patches applied
4. `make debug` — full app build

---

## Migration Workflow

```
[checkout vienna/ to 3.0.8]           ← done
        ↓
[build ASICURLRequest library]         ← new library, step 1
        ↓
[update Makefile: new sources, new deps]
        ↓
[make stage && make debug]             ← expect compile errors
        ↓
[patch GCD usage in 4 files]           ← main compat work
        ↓
[fix Tiger-specific crashes]           ← XP_ pattern as before
        ↓
[verify XIBs compile / pre-compile]
        ↓
[make clean && make debug && deploy]
```

---

## What We Get For Free After Upgrade

- Full mark-read / mark-starred sync back to The Old Reader
- Subscribe / unsubscribe from within Vienna
- Token refresh every 25 minutes (already in 3.0.8)
- Re-authentication every 6 days
- Inoreader support (bonus)
- Proper `countOfNewArticles` for dock badge
- `getToken` on wake from sleep (AppController already calls it)
