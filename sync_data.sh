#!/bin/bash
# Copy user data from Godot user:// into data/ for git tracking
SRC="$APPDATA/Godot/app_userdata/Synth Fleet"
DEST="$(dirname "$0")/data"

# Categories to sync (just the JSON content, skip logs/shader_cache/vulkan)
DIRS="weapons ships loadouts projectile_styles power_cores devices flight_paths settings"

for dir in $DIRS; do
    if [ -d "$SRC/$dir" ]; then
        mkdir -p "$DEST/$dir"
        cp "$SRC/$dir/"*.json "$DEST/$dir/" 2>/dev/null
    fi
done

# Top-level save
[ -f "$SRC/save_data.json" ] && cp "$SRC/save_data.json" "$DEST/"

echo "Synced user data → data/"
