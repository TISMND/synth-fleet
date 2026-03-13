# Synth Fleet — Complete Rebuild Prompt

## How to Use This Document

This is the master specification for rebuilding Synth Fleet from scratch. It is organized into **phases** that should be built in order — each phase produces a working, testable state before moving on.

**Before you start:** Explore the existing codebase for reference (especially things that work well), but do NOT modify the existing code. Build fresh in a new project directory. **Do not delete `res://assets/audio/samples/`** — copy those files into the new project.

**Development philosophy:** Everything is a dev tool right now. Even the Play screen is a test sandbox. Nothing is player-facing yet. Build for developer iteration speed, not polish.

---

## Architecture Decisions (Non-Negotiable)

### Save Format: JSON (Not .tres)
All dev-created content (weapons, ships, patterns, settings) is saved as **JSON files** in `user://` subdirectories. Godot Resource classes still exist for type safety in code, but they are populated at runtime by a thin JSON loader — never serialized as `.tres`.

**Why:** Claude Code consistently produces type errors when writing `.tres` files. JSON is something both the in-game editors and Claude Code can read/write reliably.

**Implementation pattern:**
```
user://weapons/       → weapon definition JSON files
user://ships/         → ship definition JSON files  
user://loadouts/      → player loadout JSON files
user://settings/      → global settings (BPM, aesthetic config)
```

Each domain gets a **DataManager** singleton or static class that handles:
- `save(id, data_dict)` → writes JSON to the appropriate directory
- `load(id)` → reads JSON, returns populated Resource object
- `load_all()` → scans directory, returns array of Resources
- `delete(id)` → removes the JSON file

### Single Source of Truth
The data flow is strictly one-directional:

```
Dev Studio (Weapon Builder) → saves weapon JSON
                                    ↓
Loadout Screen → reads available weapons from JSON, saves loadout JSON
                                    ↓  
Play Sandbox → reads loadout JSON → loads referenced weapon JSONs → plays
```

Nothing is hardcoded. If it doesn't exist as a saved JSON file, it doesn't exist in the game.

### Autoload Singletons
Three singletons, same as before but cleaned up:

1. **BeatClock** — Musical timing. BPM is a global dev setting (stored in `user://settings/beat_clock.json`), eventually per-level. Emits `beat_hit(beat_index)` and `measure_hit(measure_index)`. Compensates for AudioServer latency.

2. **AudioManager** — Sound playback via pooled AudioStreamPlayer nodes on the "SFX" bus. No hardcoded color-to-sample mapping. Weapons specify their own audio sample path and pitch. `play_weapon_sound(sample_path, pitch)` is the core method.

3. **GameState** — Persistent state. Credits, owned weapon IDs, owned ship IDs, current loadout, stats. Loads/saves from `user://save_data.json`. References weapons and ships by ID — the actual data lives in their own JSON files.

### Display & Rendering
- 1920×1080 viewport, `canvas_items` stretch mode
- Nearest-neighbor filtering (pixelated/neon aesthetic)
- Black clear color
- GL Compatibility renderer

---

## Phase 1: Foundation

**Goal:** Autoloads work, JSON save/load works, BeatClock ticks, main menu exists with three buttons that navigate to placeholder screens.

### Tasks:
- Create new Godot 4.x project with the display settings above
- Copy `res://assets/audio/samples/` from old project
- Implement **BeatClock** autoload:
  - Configurable BPM (load from `user://settings/beat_clock.json`, default 120)
  - `_process(delta)` accumulator with AudioServer latency compensation
  - Signals: `beat_hit(beat_index)`, `measure_hit(measure_index)` (every 4 beats)
  - Methods: `get_beat_duration()`, `get_subdivision_duration(subdivision)`
- Implement **AudioManager** autoload:
  - Pool of 16 AudioStreamPlayer nodes on "SFX" bus
  - `play_weapon_sound(sample_path: String, pitch: float)` — loads sample from path, plays at pitch
  - No hardcoded mappings. The weapon data tells it what to play.
