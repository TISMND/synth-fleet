class_name EffectLayerRenderer
extends RefCounted
## Static utility class for composable effect layer rendering.
## Centralizes all glow draw helpers and layer resolution logic.
## Used by Projectile (game) and WeaponPreview (editor) to eliminate duplication.

const MAX_LAYERS_PER_SLOT: int = 4

# ── Layer Resolution ────────────────────────────────────────

## Resolve layers for a given trigger index from a v2 effect profile.
## Returns a Dictionary with slot keys mapping to Array of layer dicts.
static func resolve_layers(profile: Dictionary, trigger_index: int = -1) -> Dictionary:
	var version: int = int(profile.get("version", 1))
	var result: Dictionary = {}

	if version < 2:
		# v1 profile: each slot is {type, params} — wrap in array
		for slot in ["shape", "motion", "muzzle", "trail", "impact"]:
			var layer_data: Dictionary = profile.get(slot, {}) as Dictionary
			if layer_data.is_empty() or str(layer_data.get("type", "none")) == "none":
				result[slot] = []
			else:
				result[slot] = [layer_data]
		result["beat_fx"] = []
		return result

	# v2 profile
	var defaults: Dictionary = profile.get("defaults", {}) as Dictionary
	for slot in ["shape", "motion", "muzzle", "trail", "impact", "beat_fx"]:
		var slot_layers: Array = defaults.get(slot, []) as Array
		result[slot] = slot_layers.duplicate()

	# Apply trigger overrides if a specific trigger is selected
	if trigger_index >= 0:
		var overrides: Dictionary = profile.get("trigger_overrides", {}) as Dictionary
		var key: String = str(trigger_index)
		if overrides.has(key):
			var trigger_data: Dictionary = overrides[key] as Dictionary
			for slot in trigger_data:
				result[slot] = (trigger_data[slot] as Array).duplicate()

	# Cap layers per slot
	for slot in result:
		var layers: Array = result[slot]
		if layers.size() > MAX_LAYERS_PER_SLOT:
			result[slot] = layers.slice(0, MAX_LAYERS_PER_SLOT)

	return result


# ── Motion ──────────────────────────────────────────────────

## Compute summed x-offset from all motion layers.
static func compute_motion_offset(layers: Array, age: float) -> float:
	var x_offset: float = 0.0
	for layer in layers:
		var layer_dict: Dictionary = layer as Dictionary
		var mtype: String = str(layer_dict.get("type", "none"))
		var params: Dictionary = layer_dict.get("params", {}) as Dictionary
		match mtype:
			"sine_wave":
				var amp: float = float(params.get("amplitude", 30.0))
				var freq: float = float(params.get("frequency", 3.0))
				x_offset += sin(age * freq * TAU) * amp
			"corkscrew":
				var amp: float = float(params.get("amplitude", 20.0))
				var freq: float = float(params.get("frequency", 5.0))
				var phase: float = float(params.get("phase_offset", 0.0))
				x_offset += sin(age * freq * TAU + phase) * amp
			"wobble":
				var amp: float = float(params.get("amplitude", 10.0))
				var freq: float = float(params.get("frequency", 8.0))
				x_offset += sin(age * freq * TAU) * amp * (1.0 + 0.3 * sin(age * freq * 3.7))
	return x_offset


# ── Shape Drawing ───────────────────────────────────────────

