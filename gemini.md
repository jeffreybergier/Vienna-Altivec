# Vienna Legacy Build Strategy (No-Touch)

This document summarizes the technical approach used to compile and deploy **Vienna 2.1.0** for PowerPC and i386 systems without modifying a single file within the original `/vienna` repository.

## 🎯 The Challenge
Legacy Objective-C code often relies on case-insensitive filesystems (common on Mac) and specific compiler behaviors for prefix headers. To build this on a modern Linux host for retro targets while keeping the source directory pristine, we employed several "Shadowing" techniques.

## 🛠️ Core Strategies

### 1. Shadow Source Injection
**Problem:** The legacy GCC compiler required the prefix header (`Vienna_Prefix.pch`) to be included in every file, but the source files lacked explicit imports for it, and the `-include` compiler flag was inconsistent.
**Solution:** The Makefile creates a "shadow" directory in `build/Intermediates`. For every `.m` file in the original repo, it creates a temporary copy and prepends `#import "Vienna_Prefix.pch"` to the top of the file using a shell redirect. The compiler then builds from these temporary "shadow" files.

### 2. Bridging Case-Sensitivity
**Problem:** Linux is case-sensitive. The Vienna source uses `#import "BacktrackArray.h"`, but the physical file is named `BackTrackArray.h` (uppercase 'T').
**Solution:** A shadow include directory was created (`build/Intermediates/include`). We used `git show HEAD:BackTrackArray.h` to extract the content and save it as `BacktrackArray.h` (lowercase 't') in this shadow folder. By adding this folder to the include path (`-I`), we satisfied the compiler's search without renaming the original file.

### 3. Dynamic Linker Fixes (Header Shadowing)
**Problem:** `Constants.h` contained `const` definitions without `extern`. This caused "duplicate symbol" errors because every object file including the header tried to define the same global variable.
**Solution:** We created a shadow version of `Constants.h` in the intermediates folder. We used `sed` to dynamically transform `const AEKeyword` into `extern const AEKeyword` during the copy process. This allowed the code to link successfully while maintaining the original header's integrity.

### 4. Semantic Bundling
**Problem:** The application crashed on startup with a "Default style is corrupted!" error because it expected its Styles and Scripts to be in `Contents/SharedSupport`, not `Contents/Resources`.
**Solution:** The Makefile's bundling logic was customized to map the flat directory structure of the repository to the specific sub-paths expected by the legacy Vienna runtime (`Contents/SharedSupport/Styles` and `Contents/SharedSupport/Scripts`).

### 5. Build Isolation
**Strategy:** We implemented a standalone Makefile that separates builds into `build-debug` (using `-O0`) and `build-release` (using `-O3`). This prevents intermediate object collisions and allows for rapid testing of unoptimized code on the target hardware.

## 🚀 Deployment
Deployment is handled via the `altivec_deploy.sh` script, which:
1. Validates the existence of the universal binary (PPC + i386).
2. Requires a `.zip` payload for remote Mac targets to preserve resource forks and symbolic links.
3. Automates the transfer, extraction, and remote launch on the target `x5-vm` (Leopard 10.5.8).
