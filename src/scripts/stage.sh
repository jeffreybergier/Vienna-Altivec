#!/bin/bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VIENNA_DIR="$REPO_ROOT/vienna"
DEPS_DIR="$REPO_ROOT/deps"
SRC_DIR="$REPO_ROOT/src"
META_DIR="$REPO_ROOT/build-stage"

echo "=== Staging Sources ==="

rm -rf "$META_DIR"
mkdir -p \
  "$META_DIR/source/Preferences" \
  "$META_DIR/source/models" \
  "$META_DIR/deps/JSONKit" \
  "$META_DIR/deps/sqlite" \
  "$META_DIR/deps/PXListView" \
  "$META_DIR/deps/MASPreferences" \
  "$META_DIR/deps/FMDB" \
  "$META_DIR/resources"

# Vienna source files — flat in src/
echo " > Copying vienna/src/ source..."
find "$VIENNA_DIR/src" -maxdepth 1 \
  \( -name "*.m" -o -name "*.h" -o -name "*.c" -o -name "*.pch" \) \
  -exec cp {} "$META_DIR/source/" \;

# vienna/src/Preferences/
find "$VIENNA_DIR/src/Preferences" -maxdepth 1 \
  \( -name "*.m" -o -name "*.h" \) \
  -exec cp {} "$META_DIR/source/Preferences/" \;

# vienna/src/models/
find "$VIENNA_DIR/src/models" -maxdepth 1 \
  \( -name "*.m" -o -name "*.h" \) \
  -exec cp {} "$META_DIR/source/models/" \;

# External deps
echo " > Copying deps/..."
cp -r "$DEPS_DIR/JSONKit"/. "$META_DIR/deps/JSONKit/"
cp -r "$DEPS_DIR/sqlite"/. "$META_DIR/deps/sqlite/"
cp "$VIENNA_DIR/Pods/PXListView/Classes/"*.{m,h} "$META_DIR/deps/PXListView/" 2>/dev/null || true
cp "$VIENNA_DIR/Pods/MASPreferences/"*.{m,h} "$META_DIR/deps/MASPreferences/" 2>/dev/null || true
cp "$REPO_ROOT/deps/fmdb/src/FMDatabase."{m,h} "$META_DIR/deps/FMDB/"
cp "$REPO_ROOT/deps/fmdb/src/FMResultSet."{m,h} "$META_DIR/deps/FMDB/"

# Info.plist (3.0.8 keeps it in Resources/)
cp "$VIENNA_DIR/Resources/Vienna-Info.plist" "$META_DIR/Info.plist"

# Resources (tiff, plist, icns, rtf, png, script files, etc.)
echo " > Copying vienna/Resources/..."
find "$VIENNA_DIR/Resources" -maxdepth 1 -type f \
  ! -name "Vienna-Info.plist" \
  -exec cp {} "$META_DIR/resources/" \;

# Pre-compiled NIBs from Interfaces/
echo " > Copying vienna/Interfaces/ NIBs..."
find "$VIENNA_DIR/Interfaces" -maxdepth 1 -name "*.nib" -type d \
  -exec cp -r {} "$META_DIR/resources/" \;

# lproj bundles from lproj/
echo " > Copying vienna/lproj/ bundles..."
for d in "$VIENNA_DIR/lproj/"*.lproj; do
  cp -r "$d" "$META_DIR/resources/"
done

# SyntaxHighlighter
[ -d "$VIENNA_DIR/SyntaxHighlighter" ] && \
  cp -r "$VIENNA_DIR/SyntaxHighlighter" "$META_DIR/resources/"

# SharedSupport — Styles and Plugins (no scripts subdir in 3.0.8)
echo " > Copying vienna/SharedSupport/..."
[ -d "$VIENNA_DIR/SharedSupport/Styles" ] && \
  cp -r "$VIENNA_DIR/SharedSupport/Styles" "$META_DIR/resources/"
[ -d "$VIENNA_DIR/SharedSupport/Plugins" ] && \
  cp -r "$VIENNA_DIR/SharedSupport/Plugins" "$META_DIR/resources/"

# Custom resources (override if needed)
echo " > Copying src/resources/..."
find "$SRC_DIR/resources" -maxdepth 1 -type f -exec cp {} "$META_DIR/resources/" \;

# Apply patches
echo " > Applying patches..."
bash "$SRC_DIR/scripts/apply_patches.sh"

touch "$META_DIR/.stamp"
echo "=== Staging Complete ==="
