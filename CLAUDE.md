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
- BeatClock running at level BPM with beat position tracking
- LoopMixer: all loops play simultaneously, mute/unmute for perfect sync
- HardpointController fires projectiles at specific beat positions (fire_triggers)
- Enemies spawn, drift down, can be hit by projectiles
- Parallax scrolling background
- Shield/hull health system with HUD
- GameState save/load to user://
- WeaponData resource with loop_file_path, loop_length_bars, fire_triggers
- Weapon Builder with waveform editor for placing fire triggers
- ThemeManager for visual theming across all screens

**What's next (rough priority):**
1. Add Splice WAV loops to `assets/audio/loops/` and `assets/audio/atmosphere/`
2. Visual polish / aesthetic pass (ThemeManager presets)
3. More enemy types + actual wave/level design
4. Shop UI between levels
5. Additional weapons with different loop lengths/trigger patterns
6. Real sprite art to replace placeholder polygons
7. Level atmosphere loops for background music layers

## Architecture

### Audio Model
All audio loops play simultaneously from level start and are muted/unmuted — never started/stopped — so they stay perfectly in sync. Player creativity = choosing which weapons (= which audio loops) to equip and when to activate/deactivate them during gameplay.

### Autoloads (singletons, always available)
- **BeatClock** — Musical clock with `beat_hit`/`measure_hit` signals, plus continuous `beat_position`/`total_beat_position` tracking. `get_loop_beat_position(loop_length_beats)` for varied-length loops.
- **GameState** — Persistent player data (credits, loadout, owned items). Saves to `user://save_data.json`.
- **AudioManager** — Pooled audio playback for non-loop SFX (impacts, UI clicks).
- **LoopMixer** — Manages N AudioStreamPlayers for loops. All play from bar 1 simultaneously. Mute = `volume_db = -80.0`, unmute = restore volume. API: `add_loop()`, `remove_loop()`, `mute()`, `unmute()`, `start_all()`.
- **ThemeManager** — Color/glow/font theming with presets.

### Godot gotchas
- **Sibling `_ready()` order is not guaranteed.** If node A needs to call a method on sibling node B that uses B's child refs, use `call_deferred()` so B's `_ready()` has run first. Without this, B's `$Child` refs will still be null and you'll get "Nil" property access errors.
- **Integer regen from floats:** `int(rate * delta)` truncates to 0 when `rate * delta < 1`. Use a float accumulator: add `rate * delta` each frame, convert to int when ≥ 1, subtract the int portion.
- **Script inheritance:** Don't use `extends "res://path/to/script.gd"` — it causes "Could not resolve class" errors. Instead, give the base script a `class_name` and extend by name (e.g. `class_name MyBase` → `extends MyBase`).
- **NEVER use `:=` when the right-hand side might be `Variant`.** This includes:
  1. **Dictionary values** — `dict[key]`, `dict.get()`, `dict.values()`, `for key in dict:`
  2. **Loosely-typed node access** — `get_parent()` returns `Node`, so `get_parent().some_property` is Variant. Cast first: `var parent: Node2D = get_parent()`
  3. **`load()` / `preload()` return values** — returns `Resource` (Variant-like). Use `as` cast: `var res: AudioStream = load(path) as AudioStream`
  4. **Array element access on untyped Arrays** — `array[i]` when array is `Array` not `Array[Type]`
  5. **Any property access on a base-class-typed variable** when the property only exists on a subclass

  **Always use explicit type annotations instead:** `var x: float = dict["key"]`, `var pos: Vector2 = parent.global_position`, `var res: PackedScene = load(path)`. Wrapping in `int()` / `float()` also works since those return concrete types.

### Key design rules
- Weapons fire at specific beat positions defined by `fire_triggers` (Array[float])
- Each weapon has an audio loop that plays/mutes in sync via LoopMixer
- Player toggles weapons ON/OFF (1-9 keys, Space = all on, C = all off)
- 3 long levels, fixed BPM each. No dynamic tempo.
- Health = shields (regen) + hull (doesn't). Generator = simple power budget limiting equipped weapons.
- Shop between levels/deaths for weapons, upgrades, ships

### WeaponData schema
- `id`, `display_name`, `description`, `color` — identity
- `loop_file_path` — path to Splice WAV (e.g. `res://assets/audio/loops/bass_4bar.wav`)
- `loop_length_bars` — 1, 2, 4, or 8
- `fire_triggers` — Array[float] beat positions where shots fire
- `damage`, `projectile_speed`, `power_cost` — combat stats
- `fire_pattern` — single/dual/spread/burst/scatter/wave/beam
- `effect_profile` — visual effects (motion, muzzle, shape, trail, impact)
- `special_effect` — none/disable_shields/disable_weapons/drain_shields_for_power

### Directory layout
```
scenes/
  ui/            Menus, dev studio, hangar, shop
scripts/
  autoload/      Singletons (BeatClock, GameState, AudioManager, LoopMixer, ThemeManager)
  data/          DataManagers (WeaponDataManager, ShipDataManager, LoadoutDataManager)
  game/          Game logic (game, player_ship, hardpoint_controller, enemy, etc.)
  ui/            UI scripts (main_menu, dev_studio, weapon_builder, waveform_editor, etc.)
resources/       Resource class definitions (.gd) — populated from JSON at runtime
assets/
  audio/loops/       Weapon audio loops (Splice WAVs)
  audio/atmosphere/  Level/boss atmospheric loops (Splice WAVs)
```

### Data storage
All dev-created content is JSON in `user://`:
```
user://weapons/       Weapon definition JSON files
user://ships/         Ship definition JSON files
user://loadouts/      Player loadout JSON files
user://settings/      Global settings (BPM, aesthetics)
user://save_data.json GameState persistence
```

### Collision layers
- Layer 1: Player
- Layer 2: Player projectiles
- Layer 4: Enemies

### Adding a new weapon
1. Use the Weapon Builder in Dev Studio, or save a JSON file to `user://weapons/`
2. Place the weapon's audio loop WAV in `assets/audio/loops/`
3. In Weapon Builder: select loop file, set loop length (bars), click waveform to place fire triggers
4. JSON schema matches `WeaponData` resource class fields
5. Weapons are loaded at runtime via `WeaponDataManager.load_by_id(id)`

### HardpointController
Frame-based trigger checking replaces the old timer-based step sequencer:
- Each frame: get `BeatClock.get_loop_beat_position(loop_length_beats)`, check if any fire trigger was crossed since last frame
- Wrap-around detection: if `curr < prev`, trigger fires if `> prev OR <= curr`
- `activate()` / `deactivate()` / `toggle()` — unmute/mute via LoopMixer
