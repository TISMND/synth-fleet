# Synth Fleet — Project Guide

## What is this?
A Tyrian-style vertical scrolling shooter built in Godot 4.6 / GDScript. Core mechanic: weapons fire on a beat grid, and players choose the sound/color of their projectiles, so gameplay produces coherent 80s synth music.

## Running
- Open in Godot 4.6
- Main scene: `scenes/main.tscn`
- Run with Cmd+B (macOS) or the play button in the Godot editor

## Current status
Project scaffolding is complete. The game runs: player ship moves, background scrolls, enemies spawn and drift down, forward weapon fires projectiles on every beat. Everything uses placeholder visuals (colored polygons/rects).

**What works:**
- Player movement (WASD / arrows), clamped to screen
- BeatClock running at 120 BPM, weapon fires on beat
- Enemies spawn, drift down, can be hit by projectiles
- Parallax scrolling background
- Shield/hull health system (not yet visible via HUD)
- GameState save/load to user://
- WeaponData resource class + basic_pulse.tres starter weapon

**What's next (rough priority):**
1. Audio samples — add synth one-shots to `assets/audio/samples/`, wire up color→sample mapping so weapons make sound
2. HUD — health bar, credits display, beat indicator
3. More enemy types + actual wave/level design
4. Shop UI between levels
5. Additional weapons with different subdivisions/patterns
6. Real sprite art to replace placeholder polygons
7. Background music tracks per level

## Architecture

### Autoloads (singletons, always available)
- **BeatClock** — Musical clock. Everything syncs to `beat_hit` / `measure_hit` signals. Each level sets its own BPM.
- **GameState** — Persistent player data (credits, loadout, owned items). Saves to `user://save_data.json`.
- **AudioManager** — Pooled audio playback. Maps weapon colors → audio samples. Weapons call `AudioManager.play_color()` on fire.

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
- Weapons fire on BeatClock subdivisions (quarter/eighth/triplet), NOT on input
- Player chooses weapon color = chooses the synth sound that plays
- 3 long levels, fixed BPM each. No dynamic tempo.
- Health = shields (regen) + hull (doesn't). Generator = simple power budget limiting equipped weapons.
- Shop between levels/deaths for weapons, upgrades, ships

### Directory layout
```
scenes/          .tscn scene files
  game/          Gameplay scenes (player, enemies, level, projectiles)
  ui/            Menus, HUD, shop
scripts/         .gd scripts
  autoload/      Singletons (BeatClock, GameState, AudioManager)
  player/        Player ship
  weapons/       Weapon base + specifics
  enemies/       Enemy base + specifics
  systems/       Health, shop, scoring, level controller
resources/       .tres/.gd resource definitions (WeaponData, etc.)
assets/          Raw art, audio, fonts
  sprites/
  audio/samples/ Synth one-shots (weapon sounds)
  audio/music/   Background tracks per level
  fonts/
addons/          Editor plugins / dev tools
```

### Collision layers
- Layer 1: Player
- Layer 2: Player projectiles
- Layer 4: Enemies

### Adding a new weapon
1. Create a `WeaponData` resource in `resources/` defining damage, speed, subdivision, colors, cost
2. Optionally subclass `WeaponBase` in `scripts/weapons/` for custom fire patterns
3. Add the weapon ID to `GameState._set_defaults()` if it should be available at start