## Draw all shape layers stacked (alpha-blended, visually additive).
static func draw_shape_stack(canvas: CanvasItem, center: Vector2, layers: Array, color: Color, age: float) -> void:
	if layers.is_empty():
		# Default fallback shape
		_draw_glow_rect(canvas, center, 6.0, 12.0, 3.0, 0.8, 1.0, color)
		return
	for layer in layers:
		var layer_dict: Dictionary = layer as Dictionary
		var stype: String = str(layer_dict.get("type", "rect"))
		var params: Dictionary = layer_dict.get("params", {}) as Dictionary
		var glow_w: float = float(params.get("glow_width", 3.0))
		var intensity: float = float(params.get("glow_intensity", 0.8))
		var core_b: float = float(params.get("core_brightness", 1.0))
		match stype:
			"rect":
				var w: float = float(params.get("width", 6.0))
				var h: float = float(params.get("height", 12.0))
				_draw_glow_rect(canvas, center, w, h, glow_w, intensity, core_b, color)
			"streak":
				var w: float = float(params.get("width", 3.0))
				var h: float = float(params.get("height", 20.0))
				_draw_glow_rect(canvas, center, w, h, glow_w, intensity, core_b, color)
			"orb":
				var r: float = float(params.get("radius", 4.0))
				_draw_glow_circle(canvas, center, r, glow_w, intensity, core_b, color)
			"diamond":
				var w: float = float(params.get("width", 8.0))
				var h: float = float(params.get("height", 14.0))
				_draw_glow_diamond(canvas, center, w, h, glow_w, intensity, core_b, color)
			"arrow":
				var w: float = float(params.get("width", 8.0))
				var h: float = float(params.get("height", 16.0))
				_draw_glow_arrow(canvas, center, w, h, glow_w, intensity, core_b, color)
			"pulse_orb":
				var r: float = float(params.get("radius", 5.0))
				var pulse: float = 1.0 + 0.3 * sin(age * 10.0)
				_draw_glow_circle(canvas, center, r * pulse, glow_w * pulse, intensity * 1.2, core_b, color)
			_:
				_draw_glow_rect(canvas, center, 6.0, 12.0, glow_w, intensity, core_b, color)


# ── Muzzle Spawning ─────────────────────────────────────────

## Generate muzzle particles from all muzzle layers. Returns flat Array of particle dicts.
static func spawn_muzzle_stack(layers: Array, origin: Vector2, color: Color) -> Array:
	var all_particles: Array = []
	for layer in layers:
		var layer_dict: Dictionary = layer as Dictionary
		var mtype: String = str(layer_dict.get("type", "none"))
		if mtype == "none":
			continue
		var params: Dictionary = layer_dict.get("params", {}) as Dictionary
		var count: int = int(params.get("particle_count", 6))
		var lifetime: float = float(params.get("lifetime", 0.3))
		var spread: float = float(params.get("spread_angle", 360.0))

		for i in count:
			var angle: float = 0.0
			var spd: float = randf_range(80, 200)
			match mtype:
				"radial_burst":
					angle = randf_range(0, TAU)
				"directional_flash":
					angle = -PI / 2.0 + randf_range(-deg_to_rad(spread / 2.0), deg_to_rad(spread / 2.0))
				"ring_pulse":
					angle = TAU * float(i) / float(count)
					spd = 120.0
				"spiral_burst":
					angle = TAU * float(i) / float(count) + float(i) * 0.3
					spd = 100.0 + float(i) * 10.0
				_:
					angle = randf_range(0, TAU)

			all_particles.append({
				"pos": Vector2.ZERO,
				"vel": Vector2(cos(angle), sin(angle)) * spd,
				"age": 0.0,
				"lifetime": lifetime,
				"size": randf_range(2.0, 4.0),
				"color": color,
			})
	return all_particles


# ── Trail Particle Spawning ─────────────────────────────────

