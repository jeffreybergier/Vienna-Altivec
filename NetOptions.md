# Vienna Networking Replacement Plan: AICURLConnection

## Why Replace the Networking?

Vienna 2.6.0 uses `NSURLConnection` for all non-WebKit HTTP requests. On Tiger (10.4),
`NSURLConnection` uses the system's SSL stack which cannot negotiate with modern HTTPS
servers — TLS 1.2/1.3 are not supported. This means feed fetching, link shortening, and
file downloads all silently fail or error out on any modern HTTPS endpoint.

`AICURLConnection` wraps `libcurl` with a bundled modern OpenSSL, providing TLS 1.3
support on Tiger with a near-identical API to `NSURLConnection`. Replacing the networking
layer fixes HTTPS compatibility for the app's lifetime.

---

## Inventory of All Networking in Vienna 2.6.0

### 1. `AsyncConnection.m` — Async Feed & Favicon Fetching
**Used by:** `RefreshManager.m`
**Mechanism:** `NSURLConnection alloc initWithRequest:delegate:` (async, delegate callbacks)
**Purpose:** Downloads RSS/Atom feed XML and feed favicons.
**Volume:** Two connections created per feed refresh cycle.

### 2. `BitlyAPIHelper.m` — URL Shortening
**Used by:** Share menu actions.
**Mechanism:** `[NSURLConnection sendSynchronousRequest:returningResponse:error:]`
**Purpose:** Synchronous POST to bit.ly API to shorten a URL.
**Volume:** One request per user share action.

### 3. `NewSubscription.m` — Feed Discovery
**Used by:** New subscription dialog (auto-detect feed URL from a site URL).
**Mechanism:** `[NSURLConnection sendSynchronousRequest:returningResponse:error:]`
**Purpose:** Fetches a web page's HTML synchronously to scan for `<link rel="alternate">` feed tags.
**Volume:** One request per new subscription attempt.

### 4. `DownloadManager.m` — File Downloads
**Used by:** Enclosure/attachment download feature.
**Mechanism:** `NSURLDownload alloc initWithRequest:delegate:` (a separate class from NSURLConnection)
**Purpose:** Downloads binary files to disk with progress reporting.
**Volume:** One per user-initiated download.

### 5. WebKit (`BrowserPane`, `ArticleView`, `ArticleListView`, `UnifiedDisplayView`, `TabbedWebView`, `XMLSourceWindow`) — Page & Article Rendering
**Mechanism:** WebKit's internal networking stack, driven by `[[webPane mainFrame] loadRequest:]`.
**Purpose:** Renders full web pages in the browser pane and renders article HTML content.
**Volume:** Every page view and every article render.

---

## Replacement Plan by Component

### Component 1: `AsyncConnection.m` — **Full Replacement**

This is the highest priority and highest impact change.

**What to do:** Replace the single `NSURLConnection` instantiation on line 175:

```objc
// Before
connector = [[NSURLConnection alloc] initWithRequest:theRequest delegate:self];

// After
connector = [[AICURLConnection alloc] initWithRequest:theRequest delegate:self];
```

That is the only line that needs to change. `AICURLConnection` fires the same four
delegate callbacks that `AsyncConnection` implements:

| Delegate Method | AsyncConnection uses it | AICURLConnection fires it |
|---|---|---|
| `connection:didReceiveResponse:` | Read HTTP status, grab headers | ✅ Yes |
| `connection:didReceiveData:` | Accumulate response bytes | ✅ Yes |
| `connectionDidFinishLoading:` | Signal completion | ✅ Yes |
| `connection:didFailWithError:` | Signal failure | ✅ Yes |
| `connection:willSendRequest:redirectResponse:` | Log redirects only | ❌ Not fired — loss of redirect log entries only |
| `connection:willCacheResponse:` | Returns nil to suppress caching | ❌ Not fired — harmless, libcurl does not cache |
| `connection:didReceiveAuthenticationChallenge:` | Send HTTP Basic Auth | ❌ Not fired — irrelevant for feed fetching; Vienna stores credentials in the URL |

**Risk:** Very low. One line change. All feed refresh and favicon fetching moves to
modern TLS immediately. The `connector` ivar type changes from `NSURLConnection *` to
`AICURLConnection *` — update the ivar declaration in `AsyncConnection.h` accordingly.

**Headers to add:** `#import "AICURLConnection.h"` in `AsyncConnection.m`.

---

### Component 2: `BitlyAPIHelper.m` — **Full Replacement**

**What to do:** Replace the synchronous `NSURLConnection` call with `AICURLConnection`'s
synchronous equivalent, which has an identical signature:

