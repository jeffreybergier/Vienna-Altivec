# Vienna Legacy Build Strategy (No-Touch)

This document summarizes the technical approach used to compile and deploy **Vienna 2.2.0** for PowerPC and i386 systems without modifying a single file within the original `/vienna` repository.

## Directory Structure

```
vienna/          # READ ONLY — git submodule, never touch
deps/            # External dependencies (JSONKit, PSMTabBarControl) — READ ONLY
src/compat/      # READ ONLY — backported/modified originals, never touch
patches/
  vienna/        # Patches against vienna/ originals
  compat/        # Patches against src/compat/ originals
  deps/          # Patches against deps/ originals
  resources/     # Patches against vienna/ resource files
  Info.plist.patch
src/
  compat/        # READ ONLY — backported originals (e.g. KeyChain 3.0.0)
  custom/        # Files authored by us — edit directly
  nibs/          # Custom nib builders — edit directly
  resources/     # Custom resource files — edit directly
  scripts/       # Build scripts
build-stage/      # Generated staging area — edit freely, run make patches to persist
```

### Which files can I edit directly?

| Location | Edit directly? | Notes |
|---|---|---|
| `vienna/` | NO | No-touch submodule |
| `deps/` | NO | Use patches if changes needed |
| `src/compat/` | NO | Backported originals; use patch workflow via build-stage/ |
| `src/custom/` | YES | Authored by us |
| `src/nibs/` | YES | Custom nib builders |
| `src/resources/` | YES | Custom resources |
| `build-stage/` | YES | Edit freely — run `make patches` to persist changes |

## Dependency Linking

| Dependency | How linked |
|---|---|
| PSMTabBarControl | `.dylib` bundled as `.framework` inside app |
| JSONKit | Compiled from source, statically in main binary |
| SQLite | Compiled from source, statically in main binary |
| libcurl / libssl / libz | Prebuilt `.a` files, statically in main binary |

## Core Strategies

### Tiger (10.4) Runtime Compatibility
- All compatibility logic is centralized in `src/custom/CrossPlatform.h/.m`
- Headers are injected at compile time via `-include` flags (not by modifying source files)
- XP_ category pattern bridges API gaps with runtime checks
- Fast enumeration replaced with NSEnumerator throughout

### Patch Management
Patches are unified diffs stored in `patches/`. They are applied automatically during `make stage` to the staged copies in `build-stage/`.

### PSMTabBarControl
Compiled as a standalone `.dylib` and bundled as a `.framework`. Avoids PPC static linker failures with large external libs.

## Developer Workflow

### Clean Build

```bash
make stage && make debug
```

`make stage` runs `make clean` automatically, then re-stages all sources and applies patches.
`make debug` compiles incrementally from whatever is in `build-stage/`.

### Incremental Debug Loop (editing build-stage/ directly)

```bash
$EDITOR build-stage/source/SomeFile.m
make debug
```

`make debug` does NOT call `make stage`, so edits in `build-stage/` are preserved between builds.

### Persisting Changes Back to Patches

Once debugging is working, persist the changes:

```bash
make patches
make stage && make debug   # confirm clean build still works
```

`make patches` diffs `build-stage/source/` against originals: compat files go to
`patches/compat/`, vienna files go to `patches/vienna/`.
Files identical to their original have their patch automatically removed.

### Editing src/custom/ or src/nibs/

```bash
$EDITOR src/custom/CrossPlatform.m
make debug
```

No staging needed — these files are compiled directly from `src/`.

### Quick Reference Flowchart

```
[vienna/, deps/, or compat/ change]     [src/custom|nibs/ change]
              ↓                                    ↓
   make stage && make debug               edit directly
              ↓                                    ↓
       edit build-stage/                     make debug
              ↓
          make debug  (incremental)
              ↓
          make patches  (persist)
              ↓
   make stage && make debug  (confirm)
              ↓
   ./altivec/altivec_deploy.sh
```

## AI Assistants

*   **Gemini CLI**: Run `docker compose run --rm altivec-intelligence`. This is the default assistant.
*   **Claude CLI**: Run `docker compose run --rm altivec-claude`.

## Deployment

```bash
./altivec/altivec_deploy.sh ./ -d <target-host> --yes 20
```

## Common Pitfalls

- **Forgetting `make patches` after editing build-stage/**: Changes in `build-stage/` are lost on the next `make stage`. Always run `make patches` to persist them.
- **Editing `build-stage/` without staging first**: Run `make stage` to populate it before editing.
- **Resource files not found**: Ensure `src/resources/` contains the needed `.tiff` and `.plist` files.
