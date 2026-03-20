# Review Checklist — Commit 9243603

Everything implemented in the "accidental mega-commit." Check each item, leave notes, mark pass/fail.

---

## 1. Audio Fade Transitions (D3)

- [ ] **LoopMixer fade support** — `mute(id, fade_ms)` / `unmute(id, fade_ms)` with Tween interpolation
  - File: `scripts/autoload/loop_mixer.gd`
- [ ] **WeaponData schema** — new `transition_mode` ("instant"/"fade") and `transition_ms` (50-2000) fields
  - File: `resources/weapon_data.gd`
- [ ] **DeviceData schema** — same `transition_mode` and `transition_ms` fields
  - File: `resources/device_data.gd`
- [ ] **HardpointController uses fade** — `_get_audio_fade_ms()` helper, `activate()`/`deactivate()` pass fade to LoopMixer
  - File: `scripts/game/hardpoint_controller.gd`
- [ ] **DeviceController uses fade** — same pattern as HardpointController
  - File: `scripts/game/device_controller.gd`
- [ ] **Weapons Tab UI** — "AUDIO TRANSITION" section in timing subtab (Mode dropdown + Duration slider)
  - File: `scripts/ui/weapons_tab.gd`
- [ ] **Device Tab Base UI** — same transition UI for devices
  - File: `scripts/ui/device_tab_base.gd`

---

## 2. Enemy Weapon System (B1 + B4)

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

## 3. Enemy Presence Audio (B3)

- [ ] **ShipData schema** — new `presence_loop_path` field
  - File: `resources/ship_data.gd`
- [ ] **Game presence tracking** — ref-counted `_presence_counts`/`_presence_loops`, `register`/`unregister` methods, pre-registers loops at level start (muted)
  - File: `scripts/game/game.gd`
- [ ] **Enemy registration** — calls `register_enemy_presence()` in `_ready()`, connects `tree_exiting` to unregister
  - File: `scripts/game/enemy.gd`
- [ ] **Ships Screen UI** — "AUDIO" section with `presence_loop_path` LineEdit for enemies
  - File: `scripts/ui/ships_screen.gd`

---

## 4. Explosion Effects (E2)

- [ ] **ExplosionEffect class** — central flash, expanding rings, debris lines, GPU particle burst, screen shake, additive blending, HDR colors, auto-cleanup
  - File: `scripts/game/explosion_effect.gd` (new, 270 lines)
- [ ] **Enemy spawns explosion on death** — `_spawn_explosion()` called from `take_damage()` when `health <= 0`
  - File: `scripts/game/enemy.gd`

---

## 5. Nebula Status Effects (E1)

- [ ] **NebulaData schema** — `bar_effects` (dict of bar_name -> rate/sec), `special_effects` (array of strings)
  - File: `resources/nebula_data.gd`
- [ ] **Game nebula collision** — Area2D per nebula with effects, enter/exit callbacks, per-frame bar drain/fill accumulator
  - File: `scripts/game/game.gd`
- [ ] **Special effects** — cloak (opacity 0.3), slow (speed x0.5), damage_boost (meta flag)
  - File: `scripts/game/game.gd`
- [ ] **Nebulas Tab editor** — bar rate spinboxes (shield/hull/thermal/electric), special effects checkboxes (Cloak/Slow/Damage Boost)
  - File: `scripts/ui/nebulas_tab.gd`

---

## 6. HUD Rolling Wave Animations (A2)

- [ ] **LED bar shader** — new uniforms (`gain_wave_pos`, `drain_wave_pos`, `wave_intensity`, `wave_width`), `wave_glow()` function, per-segment directional glow (gain = brighten to white, drain = shift to red)
  - File: `assets/shaders/led_bar.gdshader`
- [ ] **HUD wave state** — replaces old `_bar_pulse_brightness` with `_bar_gain_wave`/`_bar_drain_wave` dicts, `trigger_gain_wave()`/`trigger_drain_wave()`, change detection via `_bar_prev_values`
  - File: `scripts/game/hud.gd`

---

## 7. HUD Fixed Segment Sizing (A1)

- [ ] **Bar height from segments** — `seg * seg_px + (seg - 1) * gap_px`, anchored to top of half-panel zone, no stretch
  - File: `scripts/ui/hud_builder.gd`

---

## 8. Options Screen (F4)

- [ ] **Options screen** — volume sliders for Master/Weapons/Enemies/Atmosphere/SFX/UI, saves to `user://settings/audio.json`, full theme integration, Escape to return
  - File: `scripts/ui/options_screen.gd` (new, 318 lines)
  - Scene: `scenes/ui/options_screen.tscn`
- [ ] **AudioBusSetup autoload** — creates audio buses at startup if missing, loads saved volumes
  - File: `scripts/autoload/audio_bus_setup.gd` (new)
  - Registered in `project.godot`
- [ ] **Main menu wired up** — `_on_options()` navigates to options screen (was `pass`)
  - File: `scripts/ui/main_menu.gd`

---

## 9. Level Select Screen (F3)

- [ ] **Level select screen** — loads all levels, scrollable list with encounter counts, detail panel (name/BPM/encounters/length/speed/nebulas), Play button launches game
  - File: `scripts/ui/level_select_screen.gd` (new, 272 lines)
  - Scene: `scenes/ui/level_select_screen.tscn`
- [ ] **Play menu link** — "SELECT LEVEL" button navigates to level select
  - Files: `scenes/ui/play_menu.tscn`, `scripts/ui/play_menu.gd`

---

## 10. Hangar Screen Readability (F1)

- [ ] **Color-coded section headers** — "WEAPONS"/"CORES"/"DEVICES" with colored PanelContainer bars
- [ ] **Color-coded slot buttons** — font color tinted by slot type (cyan/yellow/orange)
- [ ] **Enlarged toggle buttons** — 30x30 -> 44x38
- [ ] **Increased spacing** — section separation, slot row heights, mode tab spacing
- [ ] **Theme-aware recoloring** — `_apply_theme()` rewritten for all color-coded elements
  - File: `scripts/ui/hangar_screen.gd`

---

## 11. Ship Renderer Cleanup (C1)

- [ ] **`_make_circle_points()` utility** — generates evenly-spaced polygon points
- [ ] **`_arc()` utility** — draws arcs respecting render modes
- [ ] **Sentinel** — uses `_make_circle_points()` with 32 segments (was 12 inline)
- [ ] **Scythe** — inner edge accent uses `_arc()` helper
  - File: `scripts/rendering/ship_renderer.gd`

---

## 12. LED Bar Shader Modulate Fix

- [ ] **Shader captures `modulate_alpha`** at top of `fragment()` and multiplies into final alpha — fixes `sprite.modulate.a` having no effect from GDScript
  - File: `assets/shaders/led_bar.gdshader`

---

## 13. New Content

- [ ] **Nebula: Hull Healer** (`nebula_3.json`) — dual_voronoi style
- [ ] **Nebula: Electrical Charge** (`nebula_4.json`) — electric_filaments style
- [ ] **Weapon: green_tickle** (`green_tickle.json`) — track aim, 128 fire triggers, 8-bar loop
- [ ] **Projectile Style: green_tickle** (`green_tickle.json`) — bullet archetype, green, fire shader
- [ ] **Removed: ignored_bubbles** weapon (placeholder with no triggers)

---

## Notes / Issues Found

_Write your findings here as you test each section._
