# Godot Gotchas — Synth Fleet

Architecture-specific lessons learned. See also CLAUDE.md for the most critical universal gotchas.

## Panel sizing vs content width
Setting `position`/`size` on a Panel directly does NOT prevent content from overflowing if children's combined minimum size exceeds the Panel width. `clip_contents = true` will crop visually but not fix the layout. Manual `set_deferred()`, anchors, and `grow_horizontal` all fail to override this. **Fix:** build content first, then `await get_tree().process_frame` and read `get_combined_minimum_size()` on children to measure actual needed width. Set the Panel size to fit, and position it accordingly (e.g. right-align by setting `position.x = viewport_width - measured_width`).

## LED bar glow architecture
`apply_led_bar()` applies a segment shader to the bar's background stylebox AND adds a child `led_glow` ColorRect with HDR color for bloom. The shader alone can't provide HDR bloom — Godot's 2D pipeline clamps canvas_item shader `COLOR` output, but preserves `ColorRect.color` values > 1.0. So the shader handles visual detail (segments, gaps, inner glow) while the glow rect provides the bloom source. Access shader via `bar.material`. The fill stylebox must be transparent (so ProgressBar value-scaling doesn't affect visuals); the background stylebox must be opaque (so the shader has a surface to draw on). Bloom comes from the root viewport's WorldEnvironment (ThemeManager).

## Bloom architecture
ThemeManager's root `WorldEnvironment` has `glow_enabled = true` — this is the single bloom source. `VFXFactory.add_bloom_to_viewport()` adds ACES tonemapping only (no glow) to SubViewports for consistent color mapping. HUD bars on the root viewport get bloom naturally. CanvasLayer content (VHS overlay) still skips bloom, which is correct.

## `glow_bloom` vs `glow_hdr_threshold`
`glow_bloom` applies bloom to ALL pixels regardless of brightness — even small values fog up the entire screen. Keep it near 0. `glow_hdr_threshold` controls the minimum brightness for bloom — only pixels above this value glow. HDR bar output (fill_color × hdr_multiplier) must exceed the threshold to bloom.

## Bloom is resolution-dependent
Godot's glow blur kernel is fixed-size in pixels, so it covers proportionally larger area in smaller viewports. Dev studio previews (400px) will have more visible bloom per pixel than the game viewport (1920px) with identical settings. This is acceptable — dev previews don't need to match game exactly. **Portability warning:** bloom will blow out on smaller screens (tablets, phones, Steam Deck). Any future port MUST scale glow settings inversely with screen resolution.

## Never manually position bars — use VBoxContainer layout
`apply_led_bar()` sets `custom_minimum_size` based on segment count. If you manually calculate `bar.position`/`bar.size`, they will desync when `_apply_theme` later calls `apply_led_bar` with a different segment count (e.g. from ship stats). **Fix:** put bars inside VBoxContainers: `spacer (SIZE_EXPAND_FILL) → bar → pad → label → pad`. The spacer pushes bar+label to the bottom of the zone. `custom_minimum_size` changes from `apply_led_bar` flow naturally through the container layout. Zero manual position math, zero deferred hacks.

## `z_index` in SubViewport previews
Nodes in a SubViewport share a global z_index sort. A `Sprite2D` with `z_index = -1` renders BEHIND a `ColorRect` background at z_index 0, making shader-driven content completely invisible even when opacity is 1.0. **Fix:** always use `z_index = 1` (or higher) on preview sprites that render over a dark background ColorRect. The Fields tab uses `z_index = 1` — match it in any device/emitter preview.

## Hidden nodes leave layout
Setting `visible = false` on a node removes it from layout calculations entirely. In an `HSplitContainer`, this causes the split to recalculate and the panel to shrink/jump. **Fix:** never hide content that anchors a panel's width. Instead, keep it visible but grey it out (`modulate = Color(1, 1, 1, 0.3)`) and disable interactive controls (`disabled = true` on buttons/dropdowns, `editable = false` on spinboxes). The widgets stay in layout and hold the panel width stable.

## Recovery animations trigger exit checks
If code checks `if electric > 0.0: _end_drift()` and a recovery animation sets `electric = lerpf(0, max, t)`, the recovery kills itself on frame 2 because electric rises above 0. **Fix:** guard exit checks with `and not _recovery_active` (or equivalent flag) so the recovery sequence completes before normal gameplay checks resume. This applies to any multi-frame animation that restores a stat value that other code monitors for state transitions.

## GDScript warnings to avoid
Godot's script analyzer produces yellow warnings for common patterns. These are easy to prevent:
- **SHADOWED_VARIABLE_BASE_CLASS:** Never name a local variable `scale`, `position`, `size`, `visible`, `modulate`, `show`, `is_visible`, `tr`, etc. — these shadow properties/methods on `Node2D`, `Control`, `CanvasItem`, or `Object`. Use descriptive names: `map_scale`, `show_nav`, `tooth_r`.
- **UNUSED_VARIABLE:** Prefix genuinely unused vars with `_`. But first check if the var *should* be used — it may indicate forgotten code.
- **UNUSED_PARAMETER:** Prefix unused function params with `_` (e.g. `_shimmer`). Common with interface-style signatures where not all implementations use every param.
- **INTEGER_DIVISION:** `int(x) / 60` silently truncates. Use `int(x / 60.0)` to make intent explicit.
- **CONFUSABLE_LOCAL_DECLARATION:** Don't declare `var foo` in both an inner block and later in the same function, even if the inner block returns. Rename one of them.
