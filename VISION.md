# Syntherion — Vision, Plans, and Open Questions

> Living document. Started 2026-03-23. For discussion, not execution.

---

## 1. Game Identity — Lessons from Tyrian

The core gameplay loop Tyrian nails:
- **Constant shredding of small enemies** with occasional "oh fuck" surprises from big/dangerous ones
- **Game of chicken** — dare to stay in front of a big enemy to kill it, or bail sideways?
- **Ramming is deadly** — contact damage is serious, movement matters
- **Collecting is the dopamine**, not score. Gems, shiny drops, then spending after.
- **Surprise riches** — introduce a pattern ("this section drops gems"), then repeat it
- **Distinct planet themes** — first four levels all looked completely different
- **Music drives the experience** — levels need their own soundtrack

### How Syntherion differs
- Player has more to manage (weapon toggles = audio layering, system bars, components)
- The music IS the weapons — but levels also need atmosphere/soundtrack loops
- Fragility lesson applies: everything should be more killable, including the player

### Pacing — DECIDED
Longer levels (3-5 min) with **breathing corridors** — brief 5-10 second gaps where enemies thin out. Not checkpoints, not stops. Just natural lulls. Reasons:
- The audio layering system needs TIME to breathe. A 90-second level barely lets the player hear what they've composed.
- Breathing corridors let players toggle weapons, check bars, recover from heat — without pausing gameplay.
- Musical transition points: atmosphere loops can shift during corridors.
- Combat has arcs: buildup → climax → corridor → buildup again.
- Having management decisions to make (weapon toggles, system bars) doesn't create slow moments by itself — the player is still dodging and shooting during those decisions. Deliberate lulls are separate.

---

## 2. Ship Design Philosophy — DECIDED

### Ships are RPG classes, not stat sticks
All ships have the **same number of slots, similar size, and roughly similar speed/acceleration.** The differentiator is a **unique passive ability** per ship:
- "Amplifies nebula effects"
- "Converts a portion of shield hits to energy"
- "Faster thermal dissipation"
- "Brief invulnerability on weapon toggle" (rewards musical risk)

This gives ships personality without power creep. Players pick based on playstyle: *"I'll take the Stalker on this one, it's good in nebulas."*

### Crystal Socket System
Ships have **crystal sockets** — permanent upgrade slots. Players find or earn crystals (rare drops, level rewards, shop purchases) and fit them into a ship. The procedure is **permanent** — once socketed, it's committed. This creates:
- Treasure-hunting dopamine (finding a good crystal)
- Meaningful decisions (which ship gets this crystal?)
- Investment / attachment to a specific ship
- A reason to own multiple ships (different crystal builds for different situations)

Crystals affect **ship stats** (hull, shield, thermal, electric, speed), not weapon behavior. Weapons and components stay as collectibles with their own audio/visual identity.

### Cosmetic skins
Separate from stats. Metal/chrome for player ships, neon/alien for enemies (existing direction). Additional skins earnable or purchasable. Sense of ownership.

---

## 3. Component Collection — DECIDED

### All components are collectibles (breadth, not depth)
Weapons, power cores, field emitters — each is a unique item with its own audio/visual identity:
- **Weapons** — unique loop, fire pattern, effect profile
- **Power Cores** — unique beat-synced stat behavior, visual pulse
- **Field Emitters** — unique pulsing animation synced to music

No "Pulse Cannon Lv1 → Lv2 → Lv3." Each component is a distinct creative object. Progression = owning more options to mix and match, not making one thing bigger.

### Where upgrades live
- **Ship stats** via crystal sockets (permanent, meaningful)
- **Ship cosmetics** via skins (earnable/purchasable)
- Components themselves: no upgrades, just collection

---

## 4. Economics and Monetization — DECIDED

### In-game economy (must work with zero real money)
- **Credits** earned by playing levels. Per-level earning with **letter grade bonus** (A/B/C/D/F).
- Spent at **shop between levels**: new components, crystals, ship unlocks, skins.
- A "good run" funds the next level's baseline needs. A "perfect run" funds something extra.
- No reselling components (unlike Tyrian). Once bought, it's yours.
- F2P player can beat all content through skill + grinding. Economy never requires real money.

### Real-money monetization (layered on top, not baked in)
- **No gacha.** Direct purchase only.
- **Season Pass / Battle Pass model** — pay for a content track that unlocks as you play. Each season adds levels + components + crystals + skins.
- Fits the goal of continued value through regular releases.
- Automatable over time: as level/enemy generation pipeline matures, season content gets easier to produce.

### Platform packaging
- **Steam**: Base game free or cheap. Season packs as DLC ($3-5 each). No microtransactions.
- **Mobile**: Free to play. Same in-game currency. Premium currency purchasable for cosmetics/season pass. Optional ads (watch ad for bonus credits after level).
- **Key**: Currency system is platform-agnostic. Same shop, same unlock logic. Only the payment entry point differs.

---

## 5. Gameplay Features — What to Build

