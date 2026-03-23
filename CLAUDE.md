# Synth Fleet — Project Guide

## What is this?
A Tyrian-style vertical scrolling shooter built in Godot 4.6 / GDScript. Core mechanic: weapons fire on a beat grid, and each weapon has an associated audio loop (Splice WAV). Equipping and activating weapons layers loops together like a DAW mixer, so gameplay produces coherent 80s synth music.

## Running
- Open in Godot 4.6
- Main scene: `scenes/ui/main_menu.tscn`
- Run with Cmd+B (macOS) or the play button in the Godot editor

## Current status
Game runs with loop-based audio system. Player ship moves, background scrolls, enemies spawn, weapons fire projectiles at beat-synced trigger positions. Weapons mute/unmute audio loops via LoopMixer.

**What works:**
- Player movement (WASD / arrows), clamped to screen
- LoopMixer: all loops play simultaneously, mute/unmute for perfect sync
- HardpointController fires projectiles at normalized time positions via LoopMixer (fire_triggers)
- Enemies spawn with weapons, flight paths, formations; hit by player projectiles
- Enemy weapon system (enemy projectiles, beam projectiles, pulse waves)
- Parallax scrolling background with nebula layers
- Shield/hull/thermal/electric system bars with HUD
- GameState save/load to user://
- Dev Studio with component tabs: Weapons, Beams, Fields, Orbiters, Projectile Animator, Power Cores, Key Changes, Nebulas, Orbital Generators, Field Emitters
- Weapons Tab with subtabs (Timing / Movement / Effects / Stats), waveform editor, loop browser
- Level Editor with encounter placement, wave management
- Level Select and Ship Select screens
- Ships Screen with ship rendering preview, explosion editor
- Hangar Screen for loadout configuration
- Style Editor for live theme editing (Typography, Grid, Buttons, VHS, Panels, Bars, HUD)
- Options Screen with per-bus volume controls
- SFX Editor and VFX Editor
- Movement system: aim modes (fixed/sweep/track), mirror modes (none/mirror/alternate)
- Effect system: muzzle/trail/impact slots with per-layer color, per-trigger overrides
- EffectLayerRenderer: centralized rendering utility
- ThemeManager for visual theming across all screens
- ShipRenderer with procedural ship drawing + skin system
- Audio bus hierarchy (GameAudio→Weapons/SFX/Enemies/Atmosphere, UI→Master)
- KeyBindingManager with customizable slot keybindings

**What's next (rough priority):**
1. Add Splice WAV loops to `assets/audio/loops/` and `assets/audio/atmosphere/`
2. More enemy types + actual wave/level design
3. Shop UI between levels (scene exists, needs build-out)
4. Additional weapons with different loop lengths/trigger patterns
5. Real sprite art to replace placeholder polygons
6. Level atmosphere loops for background music layers
7. HUD segment glow animation rework

## Core Rules
- **PREVIEWS MUST = GAME REALITY.** Editor/dev studio previews must use the exact same rendering code, shaders, and node setup as the actual game. If something looks good in a preview but different in gameplay, that's a bug. Never create separate rendering paths for previews vs game — share the same components (e.g. `FieldRenderer`, `ShipRenderer`, `VFXFactory`). Previews exist to show what the player will actually see.

## Architecture

### Audio Model
All audio loops play simultaneously from level start and are muted/unmuted — never started/stopped — so they stay perfectly in sync. Player creativity = choosing which weapons (= which audio loops) to equip and when to activate/deactivate them during gameplay.

### Autoloads (singletons, always available)
- **GameState** — Persistent player data (credits, loadout, owned items). Saves to `user://save_data.json`.
- **AudioBusSetup** — Creates audio bus hierarchy at startup (GameAudio→Weapons/SFX/Enemies/Atmosphere, UI→Master). Loads saved volumes from `user://settings/audio.json`.
- **AudioManager** — Pooled audio playback for non-loop SFX (impacts, UI clicks).
- **LoopMixer** — Manages N AudioStreamPlayers for loops. All play from bar 1 simultaneously. Mute = `volume_db = -80.0`, unmute = restore volume. API: `add_loop()`, `remove_loop()`, `mute()`, `unmute()`, `start_all()`.
- **ShipRegistry** — Static registry of all 9 player ships with stats (hull/shield/thermal/electric segments, speed, slot counts). Pure code, no JSON.
- **SfxPlayer** — Loads `SfxConfig` and plays one-shot sounds for game events (hits, explosions, UI).
- **KeyBindingManager** — Persists slot key bindings to `user://settings/keybindings.json`. Applies bindings to Godot InputMap at runtime.
- **ThemeManager** — Color/glow/font theming. Single active theme saved to `user://settings/aesthetic.json`. Owns the root `WorldEnvironment` with `glow_enabled = true` — this is the **single bloom source** for everything on screen. SubViewports get ACES tonemapping only (no bloom) via `VFXFactory.add_bloom_to_viewport()`. Helpers: `apply_grid_background()`, `apply_button_style()`, `apply_text_glow()`, `apply_vhs_overlay()`, `apply_led_bar()`, `get_environment()`, `set_glow_enabled()`, color/font/float getters. All screens connect `theme_changed` and call helpers in `_apply_theme()` so changes propagate everywhere.

