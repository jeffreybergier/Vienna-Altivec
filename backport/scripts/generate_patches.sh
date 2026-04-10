#!/bin/bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
META_DIR="$REPO_ROOT/build-meta"
PATCHES_DIR="$REPO_ROOT/patches"
VIENNA_DIR="$REPO_ROOT/vienna"
BACKPORT_DIR="$REPO_ROOT/backport"
TMP_DIR="$REPO_ROOT/build-meta-tmp"
INJECTED='#import "(Vienna_Prefix\.pch|HelperFunctions\.h|CrossPlatform\.h)"'

echo "=== Generating Patches ==="
rm -rf "$TMP_DIR" && mkdir -p "$TMP_DIR"

# Save a patch for a single file.
# Args: patch_path, label, original_file, meta_file [strip_injected=true]
#   strip_injected: set to "false" for backport/ files whose imports are real, not auto-injected
save_patch() {
    local patch_path="$1" label="$2" original="$3" meta="$4" strip="${5:-true}"
    local staged="$TMP_DIR/staged"

    # Strip injected headers so they don't appear in the patch.
    # Only applies to source/ files — backport/ files own their own imports.
    if [ "$strip" = "true" ]; then
        grep -vE "$INJECTED" "$meta" > "$staged" || true
    else
        cp "$meta" "$staged"
    fi

    local name
    name=$(basename "$patch_path")

    if ! diff -u "$original" "$staged" > "$patch_path.new"; then
        # Rewrite headers to just the filename (for -p0)
        { echo "--- $label"; echo "+++ $label"; tail -n +3 "$patch_path.new"; } > "$patch_path.new2"
        mv "$patch_path.new2" "$patch_path.new"

        # Skip if only timestamps differ (compare body, not first 2 header lines)
        if [ -f "$patch_path" ] && diff -q <(tail -n +3 "$patch_path") <(tail -n +3 "$patch_path.new") > /dev/null 2>&1; then
            rm "$patch_path.new"
            echo "   - $name: skipped: no change"
            return
        fi

        mv "$patch_path.new" "$patch_path"
        echo "   + $name: created patch"
    else
        rm -f "$patch_path.new"
        echo "   - $name: skipped: no difference"
    fi
}

# --- source/ --- (patches use vienna/ prefix, applied with -p1)
echo " > source/"
find "$META_DIR/source" -maxdepth 1 -type f \( -name "*.m" -o -name "*.h" \) | sort | while read -r f; do
    name=$(basename "$f")
    orig="$VIENNA_DIR/$name"
    [ -f "$orig" ] || continue
    save_patch "$PATCHES_DIR/source/$name.patch" "vienna/$name" "$orig" "$f"
done

# --- backport/ --- (backport/ is the original, build-meta/backport/ is modified)
echo " > backport/"
mkdir -p "$PATCHES_DIR/backport"
find "$META_DIR/backport" -maxdepth 1 -type f \( -name "*.m" -o -name "*.h" \) | sort | while read -r f; do
    name=$(basename "$f")
    orig="$BACKPORT_DIR/$name"
    if [ ! -f "$orig" ]; then
        echo "   - $name.patch: skipped: no original in backport/"
        continue
    fi
    save_patch "$PATCHES_DIR/backport/$name.patch" "$name" "$orig" "$f" "false"
done

# --- deps/JSONKit ---
echo " > deps/"
if [ -f "$META_DIR/deps/JSONKit/JSONKit.m" ] && [ -f "$REPO_ROOT/deps/JSONKit/JSONKit.m" ]; then
    save_patch "$PATCHES_DIR/deps/JSONKit.m.patch" "JSONKit.m" "$REPO_ROOT/deps/JSONKit/JSONKit.m" "$META_DIR/deps/JSONKit/JSONKit.m"
fi

# --- resources/ --- (originals come from vienna/; only patch existing files, not new backport additions)
echo " > resources/"
mkdir -p "$PATCHES_DIR/resources"
# Identify which resource files originally came from vienna/ (i.e. also exist in vienna/)
find "$META_DIR/resources" -maxdepth 1 -type f \( -name "*.plist" \) | sort | while read -r f; do
    name=$(basename "$f")
    orig="$VIENNA_DIR/$name"
    [ -f "$orig" ] || continue
    save_patch "$PATCHES_DIR/resources/$name.patch" "$name" "$orig" "$f"
done

rm -rf "$TMP_DIR"
echo "=== Done ==="
