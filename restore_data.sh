#!/bin/bash
# Restore user data from repo data/ into Godot user://
SRC="$(dirname "$0")/data"
DEST="$APPDATA/Godot/app_userdata/Synth Fleet"

DIRS="weapons ships loadouts projectile_styles power_cores devices flight_paths settings"

for dir in $DIRS; do
    if [ -d "$SRC/$dir" ]; then
        mkdir -p "$DEST/$dir"
        cp "$SRC/$dir/"*.json "$DEST/$dir/" 2>/dev/null
    fi
done

[ -f "$SRC/save_data.json" ] && cp "$SRC/save_data.json" "$DEST/"

echo "Restored user data → user://"
