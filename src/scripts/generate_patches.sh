#!/bin/bash
# generate_patches.sh — Diff build-stage/ against originals and save patches.
#
# Run after editing files in build-stage/. Saves diffs to patches/.
# Files identical to their original have their patch removed.

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STAGE_DIR="$REPO_ROOT/build-stage"
PATCHES_DIR="$REPO_ROOT/patches"
VIENNA_SRC="$REPO_ROOT/vienna/src"
DEPS_DIR="$REPO_ROOT/deps"

if [ ! -f "$STAGE_DIR/.stamp" ]; then
  echo "Error: build-stage/ not found. Run 'make stage' first."
  exit 1
fi

# Save or remove a patch for one file.
# Args: orig, staged, patch_file, header_prefix
save_patch() {
  local orig="$1" staged="$2" patch_file="$3" patchname="$4"
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
    | sed "1s|.*|--- ${patchname}|; 2s|.*|+++ ${patchname}|" \
    > "$tmp"

  # Skip write if only header timestamps changed
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

echo " > build-stage/source/ vs vienna/src/"
find "$STAGE_DIR/source" -type f \( -name "*.m" -o -name "*.h" -o -name "*.c" \) | sort | while read -r f; do
  # Relative path within build-stage/source/ (e.g. "Preferences/Foo.m" or "Bar.m")
  rel="${f#$STAGE_DIR/source/}"
  orig="$VIENNA_SRC/$rel"
  [ -f "$orig" ] || continue
  save_patch "$orig" "$f" "$PATCHES_DIR/vienna/${rel}.patch" "vienna/${rel}"
done

echo " > build-stage/deps/MASPreferences/ vs vienna/Pods/MASPreferences/"
MASPREFERENCES_SRC="$REPO_ROOT/vienna/Pods/MASPreferences"
if [ -d "$STAGE_DIR/deps/MASPreferences" ]; then
  find "$STAGE_DIR/deps/MASPreferences" -type f \( -name "*.m" -o -name "*.h" \) | sort | while read -r f; do
    name="$(basename "$f")"
    orig="$MASPREFERENCES_SRC/$name"
    [ -f "$orig" ] || continue
    save_patch "$orig" "$f" "$PATCHES_DIR/deps/MASPreferences/$name.patch" "$name"
  done
fi

echo " > build-stage/deps/PXListView/ vs vienna/Pods/PXListView/Classes/"
PXLISTVIEW_SRC="$REPO_ROOT/vienna/Pods/PXListView/Classes"
if [ -d "$STAGE_DIR/deps/PXListView" ]; then
  find "$STAGE_DIR/deps/PXListView" -type f \( -name "*.m" -o -name "*.h" \) | sort | while read -r f; do
    name="$(basename "$f")"
    orig="$PXLISTVIEW_SRC/$name"
    [ -f "$orig" ] || continue
    save_patch "$orig" "$f" "$PATCHES_DIR/deps/PXListView/$name.patch" "$name"
  done
fi

echo " > build-stage/deps/ASIHTTPRequest/ vs vienna/Pods/ASIHTTPRequest/Classes/"
ASIHTTP_SRC="$REPO_ROOT/vienna/Pods/ASIHTTPRequest/Classes"
if [ -d "$STAGE_DIR/deps/ASIHTTPRequest" ]; then
  find "$STAGE_DIR/deps/ASIHTTPRequest" -type f \( -name "*.m" -o -name "*.h" \) | sort | while read -r f; do
    name="$(basename "$f")"
    orig="$ASIHTTP_SRC/$name"
    [ -f "$orig" ] || continue
    save_patch "$orig" "$f" "$PATCHES_DIR/deps/ASIHTTPRequest/$name.patch" "$name"
  done
fi

echo " > build-stage/deps/FMDB/ vs deps/fmdb/src/fmdb/"
FMDB_SRC="$REPO_ROOT/deps/fmdb/src/fmdb"
if [ -d "$STAGE_DIR/deps/FMDB" ]; then
  find "$STAGE_DIR/deps/FMDB" -type f \( -name "*.m" -o -name "*.h" \) | sort | while read -r f; do
    name="$(basename "$f")"
    orig="$FMDB_SRC/$name"
    [ -f "$orig" ] || continue
    save_patch "$orig" "$f" "$PATCHES_DIR/deps/FMDB/$name.patch" "$name"
  done
fi

echo " > build-stage/resources/ vs vienna/Resources/ (plist only)"
find "$STAGE_DIR/resources" -maxdepth 1 -type f -name "*.plist" | sort | while read -r f; do
  orig="$REPO_ROOT/vienna/Resources/$(basename "$f")"
  [ -f "$orig" ] || continue
  save_patch "$orig" "$f" "$PATCHES_DIR/resources/$(basename "$f").patch" "$(basename "$f")"
done

echo " > Info.plist"
if [ -f "$STAGE_DIR/Info.plist" ]; then
  save_patch "$REPO_ROOT/vienna/Resources/Vienna-Info.plist" "$STAGE_DIR/Info.plist" \
    "$PATCHES_DIR/Info.plist.patch" "Vienna-Info.plist"
fi

echo "=== Done ==="
