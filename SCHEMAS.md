# Syntherion — Data Schemas and Subsystem Reference

> Detailed schemas and subsystem docs. CLAUDE.md links here. Consult when working on weapons, effects, the waveform editor, or the hardpoint firing system.

---

## WeaponData Schema

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

---

## Effect Profile (v2)

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

---

## Waveform Editor Coordinate System

The waveform editor works in **normalized time (0.0–1.0)** internally. Fire triggers are placed, displayed, and stored in normalized time — no beat-space conversion anywhere in the pipeline.

The playback cursor reads `LoopMixer.get_playback_position() / get_stream_duration()` — the same clock source as HardpointController. One clock, zero drift.

Beat grid overlay uses `loop_length_bars` for cosmetic display only (snap lines, bar markers).

Snap modes: Free (click anywhere), 1/4, 1/8, 1/16. Beat grid overlay is optional and visual-only.

---

## Adding a New Weapon

1. Use the Weapons Tab in Dev Studio, or save a JSON file to `res://data/weapons/`
2. Place the weapon's audio loop WAV in `assets/audio/loops/` or `loop_zips/sorted/`
3. In Weapons Tab (Timing subtab): browse loops, waveform auto-loads with real PCM data, click to place fire triggers (Free or snapped)
4. Use Effects subtab for visual effect layers, Stats subtab for combat values
5. JSON schema matches `WeaponData` resource class fields — fire_triggers stored as normalized time (0.0–1.0)
6. Weapons are loaded at runtime via `WeaponDataManager.load_by_id(id)`

---

## HardpointController

Frame-based trigger checking using LoopMixer as the single clock source:
- Each frame: get `LoopMixer.get_playback_position() / get_stream_duration()` for normalized time (0.0–1.0), check if any fire trigger was crossed since last frame
- Wrap-around detection: if `curr < prev`, trigger fires if `> prev OR <= curr`
- `activate()` / `deactivate()` / `toggle()` — unmute/mute via LoopMixer