```objc
// Before
NSData * data = [NSURLConnection sendSynchronousRequest:request
                                      returningResponse:&urlResponse
                                                  error:&error];

// After
NSData * data = [AICURLConnection sendSynchronousRequest:request
                                       returningResponse:&urlResponse
                                                   error:&error];
```

**Risk:** Very low. Method signature is identical. The call is already on a background
thread (invoked from a menu action). Note: the bit.ly API itself is largely defunct;
this is low-priority but trivial to fix.

---

### Component 3: `NewSubscription.m` — **Full Replacement**

**What to do:** Same synchronous swap as BitlyAPIHelper:

```objc
// Before
NSData * urlContent = [NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:url]
                                            returningResponse:NULL error:NULL];

// After
NSData * urlContent = [AICURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:url]
                                             returningResponse:NULL error:NULL];
```

**Risk:** Low. However, this call runs on the **main thread** (it is in the subscription
dialog's validation flow). This was always a poor pattern — it blocks the UI while
fetching. The replacement does not make this worse, but it is worth noting. A future
improvement could make this async, but that is out of scope for a direct replacement.

---

### Component 4: `DownloadManager.m` — **Not Directly Replaceable**

`DownloadManager` uses `NSURLDownload`, which is a different class from `NSURLConnection`.
`NSURLDownload` streams data directly to a file on disk and provides MIME-type decoding
(MacBinary, BinHex). `AICURLConnection` has no equivalent — it delivers data in memory
via delegate callbacks, not directly to a file path.

**Options:**

**Option A — Leave as-is (recommended for now):**  
File downloads from feed enclosures are typically MP3s or PDFs hosted on servers that
still support older TLS. In practice, this is unlikely to break for most users. The
feature can be revisited if specific download failures are reported.

**Option B — Implement a download wrapper using AICURLConnection:**  
`AICURLConnection`'s `connection:didReceiveData:` callback could be used to stream
chunks into an `NSFileHandle`, replicating `NSURLDownload`'s behaviour. This is
approximately 100–150 lines of new code in a helper class. The MIME-type decoding
feature (MacBinary/BinHex) would be lost, but this is unlikely to matter for modern
enclosures.

---

### Component 5: WebKit Networking — **Not Replaceable**

WebKit manages its own internal HTTP stack. There is no supported mechanism to intercept
or redirect WebKit's network requests through a custom transport layer on 10.4's version
of WebKit. `NSURLProtocol` registration exists but is not reliably honoured by WebKit's
internal engine on Tiger.

This affects:
- `BrowserPane` — in-app web browser
- `ArticleView` / `ArticleListView` / `UnifiedDisplayView` — article content rendering
- `XMLSourceWindow` — XML source viewer

**Practical impact:** Article content is rendered from locally-constructed HTML strings
(Vienna builds the HTML from parsed feed data and injects it with `loadData:MIMEType:`),
so WebKit rarely makes outbound network requests for article rendering. The browser pane
(`BrowserPane`) does make live web requests, and these will still use the system SSL stack.
On Tiger this means HTTPS sites may fail to load in the browser pane.

**This is a known and accepted limitation.** The browser pane on Tiger is best used for
HTTP sites or as a fallback. The core functionality — feed fetching and reading — is fully
covered by the `AsyncConnection` replacement above.

---

## Summary

| Component | Class | Replaceable | Effort | Priority |
|---|---|---|---|---|
| Feed & favicon fetching | `AsyncConnection` | ✅ Yes — 1 line | Trivial | High |
| URL shortening | `BitlyAPIHelper` | ✅ Yes — 1 line | Trivial | Low |
| Feed discovery | `NewSubscription` | ✅ Yes — 1 line | Trivial | Medium |
| File downloads | `DownloadManager` | ⚠️ Partial — needs wrapper | Medium | Low |
| WebKit page rendering | Browser/Article views | ❌ No | N/A | N/A |

## Implementation Order

1. Add `AICURLConnection.h/m` and `libcurl` to the build (already done via the Altivec engine).
2. Replace `AsyncConnection.m` — fixes all feed fetching immediately.
3. Replace `NewSubscription.m` — fixes feed auto-discovery for HTTPS sites.
4. Replace `BitlyAPIHelper.m` — fixes URL shortening.
5. Optionally implement a file-download wrapper around `AICURLConnection` for `DownloadManager`.

Steps 2–4 are each a single line change. The entire replacement (excluding the download
wrapper) is approximately 3 lines of code changed and 3 import statements added.
