class_name EffectLayerRenderer
extends RefCounted
## Static utility class for composable effect layer rendering.
## Centralizes all HDR draw helpers and layer resolution logic.
## Used by Projectile, HardpointController, and all preview contexts.
## With Forward+ renderer and bloom, shapes use HDR colors (values > 1.0) instead of
## multi-layer alpha tricks — the engine bloom creates real soft glow halos.

const MAX_LAYERS_PER_SLOT: int = 4


## Extract color from effect layer dict, with fallback.
static func get_layer_color(layer_dict: Dictionary, fallback: Color) -> Color:
	if layer_dict.has("color"):
		var c: Array = layer_dict["color"] as Array
		if c.size() >= 3:
			var a: float = float(c[3]) if c.size() >= 4 else 1.0
			return Color(float(c[0]), float(c[1]), float(c[2]), a)
	return fallback

# Shape types that use shaders instead of draw_* calls
const SHADER_SHAPES: PackedStringArray = ["energy", "plasma", "beam_shader"]

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
		return result

	# v2 profile
	var defaults: Dictionary = profile.get("defaults", {}) as Dictionary
	for slot in ["shape", "motion", "muzzle", "trail", "impact"]:
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


## Check if any shape layer in the resolved set is a shader type.
static func has_shader_shape(layers: Array) -> bool:
	for layer in layers:
		var layer_dict: Dictionary = layer as Dictionary
		var stype: String = str(layer_dict.get("type", "rect"))
		if stype in SHADER_SHAPES:
			return true
	return false


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

## Draw all shape layers stacked (HDR bloom-ready).
## Skips shader-based shapes (those are handled by Sprite2D children on the Projectile).
static func draw_shape_stack(canvas: CanvasItem, center: Vector2, layers: Array, color: Color, age: float) -> void:
	if layers.is_empty():
		# Default fallback shape
		_draw_hdr_rect(canvas, center, 6.0, 12.0, 0.8, color)
		return
	for layer in layers:
		var layer_dict: Dictionary = layer as Dictionary
		var stype: String = str(layer_dict.get("type", "rect"))
		# Skip shader shapes — rendered by Sprite2D
		if stype in SHADER_SHAPES:
			continue
		var params: Dictionary = layer_dict.get("params", {}) as Dictionary
		var intensity: float = float(params.get("glow_intensity", 0.8))
		match stype:
			"rect":
				var w: float = float(params.get("width", 6.0))
				var h: float = float(params.get("height", 12.0))
				_draw_hdr_rect(canvas, center, w, h, intensity, color)
			"streak":
				var w: float = float(params.get("width", 3.0))
				var h: float = float(params.get("height", 20.0))
				_draw_hdr_rect(canvas, center, w, h, intensity, color)
			"orb":
				var r: float = float(params.get("radius", 4.0))
				_draw_hdr_circle(canvas, center, r, intensity, color)
			"diamond":
				var w: float = float(params.get("width", 8.0))
				var h: float = float(params.get("height", 14.0))
				_draw_hdr_diamond(canvas, center, w, h, intensity, color)
			"arrow":
				var w: float = float(params.get("width", 8.0))
				var h: float = float(params.get("height", 16.0))
				_draw_hdr_arrow(canvas, center, w, h, intensity, color)
			"pulse_orb":
				var r: float = float(params.get("radius", 5.0))
				var pulse: float = 1.0 + 0.3 * sin(age * 10.0)
				_draw_hdr_circle(canvas, center, r * pulse, intensity * 1.2, color)
			_:
				_draw_hdr_rect(canvas, center, 6.0, 12.0, intensity, color)


# ── Muzzle Spawning (legacy dict particles) ──

## Generate muzzle particles from all muzzle layers. Returns flat Array of particle dicts.
## Note: For actual GPU muzzle effects, use VFXFactory.create_muzzle_emitter() instead.
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
			# HDR color for bloom on ribbon trails
			var hdr_mult: float = 1.0 + alpha * 1.5
			var line_color := Color(color.r * hdr_mult, color.g * hdr_mult, color.b * hdr_mult, alpha)
			canvas.draw_line(from_pt, to_pt, line_color, maxf(w, 1.0))


