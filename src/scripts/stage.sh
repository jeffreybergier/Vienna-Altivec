#!/bin/bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VIENNA_DIR="$REPO_ROOT/vienna"
DEPS_DIR="$REPO_ROOT/deps"
SRC_DIR="$REPO_ROOT/src"
META_DIR="$REPO_ROOT/build-stage"

echo "=== Staging Sources ==="

rm -rf "$META_DIR"
mkdir -p "$META_DIR/source" "$META_DIR/deps" "$META_DIR/resources"

# Vienna source files (.h, .m, .c, .pch)
echo " > Copying vienna/ source..."
find "$VIENNA_DIR" -maxdepth 1 \
  \( -name "*.m" -o -name "*.h" -o -name "*.c" -o -name "*.pch" \) \
  -exec cp {} "$META_DIR/source/" \;

# Vienna bundled deps
[ -d "$VIENNA_DIR/sqlite" ]      && cp -r "$VIENNA_DIR/sqlite"      "$META_DIR/deps/sqlite"
[ -d "$VIENNA_DIR/CurlGetDate" ] && cp -r "$VIENNA_DIR/CurlGetDate" "$META_DIR/deps/CurlGetDate"

# External deps
cp -r "$DEPS_DIR/JSONKit" "$META_DIR/deps/JSONKit"

# Info.plist
cp "$VIENNA_DIR/Info.plist" "$META_DIR/Info.plist"

# Vienna resources
echo " > Copying vienna/ resources..."
find "$VIENNA_DIR" -maxdepth 1 -type f \
  ! -name "Info.plist" \
  ! -name "*.m" ! -name "*.h" ! -name "*.c" ! -name "*.pch" \
  ! -name "Makefile" ! -name "*.mk" ! -name "CMakeLists.txt" \
  ! -name "README*" ! -name "LICENSE*" ! -name ".DS_Store" \
  -exec cp {} "$META_DIR/resources/" \;
for d in Styles scripts palettes Plugins Portable SyntaxHighlighter; do
  [ -d "$VIENNA_DIR/$d" ] && cp -r "$VIENNA_DIR/$d" "$META_DIR/resources/"
done
find "$VIENNA_DIR" -maxdepth 1 -type d \
  \( -name "*.nib" -o -name "*.lproj" -o -name "*.framework" \) \
  -exec cp -r {} "$META_DIR/resources/" \;

# Custom resources
echo " > Copying src/resources/..."
find "$SRC_DIR/resources" -maxdepth 1 -type f -exec cp {} "$META_DIR/resources/" \;

# Apply vienna/deps/resource patches
echo " > Applying patches..."
bash "$SRC_DIR/scripts/apply_patches.sh"

# Compat sources — copy after vienna patches so they always win over Vienna versions
echo " > Copying src/compat/ source..."
find "$SRC_DIR/compat" -maxdepth 1 \( -name "*.m" -o -name "*.h" \) \
  -exec cp {} "$META_DIR/source/" \;

# Apply compat patches on top
echo " > Applying compat patches..."
bash "$SRC_DIR/scripts/apply_patches.sh" --compat-only

touch "$META_DIR/.stamp"
echo "=== Staging Complete ==="