- Implement **GameState** autoload:
  - Loads/saves `user://save_data.json`
  - Tracks: credits, owned_weapon_ids (Array), owned_ship_ids (Array), current_loadout_id (String), stats dict
  - References only — actual weapon/ship data lives in their own JSON files
- Implement **JSON DataManager** pattern:
  - `WeaponDataManager` — reads/writes `user://weapons/*.json`
  - `ShipDataManager` — reads/writes `user://ships/*.json`
  - `LoadoutDataManager` — reads/writes `user://loadouts/*.json`
  - Each manager: `save(id, dict)`, `load(id) → Resource`, `load_all() → Array`, `delete(id)`
- Implement **Main Menu** scene:
  - Three buttons: PLAY, LOADOUT, DEV STUDIO
  - Scene transitions to placeholder scenes for each
  - DEV STUDIO button leads to a tabbed container (tabs are placeholders for now)
- Set up input mappings:
  - Movement: WASD / Arrow keys
  - Quit: ESC
  - Menu: M
  - Hardpoint toggles: 1-9 (number keys)
  - All hardpoints up one stage: R
  - All hardpoints down one stage: F
  - All hardpoints off: C
  - All hardpoints on + max stage: Space

### Verify before moving on:
- BeatClock ticks at correct BPM, signals fire reliably
- AudioManager plays a sample from `res://assets/audio/samples/` at various pitches
- JSON round-trips correctly (save → quit → relaunch → load)
- Menu navigation works between all screens

---

## Phase 2: Weapon Data & Weapon Builder (Dev Studio Tab 1)

**Goal:** Devs can create and save weapons with full visual/audio configuration through an in-game editor.

### Weapon Data Schema (JSON):
```json
{
  "id": "laser_pulse_01",
  "display_name": "Neon Pulse",
  "description": "Fast-firing cyan pulse weapon",
  "color": "#00FFFF",
  "damage": 10,
  "projectile_speed": 600,
  "power_cost": 5,
  "audio_sample_path": "res://assets/audio/samples/synth_pulse.wav",
  "audio_pitch": 1.0,
  "fire_pattern": "single",
  "effect_profile": {
    "motion": { "type": "none", "params": {} },
    "muzzle": { "type": "radial_burst", "params": { "particle_count": 6, "lifetime": 0.3 } },
    "shape": { "type": "orb", "params": { "radius": 4, "glow_width": 3.0, "glow_intensity": 0.8 } },
    "trail": { "type": "particle", "params": { "amount": 8, "lifetime": 0.2 } },
    "impact": { "type": "burst", "params": { "particle_count": 8, "lifetime": 0.4 } }
  },
  "special_effect": "none"
}
```

### EffectProfile Layers (same five as before):
1. **Motion** — none, sine_wave, corkscrew, wobble (params: amplitude, frequency, phase_offset)
2. **Muzzle** — none, radial_burst, directional_flash, ring_pulse, spiral_burst (params: particle_count, lifetime, spread_angle)
3. **Shape** — rect, streak, orb, diamond, arrow, pulse_orb (params: width, height, radius, glow_width, glow_intensity, core_brightness)
4. **Trail** — none, particle, ribbon, afterimage, sparkle, sine_ribbon (params: amount, lifetime, width_start, width_end)
5. **Impact** — none, burst, ring_expand, shatter_lines, nova_flash, ripple (params: particle_count, lifetime, radius)

### Fire Patterns:
single, burst, dual, wave, spread, beam, scatter

### Special Effects (placeholder slot — just store the string for now, no implementation):
"none", "disable_shields", "disable_weapons", "drain_shields_for_power"

