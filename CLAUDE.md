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
- Component Editor tabs: Weapons, Projectiles, Beams, Power Cores, Field Emitters, Fields
- Environments Screen: Nebulas, Key Changes
- Weapons Tab with subtabs (Timing / Movement / Stats), waveform editor, loop browser
- Level Editor with encounter placement, wave management
- Level Select and Ship Select screens
- Ships Screen with ship rendering preview, explosion editor
- Hangar Screen for loadout configuration
- Style Editor for VHS/CRT parameter tuning (other theme values baked via defaults)
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
1. Game loop: victory condition, shop integration, level progression (see TODO.md)
2. Combat feel: ram damage, fragility pass, enemy weapon direction
3. Audio: weapon fade in/out, level atmosphere loops
4. More enemy types + actual wave/level design
5. Real sprite art to replace placeholder polygons

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
- **ThemeManager** — Color/glow/font theming. Single active theme saved to `user://settings/aesthetic.json`. Owns the root `WorldEnvironment` with `glow_enabled = true` — this is the **single bloom source** for everything on screen. SubViewports get ACES tonemapping only (no bloom) via `VFXFactory.add_bloom_to_viewport()`. Helpers: `apply_grid_background()`, `apply_button_style()`, `apply_text_glow()`, `apply_vhs_overlay()`, `apply_led_bar()`, `get_environment()`, color/font/float getters. All screens connect `theme_changed` and call helpers in `_apply_theme()` so changes propagate everywhere.

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
- **Dev Studio** (`dev_studio_menu.*`) — the main menu with buttons for all dev tools. Not a single screen.
- **Component Editor** (`component_editor.*`) — tabbed screen for Weapons, Beams, Fields, Projectiles, Power Cores, etc. Accessed via COMPONENTS button.
- **Environments Screen** (`environments_screen.*`) — Nebulas, Key Changes. Accessed via ENVIRONMENTS button.
- **Style Editor** (`style_editor.*`) — VHS/CRT parameter editor only. Other theme values (colors, fonts, bars, buttons) are baked via ThemeManager defaults + `user://settings/aesthetic.json`.
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

### Schemas and subsystem details
> **Read `SCHEMAS.md`** when working on weapons, effects, the waveform editor, or the hardpoint firing system. It contains WeaponData fields, Effect Profile v2 format, waveform editor coordinate system, and HardpointController trigger logic.

### Directory layout
```
scenes/
  game/          Game scene (game.tscn)
  ui/            Menus, dev studio, hangar, shop, editors
scripts/
  autoload/      Singletons (8 — see list above)
  data/          DataManagers (~19 — WeaponDataManager, ShipDataManager, LevelDataManager, etc.)
  game/          Game logic (game, player_ship, hardpoint_controller, enemy, vfx_factory, etc.)
  rendering/     Ship rendering (ship_renderer, ship_thumbnails)
  test/          Test runner
  ui/            UI scripts (~44 — component_editor, weapons_tab, waveform_editor, level_editor, etc.)
  util/          Utilities (effect_rate_calculator)
resources/       Resource class definitions (.gd) — populated from JSON at runtime
data/            Dev-authored JSON content (weapons, ships, styles, etc.) — git-tracked
assets/
  audio/loops/       Weapon audio loops (Splice WAVs)
  audio/atmosphere/  Level/boss atmospheric loops (Splice WAVs)
  audio/sfx/         Sound effects (hits, explosions, alarms, etc.)
  audio/music/       Music tracks
  audio/samples/     Audio samples
  backgrounds/       Background images
  sprites/           Sprite assets
  vfx/               VFX textures
  shaders/           ~70 .gdshader files (nebula, field, projectile, bar, UI)
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
res://data/power_cores/         Power core definitions
res://data/projectile_styles/   Projectile visual styles
res://data/projectile_masks/    Projectile mask PNGs
res://data/bosses/              Boss definitions
res://data/buildings/           Building definitions
res://data/devices/             Device definitions
res://data/doodads/             Doodad definitions
res://data/items/               Item definitions
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

### Known Issues
- **Effect rate (seg/min) calculation may be ~2x off for some weapons.** Observed on Charged Ion Pulse (single shot, mirror_mode=none). Displayed rate shows roughly half the actual consumption. Suspect: Godot resource caching — LoopMixer loads WAV and sets `loop_mode = LOOP_FORWARD`, then `EffectRateCalculator.get_loop_duration()` calls `load()` on same path and gets the cached looping stream, where `get_length()` may return a different value. Need to verify: (1) whether discrepancy is in hangar preview or gameplay, (2) print actual WAV durations from both LoopMixer and EffectRateCalculator to compare. Files: `scripts/util/effect_rate_calculator.gd`, `scripts/autoload/loop_mixer.gd`, `scripts/game/hardpoint_controller.gd`.
