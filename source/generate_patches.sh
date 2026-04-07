#!/bin/bash
set -e

# Directories
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VIENNA_DIR="$REPO_ROOT/vienna"
META_DIR="$REPO_ROOT/build-meta"
PATCHES_DIR="$REPO_ROOT/patches"
TMP_DIR="$REPO_ROOT/build-meta-tmp"

echo "=== Generating Patches from $META_DIR ==="

# 1. Prepare clean staging area
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

# 2. Iterate through all .m, .h, and .plist files in build-meta
find "$META_DIR" -type f \( -name "*.m" -o -name "*.h" -o -name "*.plist" \) | while read -r meta_file; do
    rel_path="${meta_file#$META_DIR/}"
    vienna_file="$VIENNA_DIR/$rel_path"
    
    # Ignore files that don't exist in original vienna (extra components, stubs, etc.)
    [ -f "$vienna_file" ] || continue
    
    # Create staging version without injected headers
    staging_file="$TMP_DIR/$rel_path"
    mkdir -p "$(dirname "$staging_file")"
    
    # Filter out injected headers
    grep -vE '#import "(Vienna_Prefix.pch|HelperFunctions.h|CrossPlatform.h)"' "$meta_file" > "$staging_file"
    
    # Generate unified diff
    patch_name="$(basename "$rel_path").patch"
    patch_path="$PATCHES_DIR/$patch_name"
    
    # diff returns 1 if differences found, which is what we want
    if ! diff -u "$vienna_file" "$staging_file" > "$patch_path.tmp"; then
        # Clean up headers in patch output to be relative to 'vienna/'
        sed -i "s|$vienna_file|vienna/$rel_path|g" "$patch_path.tmp"
        sed -i "s|$staging_file|vienna/$rel_path|g" "$patch_path.tmp"
        mv "$patch_path.tmp" "$patch_path"
        echo "   > Generated $patch_name"
    else
        rm -f "$patch_path.tmp"
    fi
done

# 3. Cleanup
rm -rf "$TMP_DIR"
echo "=== Patch Generation Complete ==="
