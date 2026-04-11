#!/bin/bash
# generate_patches.sh — Diff build-stage/ against originals and save patches.
#
# Run after editing files in build-stage/. Saves diffs to patches/.
# Files identical to their original have their patch removed.
#
# Priority: if a file exists in src/compat/, it is diffed against src/compat/
# (saved to patches/compat/). Otherwise diffed against vienna/ (patches/vienna/).

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STAGE_DIR="$REPO_ROOT/build-stage"
PATCHES_DIR="$REPO_ROOT/patches"
VIENNA_DIR="$REPO_ROOT/vienna"
DEPS_DIR="$REPO_ROOT/deps"
COMPAT_DIR="$REPO_ROOT/src/compat"

if [ ! -f "$STAGE_DIR/.stamp" ]; then
  echo "Error: build-stage/ not found. Run 'make stage' first."
  exit 1
fi

# Save or remove a patch for one file.
# Args: orig, staged, patch_file, header_prefix
save_patch() {
  local orig="$1" staged="$2" patch_file="$3" prefix="$4"
  local name; name="$(basename "$orig")"

  if diff -q "$orig" "$staged" > /dev/null 2>&1; then
    if [ -f "$patch_file" ]; then
      rm "$patch_file"
      echo "   - $name.patch (removed — identical to original)"
    fi
    return
  fi

  local tmp; tmp="$(mktemp)"
  diff -u "$orig" "$staged" \
    | sed "1s|.*|--- ${prefix}${name}|; 2s|.*|+++ ${prefix}${name}|" \
    > "$tmp"

  # Skip write if only the header timestamps changed (body is identical)
  if [ -f "$patch_file" ] && diff -q <(tail -n +3 "$patch_file") <(tail -n +3 "$tmp") > /dev/null 2>&1; then
    rm "$tmp"
    echo "   = $name.patch (unchanged)"
    return
  fi

  mkdir -p "$(dirname "$patch_file")"
  mv "$tmp" "$patch_file"
  echo "   + $name.patch"
}

echo "=== Generating Patches ==="

echo " > build-stage/source/ vs compat/ and vienna/"
find "$STAGE_DIR/source" -maxdepth 1 -type f \( -name "*.m" -o -name "*.h" -o -name "*.c" \) | sort | while read -r f; do
  name="$(basename "$f")"
  if [ -f "$COMPAT_DIR/$name" ]; then
    # Compat file — diff against src/compat/ original
    save_patch "$COMPAT_DIR/$name" "$f" "$PATCHES_DIR/compat/${name}.patch" "compat/"
  elif [ -f "$VIENNA_DIR/$name" ]; then
    # Vienna file — diff against vienna/ original
    save_patch "$VIENNA_DIR/$name" "$f" "$PATCHES_DIR/vienna/${name}.patch" "vienna/"
  fi
done

echo " > build-stage/deps/JSONKit/ vs deps/JSONKit/"
if [ -f "$STAGE_DIR/deps/JSONKit/JSONKit.m" ]; then
  save_patch "$DEPS_DIR/JSONKit/JSONKit.m" "$STAGE_DIR/deps/JSONKit/JSONKit.m" \
    "$PATCHES_DIR/deps/JSONKit.m.patch" ""
fi

echo " > build-stage/resources/ vs vienna/ (plist only)"
find "$STAGE_DIR/resources" -maxdepth 1 -type f -name "*.plist" | sort | while read -r f; do
  orig="$VIENNA_DIR/$(basename "$f")"
  [ -f "$orig" ] || continue
  save_patch "$orig" "$f" "$PATCHES_DIR/resources/$(basename "$f").patch" ""
done

echo " > Info.plist"
if [ -f "$STAGE_DIR/Info.plist" ]; then
  save_patch "$VIENNA_DIR/Info.plist" "$STAGE_DIR/Info.plist" "$PATCHES_DIR/Info.plist.patch" ""
fi

echo "=== Done ==="
