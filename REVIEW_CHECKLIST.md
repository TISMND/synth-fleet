# Review Checklist — Commit 9243603+

> **STATUS (2026-03-23):** Partially complete. Most items here have been implemented but not all checkboxes are ticked. See `project_roadmap.md` in memory for the current priority list.

Remaining items from the mega-commit plus new priorities. Check each item, leave notes, mark pass/fail.

---

## 1. Enemy Weapon System (B1 + B4)

- [ ] **EnemyWeaponController** — timer-based firing, supports straight/turret/burst patterns
  - File: `scripts/game/enemy_weapon_controller.gd` (new)
- [ ] **EnemyProjectile** — collision Layer 8, detects Layer 1 (player), glowing line visual, self-destructs on hit or off-screen
  - File: `scripts/game/enemy_projectile.gd` (new)
- [ ] **Enemy integration** — weapon controller spawned in `_ready()` when ShipData has `fire_rate > 0`
  - File: `scripts/game/enemy.gd`
- [ ] **Player collision mask** — updated to `4 | 8` to detect enemy projectiles; guard skips `EnemyProjectile` in `_on_contact()`
  - File: `scripts/game/player_ship.gd`
- [ ] **WaveManager** — passes `proj_container`, `ship_data_ref`, `player_ref`, `weapons_active` to spawned enemies
  - File: `scripts/game/wave_manager.gd`
- [ ] **Game passes projectiles container** to wave manager in `_start_waves()`
  - File: `scripts/game/game.gd`
- [ ] **Level encounter `weapons_active` field** — parsed in `from_dict()`
  - File: `resources/level_data.gd`
- [ ] **Level Editor toggle** — "WEAPONS ACTIVE" checkbox in encounter editor panel
  - File: `scripts/ui/level_editor.gd`

---

## 2. Explosion Effects (E2)

- [ ] **ExplosionEffect class** — central flash, expanding rings, debris lines, GPU particle burst, screen shake, additive blending, HDR colors, auto-cleanup
  - File: `scripts/game/explosion_effect.gd` (new, 270 lines)
- [ ] **Enemy spawns explosion on death** — `_spawn_explosion()` called from `take_damage()` when `health <= 0`
  - File: `scripts/game/enemy.gd`
- [x] **Ships Screen explosion editor** — EXPLOSION section in enemy right panel: color picker, size slider, screen shake toggle, preview button
  - Files: `scripts/ui/ships_screen.gd`, `resources/ship_data.gd`
- [x] **Enemy uses ShipData explosion settings** — `_spawn_explosion()` reads color/size/shake from `ship_data_ref` when available
  - File: `scripts/game/enemy.gd`

---

## 3. Nebula Status Effects (E1)

- [ ] **NebulaData schema** — `bar_effects` (dict of bar_name -> rate/sec), `special_effects` (array of strings)
  - File: `resources/nebula_data.gd`
- [ ] **Game nebula collision** — Area2D per nebula with effects, enter/exit callbacks, per-frame bar drain/fill accumulator
  - File: `scripts/game/game.gd`
- [ ] **Special effects** — cloak (opacity 0.3), slow (speed x0.5), damage_boost (meta flag)
  - File: `scripts/game/game.gd`
- [ ] **Nebulas Tab editor** — bar rate spinboxes (shield/hull/thermal/electric), special effects checkboxes (Cloak/Slow/Damage Boost)
  - File: `scripts/ui/nebulas_tab.gd`

---

## 4. Options Screen (F4)

- [ ] **Options screen** — volume sliders for Master/Weapons/Enemies/Atmosphere/SFX/UI, saves to `user://settings/audio.json`, full theme integration, Escape to return
  - File: `scripts/ui/options_screen.gd` (new, 318 lines)
  - Scene: `scenes/ui/options_screen.tscn`
- [ ] **AudioBusSetup autoload** — creates audio buses at startup if missing, loads saved volumes
  - File: `scripts/autoload/audio_bus_setup.gd` (new)
  - Registered in `project.godot`
- [ ] **Main menu wired up** — `_on_options()` navigates to options screen (was `pass`)
  - File: `scripts/ui/main_menu.gd`

---

## 5. Level Select Screen (F3)

- [x] **White box fix** — detail panel now styled at build time (no flash before theme applies)
  - File: `scripts/ui/level_select_screen.gd`
- [ ] **Play menu link** — "SELECT LEVEL" button navigates to level select
  - Files: `scenes/ui/play_menu.tscn`, `scripts/ui/play_menu.gd`

---

## 6. Hangar Screen Readability (F1)

- [ ] **Color-coded section headers** — "WEAPONS"/"CORES"/"DEVICES" with colored PanelContainer bars
- [ ] **Color-coded slot buttons** — font color tinted by slot type (cyan/yellow/orange)
- [ ] **Enlarged toggle buttons** — 30x30 -> 44x38
- [ ] **Increased spacing** — section separation, slot row heights, mode tab spacing
- [ ] **Theme-aware recoloring** — `_apply_theme()` rewritten for all color-coded elements
  - File: `scripts/ui/hangar_screen.gd`

---

## 7. Ship Renderer Cleanup (C1)

- [ ] **`_make_circle_points()` utility** — generates evenly-spaced polygon points
- [ ] **`_arc()` utility** — draws arcs respecting render modes
- [ ] **Sentinel** — uses `_make_circle_points()` with 32 segments (was 12 inline)
- [ ] **Scythe** — inner edge accent uses `_arc()` helper
  - File: `scripts/rendering/ship_renderer.gd`

---

## 8. Component Tabs: Field Emitters & Orbital Generators (NEW)

- [ ] **Field Emitters tab** — needs design and build-out (barely developed)
- [ ] **Orbital Generators tab** — needs design and build-out (barely developed)
- [ ] **Weapons & generator tweaks** — TBD, needs user guidance on direction
  - _This section will require collaborative discussion before implementation._

---

## Notes / Issues Found

_Write your findings here as you test each section._