## Spawn trail particles from all trail layers (excluding ribbon types).
## Appends to the provided particles array. pos is the current projectile global position.
static func spawn_trail_particles(layers: Array, pos: Vector2, color: Color, particles_out: Array) -> void:
	for layer in layers:
		var layer_dict: Dictionary = layer as Dictionary
		var ttype: String = str(layer_dict.get("type", "none"))
		if ttype == "none" or ttype == "ribbon" or ttype == "sine_ribbon":
			continue
		var params: Dictionary = layer_dict.get("params", {}) as Dictionary

		match ttype:
			"particle":
				if randf() < 0.6:
					particles_out.append({
						"pos": pos + Vector2(randf_range(-3, 3), randf_range(0, 5)),
						"vel": Vector2(randf_range(-20, 20), randf_range(20, 60)),
						"age": 0.0,
						"lifetime": float(params.get("lifetime", 0.2)),
						"size": randf_range(1.0, 3.0),
						"color": color,
					})
			"sparkle":
				if randf() < 0.5:
					particles_out.append({
						"pos": pos + Vector2(randf_range(-8, 8), randf_range(-2, 6)),
						"vel": Vector2(randf_range(-40, 40), randf_range(10, 40)),
						"age": 0.0,
						"lifetime": float(params.get("lifetime", 0.25)),
						"size": randf_range(1.0, 2.5),
						"color": color,
					})
			"afterimage":
				if randf() < 0.3:
					particles_out.append({
						"pos": pos,
						"vel": Vector2.ZERO,
						"age": 0.0,
						"lifetime": float(params.get("lifetime", 0.15)),
						"size": 4.0,
						"color": color,
					})


# ── Ribbon Trail Drawing ────────────────────────────────────

## Draw ribbon trails from all trail layers that are ribbon-type.
static func draw_ribbon_trails(canvas: CanvasItem, layers: Array, trail_points: Array, color: Color, global_offset: Vector2) -> void:
	for layer in layers:
		var layer_dict: Dictionary = layer as Dictionary
		var ttype: String = str(layer_dict.get("type", "none"))
		if ttype != "ribbon" and ttype != "sine_ribbon":
			continue
		if trail_points.size() < 2:
			continue
		var params: Dictionary = layer_dict.get("params", {}) as Dictionary
		var width_start: float = float(params.get("width_start", 4.0))
		var width_end: float = float(params.get("width_end", 0.0))
		var count: int = trail_points.size()

		for i in range(count - 1):
			var t: float = float(i) / float(count - 1)
			var from_pt: Vector2 = (trail_points[i] as Vector2) - global_offset
			var to_pt: Vector2 = (trail_points[i + 1] as Vector2) - global_offset

			if ttype == "sine_ribbon":
				var amp: float = float(params.get("amplitude", 5.0))
				var freq: float = float(params.get("frequency", 4.0))
				var offset: float = sin(float(i) * freq * 0.5) * amp * (1.0 - t)
				from_pt.x += offset
				to_pt.x += offset

			var w: float = lerpf(width_end, width_start, t)
			var alpha: float = t * 0.7
			canvas.draw_line(from_pt, to_pt, Color(color, alpha), maxf(w, 1.0))


# ── Impact Spawning ─────────────────────────────────────────

## Generate impact particles from all impact layers. Returns flat Array of particle dicts.
static func spawn_impact_stack(layers: Array, color: Color) -> Array:
	var all_particles: Array = []
	for layer in layers:
		var layer_dict: Dictionary = layer as Dictionary
		var itype: String = str(layer_dict.get("type", "none"))
		if itype == "none":
			continue
		var params: Dictionary = layer_dict.get("params", {}) as Dictionary
		var count: int = int(params.get("particle_count", 8))
		var lifetime: float = float(params.get("lifetime", 0.4))
		var radius: float = float(params.get("radius", 20.0))

		for i in count:
			var angle: float = TAU * float(i) / float(count) + randf_range(-0.2, 0.2)
			var spd: float = radius / lifetime

			match itype:
				"ring_expand":
					spd = radius / lifetime * 1.5
				"shatter_lines":
					angle = randf_range(0, TAU)
					spd = randf_range(radius / lifetime * 0.5, radius / lifetime * 1.5)
				"nova_flash":
					spd = radius / lifetime * 2.0
				"ripple":
					spd = radius / lifetime * 0.8

			all_particles.append({
				"pos": Vector2.ZERO,
				"vel": Vector2(cos(angle), sin(angle)) * spd,
				"age": 0.0,
				"lifetime": lifetime,
				"size": randf_range(2.0, 5.0),
				"color": color,
			})
	return all_particles


