#!/usr/bin/env bash
set -euo pipefail

# sync_utils.sh - Copy xiaomi_utils.lua and zigbee_utils.lua from root to all subdriver src/ directories
# This is needed because luacheck doesn't work well with symlinks.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

UTILS_FILES=("xiaomi_utils.lua" "zigbee_utils.lua")

echo "=== Syncing xiaomi_utils.lua and zigbee_utils.lua to subdrivers ==="
echo "Repo root: $REPO_ROOT"
echo ""

synced_count=0
skipped_count=0

# Find all directories that have a src/ folder (subdrivers)
for driver_dir in "$REPO_ROOT"/*/; do
    # Skip if not a directory
    [[ -d "$driver_dir" ]] || continue

    src_dir="${driver_dir}src"
    
    # Skip if no src/ directory
    [[ -d "$src_dir" ]] || continue
    
    driver_name="$(basename "$driver_dir")"
    
    for utils_file in "${UTILS_FILES[@]}"; do
        source_file="$REPO_ROOT/$utils_file"
        dest_file="$src_dir/$utils_file"
        
        # Skip if source doesn't exist
        if [[ ! -f "$source_file" ]]; then
            echo "  [SKIP] $source_file not found"
            ((skipped_count++)) || true
            continue
        fi
        
        # Copy the file (overwrite if exists)
        cp "$source_file" "$dest_file"
        echo "  [SYNC] $utils_file -> $src_dir/"
        ((synced_count++)) || true
    done
done

echo ""
echo "=== Summary ==="
echo "Synced: $synced_count files"
echo "Skipped: $skipped_count files"
echo "Done!"