### Godot gotchas
> Full list with architecture-specific lessons: see `GODOT_GOTCHAS.md`

- **Sibling `_ready()` order is not guaranteed.** Use `call_deferred()` when node A needs sibling node B's children to be ready.
- **Integer regen from floats:** `int(rate * delta)` truncates to 0 when `rate * delta < 1`. Use a float accumulator.
- **Script inheritance:** Don't use `extends "res://path/to/script.gd"`. Give the base script a `class_name` and extend by name.
- **NEVER use `:=` when the right-hand side might be `Variant`.** Dictionary values, `get_parent()`, `load()`, untyped array access. Always use explicit type annotations: `var x: float = dict["key"]`.
- **Custom shaders ignore `modulate`:** Capture `float modulate_alpha = COLOR.a;` at the top of `fragment()` and multiply into final alpha. Without this, `sprite.modulate.a` has zero effect.
- **Saved settings override code defaults.** `user://settings/aesthetic.json` persists ALL values. New ThemeManager keys only use defaults if absent from saved file.
- **Shader/slider parameter minimums must be zero.** Use `max(value, 0.001)` in shader math to guard against division by zero. The user must be able to dial any parameter to zero.

### Vocabulary
- **Style Editor** (`style_editor.*`) — theme editor screen. Not "Aesthetic Studio/Workshop."
- **Ships Screen** (`ships_screen.*`) — ship config/preview. Not "Ship Viewer."
- **System Bars** — shield/hull/thermal/electric bars. Each bar has **segments**.
- `generator_power` is dead — removed stat, do not reintroduce.

