#!/bin/bash
set -e

# Directories
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VIENNA_DIR="$REPO_ROOT/vienna"
PATCHES_DIR="$REPO_ROOT/patches"
META_DIR="$REPO_ROOT/build-meta"

echo "=== Syncing Meta-Source ==="
mkdir -p "$META_DIR"

# 1. Sync original source
echo " > Syncing vienna/ to build-meta/..."
rsync -a --exclude='.git' "$VIENNA_DIR/" "$META_DIR/"

# 2. Stage extra sources into build-meta for a flat build
# This makes the Makefile much simpler
echo " > Staging extra components..."
mkdir -p "$META_DIR/extra"
# Copy CrossPlatform helpers
cp "$REPO_ROOT/source/CrossPlatform.h" "$META_DIR/extra/"
cp "$REPO_ROOT/source/CrossPlatform.m" "$META_DIR/extra/"
# Copy CurlGetDate sources if they exist in the original vienna or our source
if [ -d "$VIENNA_DIR/CurlGetDate" ]; then
    cp "$VIENNA_DIR/CurlGetDate/"*.m "$META_DIR/extra/" 2>/dev/null || true
    cp "$VIENNA_DIR/CurlGetDate/"*.h "$META_DIR/extra/" 2>/dev/null || true
fi

# 3. Apply all patches
echo " > Applying patches from $PATCHES_DIR..."
# We run patch from inside build-meta and use -p1 to match the 'vienna/' prefix in patches
pushd "$META_DIR" > /dev/null
for p in "$PATCHES_DIR"/*.patch; do
    [ -e "$p" ] || continue
    echo "   > Applying $(basename "$p")"
    patch -s -p1 < "$p" || echo "     ! Warning: Patch failed for $(basename "$p")"
done
popd > /dev/null

# 4. Inject prefix headers
echo " > Injecting prefix headers..."
find "$META_DIR" -name "*.m" | while read -r f; do
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
