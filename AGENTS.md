# Vienna Legacy Build Strategy (No-Touch)

This document summarizes the technical approach used to compile and deploy **Vienna 2.2.0** for PowerPC and i386 systems without modifying a single file within the original `/vienna` repository.

## 🎯 The Challenge
Legacy Objective-C code often relies on case-insensitive filesystems (common on Mac) and specific compiler behaviors for prefix headers. To build this on a modern Linux host for retro targets while keeping the source directory pristine, we employed several "Shadowing" and "Meta-Source" techniques.

## 🛠️ Core Strategies

### 1. Staged Flat Build (Simplified)
**Strategy:** All components (original `vienna/` core, `sqlite`, `CurlGetDate`, `stubs`, and `CrossPlatform` helpers) are synced into a flat `build-meta/` root via `source/sync_meta.sh`.
**Benefit:** The Makefile discovers and compiles sources directly from this stable directory, ensuring robust and reproducible builds for both Debug and Release targets.

### 2. Tiger (10.4) Runtime Compatibility
**Problem:** Vienna 2.2.0 (and later) contains constructs and API calls introduced in Mac OS X 10.5 (Leopard) that cause crashes or "Selector not recognized" errors on Tiger.
**Solution:**
*   **Cross-Platform Consolidation**: All compatibility logic is centralized in `source/CrossPlatform.h/.m`. This file is automatically injected into every `.m` file during the sync process.
*   **XP_ Category Pattern**: Use categories with an `XP_` prefix (e.g., `[NSURL XP_fileURLWithPath:isDirectory:]`) to bridge API gaps.
    *   **Runtime Checks**: Methods use `respondsToSelector:` and function pointers to call modern APIs if available, falling back to 10.4 logic otherwise.
    *   **Nil Safety**: `XP_URLWithString:` specifically handles `nil` inputs which cause exceptions in Tiger's `NSURL` implementation.
*   **Fast Enumeration Reversion**: Systematically replaced `for (id item in collection)` with 10.4-compatible `NSEnumerator` loops.
*   **API Reversion**: Replaced 10.5+ methods (e.g., `removeItemAtPath:error:`) with 10.4-compatible counterparts (`removeFileAtPath:handler:`).
*   **Recursive Directory Creation**: Custom `createRecursiveDirectory()` helper in `CrossPlatform.m`.
*   **Path Resolution**: Corrected `SharedSupport` path resolution logic to derive paths from `[[NSBundle mainBundle] resourcePath]` to avoid 10.5-only `sharedSupportPath`.

### 3. Automated Patch Management
**Strategy:** Changes are applied to `build-meta/` first, then extracted back to the `patches/` folder.
**Workflow:**
1.  **Modify**: Make surgical changes to files in `build-meta/`.
2.  **Extract**: Run `make patches` (executes `source/generate_patches.sh`). This script compares `build-meta/` against the original `vienna/` submodule, stripping build-time header injections.
3.  **Sync**: `source/sync_meta.sh` (called during `make`) applies all patches from `patches/` using `patch -p1` from the `build-meta/` root.
**Note:** `Info.plist` is also tracked via this patch system to manage `LSMinimumSystemVersion`.

### 4. Dynamic Linker & Case-Sensitivity Fixes
**Problem:** Linux case-sensitivity and duplicate `const` definitions caused compilation and linking errors.
**Solution:** Patches transform `const` to `extern const` in headers, and automated renaming ensures headers are found regardless of casing discrepancies.

### 5. Dependency Removal & Stubbing
**Problem:** Growl and Sparkle frameworks are unnecessary and cause deployment crashes.
**Solution:** 
*   **Stubbing**: `source/stubs.h/m` provides empty implementations for required symbols, including a functional `SUUpdater` stub to satisfy NIB loading.
*   **NIB Sanitization**: Post-build processing strips framework references from binary `.nib` files.

### 6. Source-Based Dependency Integration (PSMTabBarControl)
**Problem:** Legacy PPC linkers often fail when statically linking large external frameworks.
**Solution:** `PSMTabBarControl` is compiled into a standalone dynamic library (`.dylib`) and bundled into a standard `.framework` structure within the app.

## ⚙️ Developer Workflow (IMPORTANT)

If you need to fix a bug or add a compatibility wrapper:
1.  **Edit the logic** in `build-meta/` or `source/CrossPlatform.m`.
2.  **Generate patches**: Run `make patches`. This ensures your changes are persisted in the `patches/` directory.
3.  **Build and Verify**: Run `make debug`. This will re-sync the source, apply your new patches, and compile the PPC/i386 slices.
4.  **No-Touch**: Never edit anything inside the `vienna/` directory.

## 🤖 AI Assistants

This project supports two AI assistants for autonomous development:

*   **Gemini CLI**: Run `docker compose run --rm altivec-intelligence`. This is the default assistant.
*   **Claude CLI**: Run `docker compose run --rm altivec-claude`. 
    *   This command performs a fresh install of `@anthropic-ai/claude-code` at runtime to ensure you are always using the latest version.

## 🚀 Deployment
Deployment is handled via the `altivec_deploy.sh` script, which:
1. Validates the existence of the universal binary (PPC + i386).
2. Automates transfer and extraction to remote Mac targets.
3. Tails remote system logs to provide immediate feedback on crashes or execution errors.