### Near-term (wire up what exists)
- [ ] **Enemy weapon direction** — weapons rotate with enemy flight path. Track/turret modes stay accurate (don't rotate with hull).
- [ ] **Universal melee/ram damage** — single global parameter. Contact = pain.
- [ ] **Fragility pass** — reduce HP across the board. Player shreds small enemies, gets shredded if caught.
- [ ] **Weapon loop fade in/out** — separate durations. Fast attack, slow release.
- [ ] **Power-loss event improvements** — earlier trigger in shield drain, chance to recover from drift, warning animations.
- [ ] **Overheat event** — animation for dangerous heat buildup + overheat trigger.
- [ ] **Hull hit screen shake** — when HP is low. Subtle.
- [ ] **Impact warning on power-loss screen** — rigged to actual hits.
- [ ] **Death sequence** — flames/damage visible → fade to dark → game over.
- [ ] **Field emitter cross-system audit** — weapon-disabling field must also mute audio + update HUD correctly.

### Level design foundation
- [ ] **Build Level 1** — space background with synthwave grid, geometric enemies.
- [ ] **Build Level 2** — nebula background, ocean-themed enemies.
- [ ] **Build Level 3** — boss or gauntlet, circuit/dark theme.
- [ ] **Background "buildings"** — scrolling structures/objects, not just parallax layers.
- [ ] **Level atmosphere loops** — each level has its own background music layers.

### Editor improvements
- [ ] **Encounter placement rework** — set stats before clicking, place multiple. Selector by enemy level category.
- [ ] **Trim Style Editor** — remove unused settings, simplify what remains.

### Tools
- [ ] **Node tree dumper** — debug key (F4?) dumps every Control node's rect, visibility, parent to console. For diagnosing UI layout issues.
- [ ] **Headless test runner** — `test_runner.gd` that validates JSON schemas, cross-references, scene loading, signal connections. Grows over time.

### Bugs / small fixes
- [ ] **green_tickle projectile** — HDR increase doesn't bloom, just brightens internals.
- [ ] **Field emitter weapon disable** — audio keeps playing, HUD shows wrong state, toggle broken on re-enable.

---

## 6. Demo — What Ships to Friends

> 3 levels, playable end-to-end.

**Must have:**
- Main menu → Level select → Play level → Game over / Victory → Back to menu
- 3 playable levels with distinct themes and breathing corridors
- 3-5 weapons that sound good layered together
- 2-3 ships with distinct passives
- Working HUD with all system bars
- Death sequence
- Shop between levels (basic)
- Atmosphere loops per level
- Letter grade scoring

**Nice to have:**
- Crystal drops and socketing
- Leaderboard / score display
- Cosmetic skins

**Cut for demo:**
- Dev Studio (hide behind debug key)
- Style Editor (trim and hide)
- Mobile anything
- Economy balance (generous credits, skip the grind)

---

## 7. Process Improvements

### UI work
- **Node tree dumper** (F4) — dump Control rects/visibility to console for debugging
- **Audition pattern** — second Claude builds visual layout, main Claude wires logic
- **Screenshot workflow** — paste what you see, Claude diagnoses structure

### Testing
- **Headless test runner** — catches crashes, scope errors, missing references before launch
- Can verify: JSON validity, scene instantiation, signal wiring, method calls
- Cannot verify: visual layout, audio, input, animations
- Grow the test suite after each session

### Task management
- Sweet spot: 3-5 related tasks with clear boundaries per prompt
- Walk-away tasks need upfront verification criteria
- Remind user when headless testing could catch issues before playtest

### Cross-system safety
- Before features that touch multiple systems, trace signal/call chains first
- Use debug prints aggressively when behavior is wrong
- Document which systems talk to which (signal chain map)

---

## 8. Stability and Expandability

> "My true goal is to get a very firm and stable base that is easy to expand upon"

### What "stable base" means
- New weapon = drop JSON + WAV, done
- New enemy = drop JSON + assign ship/weapons, done
- New level = build in level editor, done
- New ship = draw + define passive + add to registry, done
- New season = bundle of the above, no core code changes

### Actions
1. **Trim Style Editor** — keep what's used, remove the rest
2. **Freeze solid dev studio tabs** — weapons, beams, projectile animator. Don't touch unless necessary.
3. **Headless data validation** — script that loads every JSON, checks references
4. **Signal chain documentation** — which systems talk to which
5. **Feature flags** — hide unfinished work from player (orbital generators, etc.)

---

## 9. Mobile (Parked)

Not building for mobile now. But keeping in mind:
- Touch controls (virtual joystick or tap-to-move)
- UI via containers, not pixel positions
- Bloom scales with resolution — will need tuning per device
- Sprite pre-rendering for performance (test with enemy swarms)
- Season pass / premium currency works on both platforms
- Currency system is platform-agnostic by design

---

## 10. Future: Auto-Generation Pipeline

After 2-3 hand-built levels and a stable level format:
- Claude/Python hybrid generates enemy variants, formations, wave sequences as JSON
- Human curates and tweaks
- Harder to automate: backgrounds, music selection, boss design
- Goal: lighten the load for season content production
