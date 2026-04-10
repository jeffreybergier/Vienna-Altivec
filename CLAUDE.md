# Vienna Legacy Build Strategy (No-Touch)

This document summarizes the technical approach used to compile and deploy **Vienna 2.2.0** for PowerPC and i386 systems without modifying a single file within the original `/vienna` repository.

## Directory Structure

```
vienna/          # READ ONLY — git submodule, never touch
deps/            # External dependencies (JSONKit, PSMTabBarControl) — READ ONLY
patches/
  vienna/        # Patches against vienna/ originals
  deps/          # Patches against deps/ originals
  resources/     # Patches against vienna/ resource files
  Info.plist.patch
src/
  compat/        # Files graduated from vienna/ — edit directly
  custom/        # Files authored by us — edit directly
  nibs/          # Custom nib builders — edit directly
  resources/     # Custom resource files — edit directly
  scripts/       # Build scripts
build-stage/      # Generated staging area — do not edit, recreated by make stage
```

### Which files can I edit directly?

| Location | Edit directly? | Notes |
|---|---|---|
| `vienna/` | NO | No-touch submodule |
| `deps/` | NO | Use patches if changes needed |
| `src/compat/` | YES | Graduated from vienna/; patches not needed |
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

### Editing a vienna/ or deps/ file (patch workflow)

```bash
make stage
$EDITOR build-stage/source/SomeFile.m
make patches
make clean && make debug
```

`build-stage/` contains the fully-patched versions of all files with full context.
`make patches` diffs `build-stage/` against the originals and saves everything to `patches/`.
Files identical to their original have their patch automatically removed.

### Editing src/compat/, src/custom/, or src/nibs/

```bash
$EDITOR src/custom/CrossPlatform.m
make clean && make debug
```

### Quick Reference Flowchart

```
[vienna/ or deps/ change]          [src/compat|custom|nibs/ change]
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
./altivec/altivec_deploy.sh ./ -d x4-vm --yes 20
```

## Common Pitfalls

- **Forgetting `make clean` before rebuild**: Old `.o` files prevent recompilation. Use `strings` to verify if code made it into the binary.
- **Forgetting `make patches` after editing build-stage/**: Changes in `build-stage/` are lost on the next `make stage`. Always run `make patches` to persist them.
- **Editing `build-stage/` without staging first**: Run `make stage` to populate it before editing.
- **Resource files not found**: Ensure `src/resources/` contains the needed `.tiff` and `.plist` files.