### Weapon Builder UI:
- **Left panel:** Live SubViewport preview showing the weapon firing, with audio. Synced to BeatClock. Shows projectile with full effect stack (motion, muzzle, shape, trail, impact).
- **Right panel (scrollable form):**
  - Weapon name (text input)
  - Color picker (sets the weapon's color — this is NOT on the loadout screen)
  - Combat stats: damage, projectile_speed, power_cost (sliders with numeric readout)
  - Fire pattern dropdown
  - Audio: sample selector (dropdown of files in `res://assets/audio/samples/`), pitch slider, preview play button
  - Special effect dropdown (placeholder, just stores the value)
  - One section per EffectProfile layer, each with:
    - Type dropdown
    - Dynamically generated parameter sliders based on selected type
- **Save button** — saves to `user://weapons/{id}.json` via WeaponDataManager
- **Load dropdown** — lists all saved weapons, loads one for editing
- **Delete button** — with confirmation

### Verify before moving on:
- Can create a weapon, configure all parameters, see live preview with audio
- Save, quit, relaunch, weapon persists and loads correctly
- Multiple weapons can coexist in `user://weapons/`
- Changing effect profile layers updates preview in real-time

---

## Phase 3: Ship Builder (Dev Studio Tab 3)

**Goal:** Devs can draw ship outlines on a grid and place hardpoints. Ships are saved as JSON.

### Ship Data Schema (JSON):
```json
{
  "id": "player_interceptor_01",
  "display_name": "Interceptor",
  "type": "player",
  "grid_size": [32, 32],
  "lines": [
    { "from": [16, 0], "to": [24, 12], "color": "#00FFFF" },
    { "from": [24, 12], "to": [28, 28], "color": "#00FFFF" }
  ],
  "hardpoints": [
    { "id": "hp_1", "label": "Forward", "grid_pos": [16, 4], "direction_deg": 0 },
    { "id": "hp_2", "label": "Left Wing", "grid_pos": [8, 16], "direction_deg": -30 },
    { "id": "hp_3", "label": "Right Wing", "grid_pos": [24, 16], "direction_deg": 30 }
  ],
  "stats": {
    "hull_max": 100,
    "shield_max": 50,
    "speed": 400,
    "generator_power": 10
  }
}
```

### Ship Builder UI:
- **Center:** Grid canvas (clickable). Dev draws lines by clicking start and end points. Lines render in the neon/synthwave style.
- **Mirror button:** Toggles horizontal symmetry — lines drawn on one side auto-mirror to the other.
- **Hardpoint placement mode:** Click a grid cell to place a hardpoint marker. Set label and default direction via a small popup.
- **Right panel:** Ship name, type toggle (player/enemy), stat sliders (hull, shield, speed, generator_power).
- **Ship preview** that renders the current design with neon glow.
- Save/Load/Delete same pattern as weapon builder.
- `type` field distinguishes player ships from enemy ships. Both are built with the same tool.

### Verify before moving on:
- Can draw a ship outline, place hardpoints, save and reload
- Mirror mode works correctly
- Multiple ships can be saved
- Both player and enemy ship types work

---

## Phase 4: Loadout Screen — Weapon Sequencer

**Goal:** Player assigns weapons to hardpoints and composes rhythm patterns per stage. This is the musical heart of the game.

### Loadout Data Schema (JSON):
```json
{
  "id": "loadout_alpha",
  "ship_id": "player_interceptor_01",
  "hardpoint_assignments": {
    "hp_1": {
      "weapon_id": "laser_pulse_01",
      "stages": [
        {
          "stage_number": 1,
          "loop_length": 8,
          "pattern": [
            { "slot": 0, "pitch_offset": 0 },
            {},
            { "slot": 2, "pitch_offset": 2 },
            {},
            { "slot": 4, "pitch_offset": 0 },
            {},
            { "slot": 6, "pitch_offset": -2 },
            {}
          ]
        },
        {
          "stage_number": 2,
          "loop_length": 16,
          "pattern": [ "...16 slots..." ]
        }
      ]
    },
    "hp_2": {
      "weapon_id": "force_wave_03",
      "stages": [ "..." ]
    }
  }
}
```

### Key Concepts:
- **Weapon type per hardpoint:** Each hardpoint is assigned ONE weapon (chosen from what devs built in Weapon Builder). The weapon's color, sound, visuals are already locked — the player doesn't change those here.
- **Pitch offset from middle C:** Vertical axis on the sequencer grid. Higher pitch = more damage and more power consumption. Lower pitch = less damage, less power. The scaling formula should be configurable but start with something like: `damage_multiplier = 1.0 + (pitch_offset * 0.1)`, `power_multiplier = 1.0 + (abs(pitch_offset) * 0.08)`.
- **Stages (up to 3 per hardpoint):** Each stage is an independent pattern with its own loop length. Stage 1 might be a simple 8-slot "intro beat." Stage 2 might be a 16-slot melody. Stage 3 might be a 32-slot intense riff.
- **Loop length is freely configurable per stage** — not locked to powers of 2, though powers of 2 are recommended. Minimum 4 slots, maximum 64.
- **Slots represent eighth notes** relative to BeatClock's BPM.

### Loadout Screen UI:
- **Top bar:** Ship selector dropdown (lists saved ships), Loadout name, Save/Load controls.
- **Left panel:** Live SubViewport preview of the ship firing the current hardpoint's current stage pattern, synced to BeatClock. Audio plays.
- **Hardpoint selector:** Buttons for each hardpoint on the selected ship (e.g., "HP1: Forward", "HP2: Left Wing"). Selecting one opens its config.
- **Per-hardpoint config:**
  - Weapon selector dropdown (lists all weapons from `user://weapons/`)
  - Stage tabs (Stage 1 / Stage 2 / Stage 3, with + to add, can delete stages)
  - Per stage:
    - Loop length slider/spinner (4-64 slots)
    - **Piano roll grid:** Columns = slots (time), Rows = pitch offsets (vertical, centered on middle C). Click to place/remove notes. Notes render in the weapon's assigned color.
    - Animated cursor showing current playback position
- **Bottom status:** Shows calculated power consumption for the current stage, total power across all hardpoints at max stage.

### Verify before moving on:
- Can select a ship, assign weapons to hardpoints
- Can compose patterns on the piano roll with pitch offsets
- Can create multiple stages per hardpoint with different loop lengths
- Live preview plays the pattern with correct audio and timing
- Save, quit, relaunch — loadout persists
- Loadout only offers weapons that exist in `user://weapons/`
- Loadout only offers ships that exist in `user://ships/`

---

## Phase 5: Play Sandbox

**Goal:** Playable test screen that uses the loadout. Hardpoints controlled by keyboard. Enemies spawn for target practice.

### Player Ship:
- Renders using the ship's line data from Ship Builder (neon polyline style)
- WASD/Arrow movement, clamped to viewport with 16px inset, `move_and_slide()` at ship's speed stat
- Health: hull (doesn't regen) + shield (regens after 2s cooldown at configurable rate). Shield absorbs first, overflow hits hull.
- Energy: max = `generator_power * 5`, regen = `generator_power` per second. Weapons consume energy per shot.

### Hardpoint Stage System (keyboard controls):
- **Number keys 1-9:** Toggle individual hardpoints. Press once = Stage 1 starts firing. Press again = Stage 2. Again = Stage 3. Again = OFF. Cycles: Off → 1 → 2 → 3 → Off.
- **R:** Raise ALL active hardpoints by one stage (caps at max, does NOT activate inactive hardpoints).
- **F:** Lower ALL active hardpoints by one stage (caps at OFF — stage 0 means off).
- **C:** All hardpoints OFF immediately.
- **Space:** All hardpoints ON, set to max stage.

### Weapons at Runtime:
- Each hardpoint runs its assigned weapon's current stage pattern
- Pattern loops continuously while the hardpoint is active
- BeatClock drives timing — slots are eighth notes
- On each slot that has a note:
  - Check energy — skip if insufficient
  - Spend energy (base power_cost × power_multiplier from pitch offset)
  - Spawn projectile with weapon's effect profile (shape, motion, trail)
  - Play weapon's audio sample at calculated pitch (base pitch + pitch_offset in semitones)
  - Trigger muzzle effect
- Projectile moves in the hardpoint's direction at weapon's projectile_speed
- On collision with enemy: deal damage (base damage × damage_multiplier from pitch offset), trigger impact effect, despawn projectile

### Enemies (minimal for sandbox):
- Use EnemyBase with configurable health, speed, credit value
- EnemySpawner: timer-based, random X across top of screen, drift downward
- On death: spawn death effect, award credits to GameState
- One enemy type is fine for now — the system should be ready for enemy ships built in Ship Builder later

### HUD:
- Hull bar (red), Shield bar (blue), Energy bar (yellow/green) — right side of screen
- Hardpoint status display: show which hardpoints are active and their current stage number (small indicators, maybe across the top or bottom)
- Connected to player signals: `health_changed`, `energy_changed`, `hardpoint_stage_changed`

### Parallax Background:
- Simple scrolling starfield or grid, neon aesthetic

### Verify before moving on:
- Ship renders from ship data, weapons fire from hardpoint positions
- Stage cycling works with number keys, R, F, C, Space
- Different stages play different patterns audibly and visibly
- Energy drains and regenerates correctly
- Enemies take damage, die, award credits
- HUD reflects all state changes in real-time
- Changing loadout (going back to Loadout screen, making changes, returning to Play) reflects immediately

---

## Phase 6: Aesthetic Workshop (Dev Studio Tab 4)

**Goal:** Global visual tuning — glow, shaders, neon styling. Dev auditions looks, picks favorites.

### Workshop UI:
- **Left panel:** Multiple preview panels (2x2 grid) showing ship, enemy, and projectiles with different glow presets. Each panel has a label (e.g., "Tight," "Wide," "Intense," "Flicker").
- **Right panel tabs:**
  - **General:** Sliders and color pickers for global glow parameters — glow width, intensity, core brightness, pass count, pulse strength, base colors. Changes update all preview panels in real-time.
  - **Presets:** Save/load named aesthetic presets to `user://settings/aesthetic_presets/`
- Settings saved to `user://settings/aesthetic.json` and applied globally.

### Verify before moving on:
- Glow/visual changes are visible in real-time across preview panels
- Settings persist across sessions
- Aesthetic settings apply to the Play sandbox

---

## Phase 7: Polish & Integration

**Goal:** Make sure everything talks to everything correctly. Clean up rough edges.

- Full data flow test: Build weapon → Build ship → Create loadout with weapon on ship → Play sandbox with that loadout → Modify weapon in builder → Verify change appears in Play
- Device Builder tab: placeholder UI with "Coming Soon" message
- Collision layers: Player (1), Player Projectiles (2), Enemies (4) — same as before
- Save system stress test: many weapons, many ships, multiple loadouts
- Scene transition cleanup: no orphan nodes, no signal leaks
- Console error audit: zero errors/warnings during normal flow

---

## General Rules for Claude Code

1. **Explore the old codebase first** for patterns that worked. Reference it, don't copy it wholesale.
2. **JSON for all dev content.** No `.tres` files for weapons, ships, loadouts, or settings. Resource classes exist in GDScript for type safety but are populated from JSON at runtime.
3. **Single source of truth.** Weapons exist in `user://weapons/`. Ships in `user://ships/`. Loadouts in `user://loadouts/`. Nothing is hardcoded. If the file doesn't exist, the thing doesn't exist.
4. **Test each phase before moving to the next.** Each phase has verification criteria — hit them.
5. **GDScript type hints everywhere.** `var speed: float = 400.0`, not `var speed = 400`. This prevents the "variable does not have a type" errors we kept hitting.
6. **Signals over polling.** Use Godot's signal system for communication between systems.
7. **call_deferred for cross-node setup** when you run into ready-order issues (e.g., HUD connecting to Player).
8. **Keep audio samples in `res://assets/audio/samples/`.** Do not move, rename, or delete them.
9. **BPM is a global dev setting for now** (stored in `user://settings/beat_clock.json`). Architecture should support per-level BPM later.
10. **This is a dev sandbox.** Don't waste time on polish, menus transitions, or juice. Functionality and correct data flow are what matter.