# ── Beat FX Evaluation ──────────────────────────────────────

## Evaluate beat-synced sub-effects. Returns transient modifiers for the current frame.
## Result dict: { "color_shift": Color, "scale_mult": float, "sparkle_particles": Array }
static func evaluate_beat_fx(layers: Array, color: Color, _age: float, _delta: float) -> Dictionary:
	var result: Dictionary = {
		"color_shift": Color.TRANSPARENT,
		"scale_mult": 1.0,
		"sparkle_particles": [],
	}
	if layers.is_empty() or not BeatClock._running:
		return result

	for layer in layers:
		var layer_dict: Dictionary = layer as Dictionary
		var fx_type: String = str(layer_dict.get("type", "none"))
		if fx_type == "none":
			continue
		var params: Dictionary = layer_dict.get("params", {}) as Dictionary
		var subdivision: int = int(params.get("subdivision", 16))
		var intensity: float = float(params.get("intensity", 0.6))

		# Check if we're near a subdivision beat
		var sub_pos: float = fmod(BeatClock.beat_position * float(subdivision), 1.0)
		# "near" = within 15% of a subdivision tick
		var proximity: float = 1.0 - minf(sub_pos, 1.0 - sub_pos) * 2.0
		proximity = clampf(proximity * 3.0 - 2.0, 0.0, 1.0)  # sharpen to pulse shape

		if proximity <= 0.0:
			continue

		var strength: float = proximity * intensity

		match fx_type:
			"color_pulse":
				var shift_color: Color = Color(
					float(params.get("r", 1.0)),
					float(params.get("g", 1.0)),
					float(params.get("b", 1.0)),
					strength * 0.5
				)
				result["color_shift"] = (result["color_shift"] as Color).blend(shift_color)
			"scale_pulse":
				var max_scale: float = float(params.get("max_scale", 1.5))
				var scale_add: float = (max_scale - 1.0) * strength
				result["scale_mult"] = float(result["scale_mult"]) + scale_add
			"sparkle_burst":
				if strength > 0.8 and randf() < 0.4:
					var sparkle_particles: Array = result["sparkle_particles"]
					sparkle_particles.append({
						"pos": Vector2(randf_range(-6, 6), randf_range(-6, 6)),
						"vel": Vector2(randf_range(-50, 50), randf_range(-50, 50)),
						"age": 0.0,
						"lifetime": 0.15,
						"size": randf_range(1.0, 2.5),
						"color": color,
					})
			"glow_flash":
				# Increase glow intensity transiently
				result["scale_mult"] = float(result["scale_mult"]) + strength * 0.3
			"ring_ping":
				if strength > 0.9 and randf() < 0.3:
					var ring_count: int = 6
					var sparkle_particles: Array = result["sparkle_particles"]
					for i in ring_count:
						var angle: float = TAU * float(i) / float(ring_count)
						sparkle_particles.append({
							"pos": Vector2.ZERO,
							"vel": Vector2(cos(angle), sin(angle)) * 80.0,
							"age": 0.0,
							"lifetime": 0.12,
							"size": 1.5,
							"color": color,
						})

	return result


# ── Trail Particle Drawing (shared helper) ──────────────────

## Draw a single trail/muzzle/impact particle with 3-layer glow.
static func draw_particle(canvas: CanvasItem, p: Dictionary, global_offset: Vector2 = Vector2.ZERO) -> void:
	var age: float = float(p["age"])
	var lifetime: float = float(p["lifetime"])
	if age >= lifetime:
		return
	var t: float = clampf(age / lifetime, 0.0, 1.0)
	var alpha: float = (1.0 - t) * 0.8
	var sz: float = float(p["size"]) * (1.0 - t * 0.5)
	var pos: Vector2 = (p["pos"] as Vector2) - global_offset
	var col: Color = p["color"] as Color
	canvas.draw_circle(pos, sz * 2.0, Color(col, alpha * 0.2))
	canvas.draw_circle(pos, sz, Color(col, alpha))
	canvas.draw_circle(pos, sz * 0.4, Color(1, 1, 1, alpha * 0.6))


