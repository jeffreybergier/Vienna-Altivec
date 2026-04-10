#!/bin/bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PATCHES_DIR="$REPO_ROOT/patches"
META_DIR="$REPO_ROOT/build-stage"

apply_dir() {
  local patches_subdir="$1"
  local target_dir="$2"
  local strip="$3"
  [ -d "$patches_subdir" ] || return 0
  pushd "$target_dir" > /dev/null
  find "$patches_subdir" -name "*.patch" | sort | while read -r p; do
    echo "   > $(basename "$p")"
    patch -s -p"$strip" < "$p" || echo "     ! Warning: failed $(basename "$p")"
  done
  popd > /dev/null
}

echo "=== Applying Patches ==="

echo " > patches/vienna/ → build-stage/source/"
apply_dir "$PATCHES_DIR/vienna" "$META_DIR/source" 1

echo " > patches/deps/ → build-stage/deps/JSONKit/"
apply_dir "$PATCHES_DIR/deps" "$META_DIR/deps/JSONKit" 0

echo " > patches/resources/ → build-stage/resources/"
apply_dir "$PATCHES_DIR/resources" "$META_DIR/resources" 0

if [ -f "$PATCHES_DIR/Info.plist.patch" ]; then
  echo " > Info.plist"
  pushd "$META_DIR" > /dev/null
  patch -s -p0 < "$PATCHES_DIR/Info.plist.patch" || echo "     ! Warning: failed Info.plist.patch"
  popd > /dev/null
fi

echo "=== Done ==="
