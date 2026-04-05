# Vienna Legacy Build Strategy (No-Touch)

This document summarizes the technical approach used to compile and deploy **Vienna 2.2.0** for PowerPC and i386 systems without modifying a single file within the original `/vienna` repository.

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
**Solution:** We created a shadow version of `Constants.h` in the intermediates folder. We used a patch file to dynamically transform `const AEKeyword` into `extern const AEKeyword` during the copy process. This allowed the code to link successfully while maintaining the original header's integrity.

### 4. Semantic Bundling
**Problem:** The application crashed on startup with a "Default style is corrupted!" error because it expected its Styles and Scripts to be in `Contents/SharedSupport`, not `Contents/Resources`.
**Solution:** The Makefile's bundling logic was customized to map the flat directory structure of the repository to the specific sub-paths expected by the legacy Vienna runtime (`Contents/SharedSupport/Styles` and `Contents/SharedSupport/Scripts`).

### 5. Dependency Removal (Growl & Sparkle)
**Problem:** The user requested the removal of Growl (notifications) and Sparkle (auto-updates) to reduce bloat and avoid unnecessary legacy dependencies.
**Solution:** 
*   **Stubbing**: Created `stubs.h` and `stubs.m` providing empty implementations for `GrowlApplicationBridge` and Sparkle constants.
*   **Surgical Patching**: Applied patches to `AppController.m` and `Preferences.m` during the shadowing phase to remove framework imports.
*   **NIB Sanitization**: Added a post-build `sed` step to strip hard-coded framework references from the binary `keyedobjects.nib` files to prevent `dyld` launch crashes.

### 6. Source-Based Dependency Integration (PSMTabBarControl)
**Problem:** The original project relied on a closed-source binary for `PSMTabBarControl.framework`. Transitioning to the open-source version (git submodule) triggered segmentation faults in the legacy PPC linker when statically linked.
**Solution:**
*   **Dynamic Framework Scaffolding:** The submodule was compiled into a standalone dynamic library (`.dylib`). The Makefile then constructed a standard macOS `.framework` bundle structure inside the build folder.
*   **Linker Stability:** Moving the dependency to a separate dynamic binary reduced the total symbol count in the main executable, bypassing the PPC linker's memory/recursion limits.
*   **Runtime Pathing:** Used `-install_name @executable_path/../Frameworks/...` during the dylib link phase to ensure the OS could locate the library inside the app bundle.
*   **Class Availability:** Injected a `[PSMTabBarControl class]` call into `main.m` (via patching) to force-load the framework's classes before the NIB files were unarchived.
*   **Legacy Porting:** Patched the modern submodule source to revert 10.6+ features (like typed enums and formal protocols) back to 10.5-compatible syntax.

### 7. Build Isolation
**Strategy:** We implemented a standalone Makefile that separates builds into `build-debug` (using `-O0`) and `build-release` (using `-O3`). This prevents intermediate object collisions and allows for rapid testing of unoptimized code on the target hardware.

## 🚀 Deployment
Deployment is handled via the `altivec_deploy.sh` script, which:
1. Validates the existence of the universal binary (PPC + i386).
2. Requires a `.zip` payload for remote Mac targets to preserve resource forks and symbolic links.
3. Automates the transfer, extraction, and remote launch on the target `x5-vm` (Leopard 10.5.8).