# ── Glow Primitives ─────────────────────────────────────────

static func _draw_glow_rect(canvas: CanvasItem, center: Vector2, w: float, h: float, glow_w: float, intensity: float, core_b: float, color: Color) -> void:
	for i in range(3, 0, -1):
		var t: float = float(i) / 3.0
		var gw: float = glow_w * t
		var alpha: float = intensity * (1.0 - t) * 0.35
		var glow_rect: Rect2 = Rect2(center.x - w / 2.0 - gw, center.y - h / 2.0 - gw, w + gw * 2, h + gw * 2)
		canvas.draw_rect(glow_rect, Color(color, alpha))
	canvas.draw_rect(Rect2(center.x - w / 2.0, center.y - h / 2.0, w, h), color)
	canvas.draw_rect(Rect2(center.x - w / 4.0, center.y - h / 4.0, w / 2.0, h / 2.0), Color(1, 1, 1, core_b * 0.8))


static func _draw_glow_circle(canvas: CanvasItem, center: Vector2, r: float, glow_w: float, intensity: float, core_b: float, color: Color) -> void:
	for i in range(3, 0, -1):
		var t: float = float(i) / 3.0
		var gr: float = r + glow_w * t
		var alpha: float = intensity * (1.0 - t) * 0.35
		canvas.draw_circle(center, gr, Color(color, alpha))
	canvas.draw_circle(center, r, color)
	canvas.draw_circle(center, r * 0.5, Color(1, 1, 1, core_b * 0.8))


static func _draw_glow_diamond(canvas: CanvasItem, center: Vector2, w: float, h: float, glow_w: float, intensity: float, core_b: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array([
		center + Vector2(0, -h / 2.0),
		center + Vector2(w / 2.0, 0),
		center + Vector2(0, h / 2.0),
		center + Vector2(-w / 2.0, 0),
	])
	for i in range(2, 0, -1):
		var t: float = float(i) / 2.0
		var scale_f: float = 1.0 + (glow_w / maxf(w, h)) * t
		var glow_pts: PackedVector2Array = PackedVector2Array()
		for p in points:
			glow_pts.append(center + (p - center) * scale_f)
		var alpha: float = intensity * (1.0 - t) * 0.3
		canvas.draw_colored_polygon(glow_pts, Color(color, alpha))
	canvas.draw_colored_polygon(points, color)
	var inner_pts: PackedVector2Array = PackedVector2Array()
	for p in points:
		inner_pts.append(center + (p - center) * 0.4)
	canvas.draw_colored_polygon(inner_pts, Color(1, 1, 1, core_b * 0.6))


static func _draw_glow_arrow(canvas: CanvasItem, center: Vector2, w: float, h: float, glow_w: float, intensity: float, core_b: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array([
		center + Vector2(0, -h / 2.0),
		center + Vector2(w / 2.0, 0),
		center + Vector2(w / 4.0, 0),
		center + Vector2(w / 4.0, h / 2.0),
		center + Vector2(-w / 4.0, h / 2.0),
		center + Vector2(-w / 4.0, 0),
		center + Vector2(-w / 2.0, 0),
	])
	for i in range(2, 0, -1):
		var t: float = float(i) / 2.0
		var scale_f: float = 1.0 + (glow_w / maxf(w, h)) * t
		var glow_pts: PackedVector2Array = PackedVector2Array()
		for p in points:
			glow_pts.append(center + (p - center) * scale_f)
		var alpha: float = intensity * (1.0 - t) * 0.3
		canvas.draw_colored_polygon(glow_pts, Color(color, alpha))
	canvas.draw_colored_polygon(points, color)
