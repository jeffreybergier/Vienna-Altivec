#!/bin/bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
META_DIR="$REPO_ROOT/build-meta"
PATCHES_DIR="$REPO_ROOT/patches"

echo "=== Applying Patches ==="

# --- source/ ---
if [ -d "$PATCHES_DIR/source" ]; then
    echo " > source/"
    pushd "$META_DIR/source" > /dev/null
    find "$PATCHES_DIR/source" -name "*.patch" | sort | while read -r p; do
        echo "   > $(basename "$p")"
        patch -s -p1 < "$p" || echo "     ! Warning: failed $(basename "$p")"
    done
    popd > /dev/null
fi

# --- backport/ ---
if [ -d "$PATCHES_DIR/backport" ]; then
    echo " > backport/"
    pushd "$META_DIR/backport" > /dev/null
    find "$PATCHES_DIR/backport" -name "*.patch" | sort | while read -r p; do
        echo "   > $(basename "$p")"
        patch -s -p0 < "$p" || echo "     ! Warning: failed $(basename "$p")"
    done
    popd > /dev/null
fi

# --- deps/ ---
if [ -f "$PATCHES_DIR/deps/JSONKit.m.patch" ]; then
    echo " > deps/"
    pushd "$META_DIR/deps/JSONKit" > /dev/null
    echo "   > JSONKit.m.patch"
    patch -s -p0 < "$PATCHES_DIR/deps/JSONKit.m.patch" || echo "     ! Warning: failed JSONKit.m.patch"
    popd > /dev/null
fi

# --- Info.plist ---
if [ -f "$PATCHES_DIR/Info.plist.patch" ]; then
    echo " > Info.plist"
    pushd "$META_DIR" > /dev/null
    patch -s -p0 < "$PATCHES_DIR/Info.plist.patch" || echo "     ! Warning: failed Info.plist.patch"
    popd > /dev/null
fi

# --- resources/ ---
if [ -d "$PATCHES_DIR/resources" ]; then
    echo " > resources/"
    pushd "$META_DIR/resources" > /dev/null
    find "$PATCHES_DIR/resources" -name "*.patch" | sort | while read -r p; do
        echo "   > $(basename "$p")"
        patch -s -p0 < "$p" || echo "     ! Warning: failed $(basename "$p")"
    done
    popd > /dev/null
fi

echo "=== Done ==="