### Key design rules
- Weapons fire at specific beat positions defined by `fire_triggers` (Array[float])
- Each weapon has an audio loop that plays/mutes in sync via LoopMixer
- Player toggles weapons ON/OFF (1-9 keys, Space = all on, C = all off)
- Health = shields (regen) + hull (doesn't) + thermal + electric system bars.
- Shop between levels/deaths for weapons, upgrades, ships

### Screen theming pattern
Every UI screen must follow this pattern for full theme consistency:
1. **Grid background** — `ThemeManager.apply_grid_background(bg_rect)` on a full-rect `ColorRect`
2. **VHS/CRT overlay** — `CanvasLayer` at layer 10 with a full-rect `ColorRect` (`mouse_filter = IGNORE`), apply via `ThemeManager.apply_vhs_overlay(overlay)`. For scripts on child nodes (e.g. `Content` MarginContainer), add the CanvasLayer to `get_parent()`.
3. **Button styling** — `ThemeManager.apply_button_style(btn)` on every `Button`
4. **Text glow** — `ThemeManager.apply_text_glow(label, "header"/"body")` on key labels
5. **LED bars** — `ThemeManager.apply_led_bar(bar, color, ratio)` on `ProgressBar` nodes
6. **Fonts/colors** — Use `get_font()`, `get_font_size()`, `get_color()` instead of hardcoded values
7. **`theme_changed` connection** — Connect in `_ready()`, handler re-applies all of the above

### WeaponData schema
- `id`, `display_name`, `description` — identity
- `loop_file_path` — path to Splice WAV (e.g. `res://assets/audio/loops/bass_4bar.wav`)
- `loop_length_bars` — 1, 2, 4, or 8
- `fire_triggers` — Array[float] normalized time positions (0.0–1.0) where shots fire
- `damage`, `projectile_speed` — combat stats
- `fire_pattern` — single/dual/spread/burst/scatter/wave/beam
- `direction_deg` — firing direction in degrees (0 = up)
- `aim_mode` — fixed/sweep/track
- `sweep_arc_deg`, `sweep_duration` — sweep parameters (arc width, seconds per cycle)
- `mirror_mode` — none/mirror/alternate
- `effect_profile` — v2 composable effect layers (see below), only muzzle/trail/impact slots
- `projectile_style_id` — links to ProjectileStyle for visual design (color comes from style)

### Effect Profile (v2)
Format: `{ "version": 2, "defaults": { slot: [layers...] }, "trigger_overrides": { "idx": { slot: [layers...] } } }`

3 weapon-level effect slots (single layer each, with optional per-layer color):
- **muzzle** — particle burst at fire origin. Types: radial_burst, directional_flash, ring_pulse, spiral_burst
- **trail** — trail stream on projectiles. Types: particle, ribbon, afterimage, sparkle, sine_ribbon
- **impact** — explosion on hit. Types: burst, ring_expand, shatter_lines, nova_flash, ripple

Each layer dict may include `"color": [r, g, b, a]` for per-effect color (default white if absent).
Shape and motion are handled by ProjectileStyle / Projectile Animator, not the weapon effect profile.

`trigger_overrides` keyed by trigger index (string). Missing slots inherit from defaults.
v1 profiles (flat `{slot: {type, params}}`) auto-migrate on load via `WeaponData._migrate_effect_profile()`.
`EffectLayerRenderer.resolve_layers(profile, trigger_index)` returns final per-slot layer arrays.

### Directory layout
```
scenes/
  game/          Game scene (game.tscn)
  ui/            Menus, dev studio, hangar, shop, editors
scripts/
  autoload/      Singletons (8 — see list above)
  data/          DataManagers (~19 — WeaponDataManager, ShipDataManager, LevelDataManager, etc.)
  game/          Game logic (game, player_ship, hardpoint_controller, enemy, vfx_factory, etc.)
  rendering/     Ship rendering (ship_renderer, ship_canvas, ship_thumbnails, shield_bubble_effect)
  ui/            UI scripts (~46 — dev_studio, weapons_tab, waveform_editor, level_editor, etc.)
  util/          Utilities (effect_rate_calculator)
resources/       Resource class definitions (.gd) — populated from JSON at runtime
data/            Dev-authored JSON content (weapons, ships, styles, etc.) — git-tracked
assets/
  audio/loops/       Weapon audio loops (Splice WAVs)
  audio/atmosphere/  Level/boss atmospheric loops (Splice WAVs)
  shaders/           90+ .gdshader files (nebula, field, projectile, bar, UI)
  fonts/             TTF fonts (Audiowide, Bungee, Orbitron, RussoOne, ShareTechMono)
```

### Data storage
Dev-created content is JSON in `res://data/` (git-tracked):
```
res://data/weapons/             Weapon definitions
res://data/ships/               Ship definitions (player + enemy)
res://data/beam_styles/         Beam visual styles
res://data/field_emitters/      Field emitter definitions
res://data/field_styles/        Field visual styles
res://data/flight_paths/        Enemy flight paths
res://data/formations/          Enemy formations
res://data/key_changes/         Key change definitions
res://data/levels/              Level definitions
res://data/nebula_definitions/  Nebula definitions
res://data/orbital_generators/  Orbital generator definitions
res://data/power_cores/         Power core definitions
res://data/projectile_styles/   Projectile visual styles
res://data/projectile_masks/    Projectile mask PNGs
res://data/loop_config.json     Global loop config
res://data/sfx_config.json      SFX event mappings
res://data/vfx_config.json      VFX config
```
Player runtime state stays in `user://` (not tracked):
```
user://save_data.json           GameState persistence
user://settings/                Global settings (audio, aesthetics, keybindings)
```

### Collision layers
- Layer 1: Player
- Layer 2: Player projectiles (projectile, beam, pulse_wave)
- Layer 4: Enemies
- Layer 8: Enemy projectiles
- Layer 128: Devices (field emitters)

### Waveform Editor coordinate system
The waveform editor works in **normalized time (0.0–1.0)** internally. Fire triggers are placed, displayed, and stored in normalized time — no beat-space conversion anywhere in the pipeline.

The playback cursor reads `LoopMixer.get_playback_position() / get_stream_duration()` — the same clock source as HardpointController. One clock, zero drift.

Beat grid overlay uses `loop_length_bars` for cosmetic display only (snap lines, bar markers).

Snap modes: Free (click anywhere), 1/4, 1/8, 1/16. Beat grid overlay is optional and visual-only.

### Adding a new weapon
1. Use the Weapons Tab in Dev Studio, or save a JSON file to `res://data/weapons/`
2. Place the weapon's audio loop WAV in `assets/audio/loops/` or `loop_zips/sorted/`
3. In Weapons Tab (Timing subtab): browse loops, waveform auto-loads with real PCM data, click to place fire triggers (Free or snapped)
4. Use Effects subtab for visual effect layers, Stats subtab for combat values
5. JSON schema matches `WeaponData` resource class fields — fire_triggers stored as normalized time (0.0–1.0)
6. Weapons are loaded at runtime via `WeaponDataManager.load_by_id(id)`

### HardpointController
Frame-based trigger checking using LoopMixer as the single clock source:
- Each frame: get `LoopMixer.get_playback_position() / get_stream_duration()` for normalized time (0.0–1.0), check if any fire trigger was crossed since last frame
- Wrap-around detection: if `curr < prev`, trigger fires if `> prev OR <= curr`
- `activate()` / `deactivate()` / `toggle()` — unmute/mute via LoopMixer

### Known Issues
- **Effect rate (seg/min) calculation may be ~2x off for some weapons.** Observed on Charged Ion Pulse (single shot, mirror_mode=none). Displayed rate shows roughly half the actual consumption. Suspect: Godot resource caching — LoopMixer loads WAV and sets `loop_mode = LOOP_FORWARD`, then `EffectRateCalculator.get_loop_duration()` calls `load()` on same path and gets the cached looping stream, where `get_length()` may return a different value. Need to verify: (1) whether discrepancy is in hangar preview or gameplay, (2) print actual WAV durations from both LoopMixer and EffectRateCalculator to compare. Files: `scripts/util/effect_rate_calculator.gd`, `scripts/autoload/loop_mixer.gd`, `scripts/game/hardpoint_controller.gd`.
