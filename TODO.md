# Syntherion — Task List

> Organized by priority toward a demo-ready build. See VISION.md for design rationale.
> Style Editor trim: DONE (2026-03-23). Headless test runner: not yet built.

---

## Tier 1: Game Loop (demo-blocking — can't ship without these)

The game currently has no way to win. Waves restart endlessly. No scoring, no progression, no shop integration. These tasks create the end-to-end flow: play level → win/lose → score → shop → next level.

### 1A. Victory condition + level complete flow
- `game.gd`: on `all_waves_cleared`, stop spawning, enter victory state
- Victory overlay: "MISSION COMPLETE" with stats (enemies killed, credits earned, time)
- Letter grade calculation (A/B/C/D/F) based on performance metrics
- After overlay dismiss: transition to shop or level select
- Track completed levels in GameState

### 1B. Death sequence polish
- Currently: 3-second explosion → "GAME OVER" text → any key returns
- Needed: make it feel like a death. Screen damage, fade to dark, brief pause before game over text
- Already has staggered explosions + shake — may just need timing/visual polish

### 1C. Shop integration
- Shop screen exists but is disconnected from game loop
- Wire it between levels: victory → shop → next level
- Display credits earned this run, total credits, available purchases
- "Continue" button loads next level (not just game.tscn blindly)
- Basic weapon/component purchasing (components already in JSON)

### 1D. Level progression tracking
- GameState needs: `completed_levels` array, `current_level_index` for sequential play
- Level select shows completion status (letter grade per level)
- "Next level" auto-advances after shop

---

## Tier 2: Combat Feel (demo-critical — makes the game fun to play)

### 2A. Universal contact/ram damage
- Single global melee damage parameter (not per-enemy)
- Enemy contact with player = serious damage (Tyrian lesson: ramming is deadly)
- Current: fixed 15.0 from `_on_contact()`. Needs to be tunable and higher.

### 2B. Fragility pass
- Reduce enemy HP across the board — player should shred small enemies
- Reduce player durability slightly — getting caught = fast death
- Tune in playtesting, but start with ~50% of current values

### 2C. Enemy weapon direction fix
- Enemy weapons currently stay straight even when enemy turns with flight path
- Weapons should rotate WITH hull direction
- EXCEPT track/turret aim modes — those stay locked on player

### 2D. Screen shake on low hull
- When hull HP is low and player takes a hit, brief screen shake
- Subtle — don't be annoying. Scale intensity with how low hull is.
- Existing ExplosionEffect has shake infrastructure to reuse

### 2E. Enemy off-screen despawn
- Enemies that drift off-screen are never cleaned up
- Add bounds check — despawn enemies that leave viewport (with margin)

---

## Tier 3: Audio Polish (demo-important — the music IS the game)

### 3A. Weapon loop fade in/out
- Separate fade-in and fade-out durations on weapon toggle
- Fast attack (instant or ~100ms) for satisfaction of activation
- Slow release (~500ms-1s) for musical fadeout
- Modify LoopMixer mute/unmute to support fade curves

### 3B. Level atmosphere loops
- Each level needs background music layers (Splice WAVs in `assets/audio/atmosphere/`)
- Atmosphere loops play via LoopMixer alongside weapon loops
- Always unmuted — the level's sonic foundation

### 3C. Add Splice WAV loops
- Populate `assets/audio/loops/` with weapon loops
- Populate `assets/audio/atmosphere/` with level atmosphere loops
- This is a content task — need actual WAV files from Splice

---

## Tier 4: Events + Animation (adds drama, not demo-blocking)

### 4A. Power-loss event improvements
- Current trigger may be too late — player is already dead
- Earlier trigger: shields start draining → engines slow → drift begins → then full event
- Brief window to recover from drift before total power loss
- Warning animations before full event kicks in

### 4B. Overheat event
- New event: thermal bar maxes out → overheat state
- Animation for dangerous heat buildup (bar pulsing, warning color)
- Overheat consequences: weapons forced off? Speed reduction? Temporary vulnerability?

### 4C. Impact warning on power-loss screen
- Power-loss event already muffles audio (good)
- Add visual hit indicator when player takes damage during event
- Rig to actual collision events

---

## Tier 5: Tools (makes development faster)

### 5A. Node tree dumper (F4 debug key)
- Press F4 → prints every Control node's global_rect, visibility, parent path to console
- For diagnosing UI layout issues without visual guessing
- Add as a debug autoload or toggle in game.gd

### 5B. Headless test runner
- `scripts/test/test_runner.gd` — run via `godot --headless --script`
- Phase 1: Load every JSON in `res://data/`, validate required fields exist
- Phase 2: Check cross-references (weapon references projectile_style that exists, level references ships that exist)
- Phase 3: Instantiate key scenes, check for script errors
- Grow after each session

### 5C. Encounter placement rework
- Current: exhaustive enemy list, click to place one at a time
- Wanted: set stats first (enemy type, count, formation), then click to place group
- Selector by enemy level category instead of showing every enemy

---

## Tier 6: Bugs (fix when touching nearby code)

### 6A. green_tickle projectile bloom
- HDR increase doesn't produce bloom, just brightens internals
- Likely shader issue — check if HDR color is actually > threshold

### 6B. Field emitter weapon disable side effects
- Weapon-disabling field: audio keeps playing when weapons disabled
- HUD shows weapons as ON when they're disabled by field
- Toggle behavior broken on field deactivation (need to press twice)
- Cross-system audit: field → hardpoint_controller → loop_mixer → hud

---

## Tier 7: Future (post-demo, park for now)

- Ship design rework (same slots, unique passives, crystal sockets) — see VISION.md §2
- Shop economy balancing (letter grade bonuses, per-level caps)
- Background "buildings" (scrolling structures, not just parallax)
- Auto-generation pipeline (Claude/Python → JSON enemies/levels)
- Mobile considerations
- Season pass / monetization layer
