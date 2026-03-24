# Syntherion — Task List

> Sourced from brain dump (2026-03-23 Tyrian session). See VISION.md for design rationale.

### Done this session
- Style Editor trimmed to VHS/CRT only (1519 → 155 lines)
- Stability pass: data loss fixes, error handling on all 18 managers, dead code removal
- File renames: dev_studio → component_editor, objects_screen → environments_screen
- Save/rename consistency: Fields + Nebulas tabs now handle renames properly
- Headless test runner (50 checks), node tree dumper (F4), level progression data layer
- SFX editor tooltips on all events
- Enemy off-screen despawn: already implemented
- Splice WAV loops: already wired into all weapons

---

## Game Loop (can't demo without these)

### Victory + scoring
- `game.gd`: on `all_waves_cleared`, stop spawning, enter victory state
- Victory overlay with stats (enemies killed, credits earned, time)
- Letter grade (A/B/C/D/F) — **OPEN: what metrics?**
- Transition: victory → shop → next level
- GameState `completed_levels` with grade tracking — DONE (data layer)
- Level select shows letter grade per level — NOT YET (UI)

### Death sequence
- Currently: explosions → "GAME OVER" text → any key. Functional but flat.
- Need: visible damage/flames, fade to dark, pause, then game over. An experience, not a label.

### Shop integration
- Shop screen exists but disconnected from game loop
- Wire between levels: victory → shop → next level
- Credits earned, purchases, "Continue" loads next level
- Basic weapon/component purchasing

---

## Combat Feel (makes it fun)

### Universal ram damage
- Single global parameter, not per-enemy. Contact = serious pain (Tyrian: ramming is deadly)
- Currently fixed 15.0 in `_on_contact()` — needs to be higher and tunable

### Fragility pass
- Reduce HP across the board. Player shreds small enemies, gets shredded if caught.
- **NEEDS PLAYTESTING** to find right values

### Enemy weapon direction
- Weapons should rotate WITH hull when enemy turns on flight path
- Track/turret aim modes stay locked on player (don't rotate with hull)

### Screen shake on low hull
- Brief shake when hit while hull is low. Scale with how low. Don't be annoying.

---

## Audio

### Weapon loop fade in/out
- Separate fade-in and fade-out durations on toggle
- Fast attack (instant/~100ms) for satisfaction, slow release (~500ms-1s) for musical fadeout
- Modify LoopMixer mute/unmute to support fade curves

### Level atmosphere loops
- Each level needs background music layers independent of weapons
- Atmosphere loops play via LoopMixer, always unmuted — the level's sonic foundation
- Need to select and assign atmosphere WAVs from existing Splice collection

---

## Events + Ship Systems

### Power-loss event — earlier trigger + recovery window
- Current trigger may be too late — player already dead
- Earlier: shields bleed → engines slow → drift begins → then full event
- Brief window to recover from drift before total power loss

### Overheat feedback (mechanic exists, feedback missing)
- Thermal overflow → hull damage bypassing shields — this WORKS already
- **Missing:** player has zero warning. Hull silently takes heat damage.
- Need: HUD warning as thermal approaches max (bar pulsing, color, alarm SFX)
- Need: distinct visual for "hull melting from heat" vs "hull hit by enemy"

### Impact warning during power-loss
- Power-loss already muffles audio (good)
- Add visual hit indicator when taking damage during event

### Ship automation toggles
- Hangar config panel with toggles: "Auto shut off heat-generating components when overheating", "Auto re-enable when cooled", etc.
- **OPEN:** per-ship or per-loadout storage?

---

## Level Design (demo needs 3 levels)

### Build Level 1
- Space background with synthwave grid, geometric enemies
- Breathing corridors between wave groups

### Build Level 2
- Nebula background, ocean-themed enemies

### Build Level 3
- Boss or gauntlet, circuit/dark theme

### Background structures
- Scrolling "buildings"/objects, not just parallax layers

---

## Tools + Editor

### Encounter placement rework
- Set stats before clicking, place multiple at once
- Selector by enemy level category, not exhaustive list

---

## Bugs

### green_tickle projectile bloom
- HDR increase doesn't bloom, just brightens internals

### Field emitter weapon disable side effects
- Audio keeps playing, HUD shows wrong state, toggle broken on re-enable
- Cross-system: field → hardpoint_controller → loop_mixer → hud

---

## Investigate

### Sprite pre-rendering performance test
- Test animated enemy swarms in render mode vs pre-rendered sprite form
- Compare visual quality and performance

### Mouse control option
- Consider mouse position = ship target with lerp
- Keyboard frees mouse for other interactions, but mouse is more precise for PC
- Mobile needs touch/virtual joystick regardless — could support both

---

## Future (post-demo)

- Ship design rework: same slots, unique passives, crystal sockets (VISION.md §2)
- Shop economy balancing: letter grade bonuses, per-level caps
- Auto-generation pipeline: Claude/Python → JSON enemies/levels
- Mobile considerations
- Season pass / monetization layer
