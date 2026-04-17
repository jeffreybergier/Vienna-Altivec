# Vienna Legacy Build Strategy (No-Touch)

This document summarizes the technical approach used to compile and deploy **Vienna 3.0.8** for PowerPC and i386 systems without modifying a single file within the original `/vienna` repository.

## Directory Structure

```
vienna/          # READ ONLY — git submodule (checked out to 3.0.8 @ 074a131a)
deps/            # External dependencies (JSONKit, PSMTabBarControl, sqlite, fmdb) — READ ONLY
patches/
  vienna/        # Patches against vienna/ originals (incl. Preferences/*)
  deps/          # Patches against deps/ originals (ASIHTTPRequest, FMDB, MASPreferences, PXListView)
  resources/     # Patches against vienna/ resource files
  Info.plist.patch
src/
  custom/        # Files authored by us — edit directly
                 #   CrossPlatform.h/.m, stubs.h/.m, ASIAuthenticationDialog.h, Reachability.h
  nibs/          # Programmatic NIB builders for preference panes — edit directly
  resources/     # Custom resource files — edit directly
  scripts/       # Build scripts (stage.sh, apply_patches.sh, generate_patches.sh)
build-stage/     # Generated staging area — edit freely, run make patches to persist
altivec/libs/    # Prebuilt static libraries (libcurl, libssl, libcrypto, libz)
```

### Which files can I edit directly?

| Location | Edit directly? | Notes |
|---|---|---|
| `vienna/` | NO | No-touch submodule |
| `deps/` | NO | Use patches if changes needed |
| `src/custom/` | YES | Authored by us |
| `src/nibs/` | YES | Programmatic pref-pane view builders |
| `src/resources/` | YES | Custom resources |
| `build-stage/` | YES | Edit freely — run `make patches` to persist changes |

## Dependency Linking

| Dependency | How linked |
|---|---|
| PSMTabBarControl | `.dylib` bundled as `.framework` inside app |
| JSONKit | Compiled from source, statically in main binary |
| SQLite | Compiled from source (`deps/sqlite/sqlite3.c`), statically in main binary |
| FMDB | Compiled from source via build-stage (`deps/FMDB`), statically in main binary |
| MASPreferences | Compiled from source via build-stage, statically in main binary |
| PXListView | Compiled from source via build-stage, statically in main binary |
| ASIHTTPRequest | Compiled from source via build-stage (libcurl-backed — see below) |
| libcurl / libssl / libcrypto / libz | Prebuilt `.a` files, statically in main binary |

## Core Strategies

### Tiger (10.4) Runtime Compatibility
- All compatibility logic is centralized in `src/custom/CrossPlatform.h/.m`
- Headers are injected at compile time via `-include` flags (not by modifying source files)
- XP_ category pattern bridges API gaps with runtime checks
- Fast enumeration replaced with NSEnumerator where gcc 4.0 can't handle it
- Polyfills for `NSViewController`, `NSThread XP_isMainThread`, `performSelector:onThread:`

### Patch Management
Patches are unified diffs stored in `patches/`. They are applied automatically during `make stage` to the staged copies in `build-stage/`. Patches identical to their original have their patch file automatically removed by `make patches`.

### ASIHTTPRequest → libcurl networking
The real ASIHTTPRequest from 3.0.8's Pods is patched in-place so its CFNetwork streaming path is replaced with libcurl (CFNetwork on Tiger/Leopard doesn't support TLS 1.2, so modern HTTPS feed endpoints fail). Authentication and proxy data-structure APIs (CFHTTPMessage, CFHTTPAuthentication) remain, since they still work fine on 10.4/10.5 — only the transport was swapped. Each request runs `curl_easy_perform` on a detached worker thread and marshals completion back to the shared network thread via `XP_performSelector:onThread:`.

### PSMTabBarControl
Compiled as a standalone `.dylib` and bundled as a `.framework`. Avoids PPC static linker failures with large external libs.

### Preference Panes (MASPreferences)
3.0.8 uses MASPreferences (NSViewController-based), which doesn't exist on Tiger. We:
- Ship an NSViewController polyfill in `CrossPlatform.h`
- Provide programmatic view builders for each pane in `src/nibs/` (e.g. `GeneralPreferencesView.m`) — these replace the XIBs that would otherwise need `ibtool` from a newer SDK
- Patch `MASPreferencesWindowController` so its window is constructed in code rather than loaded from a NIB

## Developer Workflow

### Editing a vienna/ or deps/ file (patch workflow)

```bash
make stage
$EDITOR build-stage/source/SomeFile.m
make patches
make clean && make debug
```

`build-stage/` contains the fully-patched versions of all files with full context.
`make patches` diffs `build-stage/` against the originals and saves everything to `patches/`.

### Editing src/custom/ or src/nibs/

```bash
$EDITOR src/custom/CrossPlatform.m
make clean && make debug
```

No staging needed — these files are compiled directly from `src/`.

### Quick Reference Flowchart

```
[vienna/ or deps/ change]          [src/custom|nibs/ change]
         ↓                                       ↓
     make stage                           edit directly
         ↓                                       ↓
  edit build-stage/                             ↓
         ↓                                       ↓
     make patches                               ↓
         ↓                                       ↓
         └──────────────────┬────────────────────┘
                            ↓
                    make clean && make debug
                            ↓
               ./altivec/altivec_deploy.sh
```

## AI Assistants

*   **Gemini CLI**: Run `docker compose run --rm altivec-intelligence`. This is the default assistant.
*   **Claude CLI**: Run `docker compose run --rm altivec-claude`.

## Deployment

```bash
./altivec/altivec_deploy.sh build-debug -d <target-host> --yes 20
```

## Common Pitfalls

- **Forgetting `make clean` before rebuild**: Old `.o` files prevent recompilation. Use `strings` to verify if code made it into the binary.
- **Forgetting `make patches` after editing build-stage/**: Changes in `build-stage/` are lost on the next `make stage`. Always run `make patches` to persist them.
- **Editing `build-stage/` without staging first**: Run `make stage` to populate it before editing.
- **Resource files not found**: Ensure `src/resources/` contains the needed `.tiff` and `.plist` files.
- **Touching CFNetwork code paths in ASIHTTPRequest**: The transport has been swapped to libcurl. CFHTTPMessage/CFHTTPAuthentication symbols remain but are only used for auth/proxy data — there is no longer a CFReadStream.
