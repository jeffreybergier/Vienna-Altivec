#!/bin/bash
set -e

# Directories
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VIENNA_DIR="$REPO_ROOT/vienna"
PATCHES_DIR="$REPO_ROOT/patches"
META_DIR="$REPO_ROOT/build-meta"
BACKPORT_DIR="$REPO_ROOT/backport"

echo "=== Syncing Meta-Source ==="
# Clean and recreate directories
rm -rf "$META_DIR/source" "$META_DIR/resources" "$META_DIR/deps" "$META_DIR/backport"
mkdir -p "$META_DIR/source" "$META_DIR/resources" "$META_DIR/deps" "$META_DIR/backport"

# 1. Sync all original source to temp location
TMP_SYNC="$REPO_ROOT/build-meta-sync"
rm -rf "$TMP_SYNC"
echo " > Syncing vienna/ to temp..."
rsync -a --exclude='.git' "$VIENNA_DIR/" "$TMP_SYNC/"

# 2. Copy Info.plist to build-meta root
if [ -f "$TMP_SYNC/Info.plist" ]; then
    cp "$TMP_SYNC/Info.plist" "$META_DIR/Info.plist"
fi

# 3. Distribute files to source/, resources/, and etc/
echo " > Organizing files into source/, resources/, and etc/..."

# Copy source code files to source/
find "$TMP_SYNC" -maxdepth 1 \( -name "*.m" -o -name "*.h" -o -name "*.c" -o -name "*.pch" \) -exec cp {} "$META_DIR/source/" \;

# Copy sqlite/ to deps/
[ -d "$TMP_SYNC/sqlite" ] && cp -r "$TMP_SYNC/sqlite" "$META_DIR/deps/sqlite"

# Copy CurlGetDate/ to deps/
[ -d "$TMP_SYNC/CurlGetDate" ] && cp -r "$TMP_SYNC/CurlGetDate" "$META_DIR/deps/CurlGetDate"

# Copy all resource directories to resources/
for dir in Styles scripts palettes Plugins Portable SyntaxHighlighter; do
    [ -d "$TMP_SYNC/$dir" ] && cp -r "$TMP_SYNC/$dir" "$META_DIR/resources/"
done

# Copy framework directories and .nib/.lproj to resources/
find "$TMP_SYNC" -maxdepth 1 -type d \( -name "*.framework" -o -name "*.nib" -o -name "*.lproj" \) -exec cp -r {} "$META_DIR/resources/" \;

# Copy resource files to resources/
# Include: text files, plists, images, and other Vienna resources
# Exclude: source code, build system files, project files, git files
find "$TMP_SYNC" -maxdepth 1 -type f ! -name "Info.plist" \
  ! -name "*.m" ! -name "*.h" ! -name "*.c" ! -name "*.pch" \
  ! -name "Makefile" ! -name "makefile" ! -name "CMakeLists.txt" ! -name ".git*" \
  ! -name "README*" ! -name "readme*" ! -name "LICENSE*" ! -name "license*" \
  ! -name "CONTRIBUTING*" ! -name "*.mk" ! -name ".DS_Store" \
  -exec cp {} "$META_DIR/resources/" \;

# Cleanup temp
rm -rf "$TMP_SYNC"

# Remove any build system files and unnecessary directories that shouldn't be in resources/
rm -f "$META_DIR/resources/makefile" "$META_DIR/resources/Makefile" \
      "$META_DIR/resources/CMakeLists.txt" "$META_DIR/resources/.DS_Store"
rm -rf "$META_DIR/resources"/*.xcodeproj "$META_DIR/resources/documents" "$META_DIR/resources/CurlGetDate"

# 2. Copy external dependencies to build-meta/deps/
echo " > Staging external dependencies..."
# Copy JSONKit v1.2 from deps
if [ -d "$REPO_ROOT/deps/JSONKit" ]; then
    cp -r "$REPO_ROOT/deps/JSONKit" "$META_DIR/deps/JSONKit"
fi
# Copy PSMTabBarControl from deps
if [ -d "$REPO_ROOT/deps/PSMTabBarControl" ]; then
    cp -r "$REPO_ROOT/deps/PSMTabBarControl" "$META_DIR/deps/PSMTabBarControl"
fi

# 3. Copy backported files to build-meta/backport/
echo " > Staging backported components..."
# Copy all files (not directories) from backport/ to build-meta/backport/
find "$BACKPORT_DIR" -maxdepth 1 -type f -exec cp {} "$META_DIR/backport/" \;

# Copy nib/ source files to build-meta/backport/ (compiled by the Makefile)
if [ -d "$BACKPORT_DIR/nib" ]; then
    find "$BACKPORT_DIR/nib" -maxdepth 1 -type f \( -name "*.h" -o -name "*.m" \) -exec cp {} "$META_DIR/backport/" \;
fi

# Copy backport resource files (plist, tiff) to build-meta/resources/
# These are new files that don't exist in vienna/ so there is no conflict.
if [ -d "$BACKPORT_DIR/resources" ]; then
    find "$BACKPORT_DIR/resources" -maxdepth 1 -type f -exec cp {} "$META_DIR/resources/" \;
fi

# 4. Stage Vienna custom sources into build-meta/source/extra/
echo " > Staging Vienna custom components..."
mkdir -p "$META_DIR/source/extra"

# 5. Apply all patches
bash "$BACKPORT_DIR/scripts/apply_patches.sh"

# 7. Inject prefix headers
echo " > Injecting prefix headers..."
find "$META_DIR/source" -name "*.m" | while read -r f; do
    # Skip JSONKit - it's a third-party file that manages its own headers
    case "$(basename "$f")" in JSONKit.m) continue ;; esac
    # Ensure Vienna_Prefix.pch is imported
    if ! grep -q "Vienna_Prefix.pch" "$f"; then
        sed -i '1i #import "Vienna_Prefix.pch"' "$f"
    fi
    # Ensure HelperFunctions is imported for our recursive helper
    if ! grep -q "HelperFunctions.h" "$f"; then
        sed -i '2i #import "HelperFunctions.h"' "$f"
    fi
    # Ensure CrossPlatform.h is imported for XP_ compatibility shims
    if ! grep -q "CrossPlatform.h" "$f"; then
        sed -i '3i #import "CrossPlatform.h"' "$f"
    fi
done

touch "$META_DIR/.stamp"
echo "=== Meta-Source Ready ==="