# ── Impact Spawning ─────────────────────────────────────────

## Generate impact particles from all impact layers. Returns flat Array of particle dicts.
## Note: For actual GPU impact effects, use VFXFactory.create_impact_emitter() instead.
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


# ── Trail Particle Drawing (shared helper) ──────────────────

## Draw a single trail/muzzle/impact particle with HDR glow.
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
	# HDR outer glow (bloom picks this up)
	canvas.draw_circle(pos, sz * 2.0, Color(col.r * 1.5, col.g * 1.5, col.b * 1.5, alpha * 0.3))
	# Core
	canvas.draw_circle(pos, sz, Color(col.r * 2.0, col.g * 2.0, col.b * 2.0, alpha))
	# White-hot center
	canvas.draw_circle(pos, sz * 0.4, Color(2.0, 2.0, 2.0, alpha * 0.6))


# ── HDR Glow Primitives ─────────────────────────────────────
# Instead of 3-layer alpha loops, draw shapes with HDR brightness values.
# The engine's bloom post-process creates the glow halo automatically.

static func _draw_hdr_rect(canvas: CanvasItem, center: Vector2, w: float, h: float, intensity: float, color: Color) -> void:
	var hdr: float = 1.0 + intensity
	# Outer glow rect (slightly larger, bloom catches it)
	var glow_rect: Rect2 = Rect2(center.x - w / 2.0 - 2.0, center.y - h / 2.0 - 2.0, w + 4.0, h + 4.0)
	canvas.draw_rect(glow_rect, Color(color.r * hdr, color.g * hdr, color.b * hdr, 0.4))
	# Core shape at HDR brightness
	canvas.draw_rect(Rect2(center.x - w / 2.0, center.y - h / 2.0, w, h), Color(color.r * hdr, color.g * hdr, color.b * hdr, 1.0))
	# White inner core highlight
	canvas.draw_rect(Rect2(center.x - w / 4.0, center.y - h / 4.0, w / 2.0, h / 2.0), Color(2.0, 2.0, 2.0, 0.7))


static func _draw_hdr_circle(canvas: CanvasItem, center: Vector2, r: float, intensity: float, color: Color) -> void:
	var hdr: float = 1.0 + intensity
	# Outer glow
	canvas.draw_circle(center, r + 2.0, Color(color.r * hdr, color.g * hdr, color.b * hdr, 0.4))
	# Core
	canvas.draw_circle(center, r, Color(color.r * hdr, color.g * hdr, color.b * hdr, 1.0))
	# White center
	canvas.draw_circle(center, r * 0.5, Color(2.0, 2.0, 2.0, 0.7))


static func _draw_hdr_diamond(canvas: CanvasItem, center: Vector2, w: float, h: float, intensity: float, color: Color) -> void:
	var hdr: float = 1.0 + intensity
	var points: PackedVector2Array = PackedVector2Array([
		center + Vector2(0, -h / 2.0),
		center + Vector2(w / 2.0, 0),
		center + Vector2(0, h / 2.0),
		center + Vector2(-w / 2.0, 0),
	])
	# Core
	canvas.draw_colored_polygon(points, Color(color.r * hdr, color.g * hdr, color.b * hdr, 1.0))
	# White inner
	var inner_pts: PackedVector2Array = PackedVector2Array()
	for p in points:
		inner_pts.append(center + (p - center) * 0.4)
	canvas.draw_colored_polygon(inner_pts, Color(2.0, 2.0, 2.0, 0.6))


static func _draw_hdr_arrow(canvas: CanvasItem, center: Vector2, w: float, h: float, intensity: float, color: Color) -> void:
	var hdr: float = 1.0 + intensity
	var points: PackedVector2Array = PackedVector2Array([
		center + Vector2(0, -h / 2.0),
		center + Vector2(w / 2.0, 0),
		center + Vector2(w / 4.0, 0),
		center + Vector2(w / 4.0, h / 2.0),
		center + Vector2(-w / 4.0, h / 2.0),
		center + Vector2(-w / 4.0, 0),
		center + Vector2(-w / 2.0, 0),
	])
	canvas.draw_colored_polygon(points, Color(color.r * hdr, color.g * hdr, color.b * hdr, 1.0))
