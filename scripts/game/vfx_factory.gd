class_name VFXFactory
extends RefCounted
## Factory for GPU particle emitters and procedural VFX textures.
## Generates soft circle / sparkle / ring textures at runtime (no external assets needed).

# All ACES bloom Environments created by add_bloom_to_viewport().
# Used by bloom tuning panel to live-update all SubViewport bloom.
static var _bloom_envs: Array[Environment] = []

# Cached textures (generated once on first use)
static var _soft_circle: Texture2D = null
static var _sparkle: Texture2D = null
static var _ring: Texture2D = null
static var _light: Texture2D = null
static var _smoke: Texture2D = null

# Preloaded shaders
static var _energy_shader: Shader = null
static var _plasma_shader: Shader = null
static var _beam_shader: Shader = null
static var _fire_shader: Shader = null
static var _electric_shader: Shader = null
static var _void_shader: Shader = null
static var _ice_shader: Shader = null
static var _toxic_shader: Shader = null
static var _hologram_shader: Shader = null
static var _glitch_shader: Shader = null
static var _pulse_shader: Shader = null
static var _smoke_shader: Shader = null
static var _nebula_dual_shader: Shader = null
static var _nebula_voronoi_shader: Shader = null
static var _nebula_swirl_shader: Shader = null
static var _nebula_wispy_shader: Shader = null
static var _nebula_electric_shader: Shader = null

# Valid fill shader names for validation
const FILL_SHADERS: PackedStringArray = ["energy", "plasma", "beam", "fire", "electric", "void", "ice", "toxic", "hologram", "glitch", "pulse", "smoke", "nebula_dual", "nebula_voronoi", "nebula_swirl", "nebula_wispy", "nebula_electric"]

# Field shader cache + names
static var _field_shaders: Dictionary = {}  # name -> Shader
const FIELD_SHADERS: PackedStringArray = ["force_bubble", "hex_grid", "energy_ripple", "plasma_shield", "particle_ring", "pulse_barrier", "inner_glow", "sun_rays", "shimmer", "hologram"]


# ── Texture Generation ──────────────────────────────────────

static func get_soft_circle() -> Texture2D:
	if _soft_circle == null:
		_soft_circle = _generate_radial_texture(64, 1.0, 0.0)
	return _soft_circle


static func get_sparkle() -> Texture2D:
	if _sparkle == null:
		_sparkle = _generate_sparkle_texture(64)
	return _sparkle


static func get_ring() -> Texture2D:
	if _ring == null:
		_ring = _generate_ring_texture(64, 0.7, 0.9)
	return _ring


static func get_light() -> Texture2D:
	if _light == null:
		_light = _generate_radial_texture(32, 0.8, 0.0)
	return _light


static func get_smoke() -> Texture2D:
	if _smoke == null:
		_smoke = _generate_noise_blob_texture(64)
	return _smoke


static func _generate_radial_texture(size: int, softness: float, inner_radius: float) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center: float = float(size) / 2.0
	for y in size:
		for x in size:
			var dist: float = Vector2(float(x) - center, float(y) - center).length() / center
			var alpha: float = 0.0
			if dist <= 1.0:
				if inner_radius > 0.0:
					alpha = _smoothstep(inner_radius - softness * 0.3, inner_radius, dist) * _smoothstep(1.0, 1.0 - softness * 0.3, dist)
				else:
					alpha = pow(1.0 - clampf(dist, 0.0, 1.0), softness + 0.5)
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)


static func _generate_sparkle_texture(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center: float = float(size) / 2.0
	for y in size:
		for x in size:
			var dx: float = float(x) - center
			var dy: float = float(y) - center
			var dist: float = Vector2(dx, dy).length() / center
			# 4-point star: bright along axes, dim elsewhere
			var ax: float = 1.0 - clampf(absf(dx) / center, 0.0, 1.0)
			var ay: float = 1.0 - clampf(absf(dy) / center, 0.0, 1.0)
			var star: float = maxf(ax * ax * ax * (1.0 - clampf(absf(dy) / (center * 0.15), 0.0, 1.0)),
								   ay * ay * ay * (1.0 - clampf(absf(dx) / (center * 0.15), 0.0, 1.0)))
			# Add soft radial center
			var radial: float = pow(maxf(1.0 - dist, 0.0), 2.0) * 0.5
			var alpha: float = clampf(star + radial, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)


static func _generate_ring_texture(size: int, inner: float, outer: float) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center: float = float(size) / 2.0
	for y in size:
		for x in size:
			var dist: float = Vector2(float(x) - center, float(y) - center).length() / center
			var alpha: float = _smoothstep(inner - 0.1, inner, dist) * _smoothstep(outer + 0.1, outer, dist)
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)


static func _generate_noise_blob_texture(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center: float = float(size) / 2.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for y in size:
		for x in size:
			var dist: float = Vector2(float(x) - center, float(y) - center).length() / center
			var noise_val: float = rng.randf_range(0.6, 1.0)
			var alpha: float = pow(maxf(1.0 - dist, 0.0), 1.5) * noise_val
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	# Reset seed for reproducibility isn't critical for visual noise
	return ImageTexture.create_from_image(img)


static func _smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t: float = clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


# ── GPU Particle Emitters ───────────────────────────────────

## Create a muzzle flash GPUParticles2D (one_shot, auto-frees via lifetime).
static func create_muzzle_emitter(layer: Dictionary, color: Color) -> GPUParticles2D:
	var mtype: String = str(layer.get("type", "radial_burst"))
	var params: Dictionary = layer.get("params", {}) as Dictionary
	var count: int = int(params.get("particle_count", 6))
	var lifetime: float = float(params.get("lifetime", 0.3))
	var spread: float = float(params.get("spread_angle", 360.0))

	var emitter := GPUParticles2D.new()
	emitter.amount = count
	emitter.lifetime = lifetime
	emitter.one_shot = true
	emitter.explosiveness = 0.95
	emitter.emitting = true

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT

	match mtype:
		"radial_burst":
			mat.spread = spread / 2.0
			mat.initial_velocity_min = 80.0
			mat.initial_velocity_max = 200.0
		"directional_flash":
			mat.spread = spread / 2.0
			mat.direction = Vector3(0, -1, 0)
			mat.initial_velocity_min = 100.0
			mat.initial_velocity_max = 250.0
		"ring_pulse":
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
			mat.emission_ring_radius = 24.0
			mat.emission_ring_inner_radius = 20.0
			mat.emission_ring_height = 0.0
			mat.emission_ring_axis = Vector3(0, 0, 1)
			mat.spread = spread / 2.0
			mat.initial_velocity_min = 40.0
			mat.initial_velocity_max = 80.0
			emitter.texture = get_ring()
		"spiral_burst":
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
			mat.emission_ring_radius = 4.0
			mat.emission_ring_inner_radius = 0.0
			mat.emission_ring_height = 0.0
			mat.emission_ring_axis = Vector3(0, 0, 1)
			mat.spread = spread / 2.0
			mat.initial_velocity_min = 80.0
			mat.initial_velocity_max = 160.0
			mat.angular_velocity_min = 200.0
			mat.angular_velocity_max = 400.0
			mat.orbit_velocity_min = 0.3
			mat.orbit_velocity_max = 0.5

	# Color gradient: weapon_color -> transparent
	var gradient := Gradient.new()
	var hdr_color := Color(color.r * 2.0, color.g * 2.0, color.b * 2.0, 1.0)
	gradient.set_color(0, hdr_color)
	gradient.add_point(0.5, Color(color.r * 1.2, color.g * 1.2, color.b * 1.2, 0.6))
	gradient.set_color(gradient.get_point_count() - 1, Color(color, 0.0))
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp

	# Scale curve: big -> small
	var scale_curve := CurveTexture.new()
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	scale_curve.curve = curve
	mat.scale_curve = scale_curve
	mat.scale_min = 0.5
	mat.scale_max = 1.2

	mat.damping_min = 20.0
	mat.damping_max = 40.0

	emitter.process_material = mat
	# Only set default texture if not already assigned in match (e.g. ring_pulse uses ring)
	if emitter.texture == null:
		emitter.texture = get_soft_circle()

	# Additive blending for glow
	var canvas_mat := CanvasItemMaterial.new()
	canvas_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	emitter.material = canvas_mat

	# Auto-free after particles expire
	emitter.finished.connect(emitter.queue_free)

	return emitter


## Create a trail GPUParticles2D (continuous emission, attach as child of projectile).
static func create_trail_emitter(layer: Dictionary, color: Color) -> GPUParticles2D:
	var ttype: String = str(layer.get("type", "particle"))
	var params: Dictionary = layer.get("params", {}) as Dictionary
	var lifetime: float = float(params.get("lifetime", 0.2))

	var emitter := GPUParticles2D.new()
	emitter.lifetime = lifetime
	emitter.one_shot = false
	emitter.explosiveness = 0.0

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT

	match ttype:
		"particle":
			emitter.amount = int(params.get("amount", 8))
			mat.spread = 30.0
			mat.direction = Vector3(0, 1, 0)  # emit backward (projectile moves up)
			mat.initial_velocity_min = 10.0
			mat.initial_velocity_max = 40.0
			mat.gravity = Vector3(0, 20, 0)
		"sparkle":
			emitter.amount = int(params.get("amount", 6))
			mat.spread = 90.0
			mat.direction = Vector3(0, 1, 0)
			mat.initial_velocity_min = 20.0
			mat.initial_velocity_max = 60.0
			emitter.texture = get_sparkle()
		"afterimage":
			emitter.amount = int(params.get("amount", 4))
			mat.spread = 0.0
			mat.initial_velocity_min = 0.0
			mat.initial_velocity_max = 0.0

	if ttype != "sparkle":
		emitter.texture = get_soft_circle()

	# Color gradient
	var gradient := Gradient.new()
	var hdr_color := Color(color.r * 1.5, color.g * 1.5, color.b * 1.5, 0.8)
	gradient.set_color(0, hdr_color)
	gradient.set_color(1, Color(color, 0.0))
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp

	# Scale curve: afterimage holds size then fades, others shrink
	var scale_curve := CurveTexture.new()
	var curve := Curve.new()
	if ttype == "afterimage":
		curve.add_point(Vector2(0.0, 1.0))
		curve.add_point(Vector2(0.7, 0.9))
		curve.add_point(Vector2(1.0, 0.3))
		mat.scale_min = 0.8
		mat.scale_max = 1.2
	else:
		curve.add_point(Vector2(0.0, 0.8))
		curve.add_point(Vector2(1.0, 0.1))
		mat.scale_min = 0.3
		mat.scale_max = 0.7
	scale_curve.curve = curve
	mat.scale_curve = scale_curve

	emitter.process_material = mat

	# Additive blending
	var canvas_mat := CanvasItemMaterial.new()
	canvas_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	emitter.material = canvas_mat

	return emitter


## Create an impact GPUParticles2D (one_shot, auto-frees).
static func create_impact_emitter(layer: Dictionary, color: Color) -> GPUParticles2D:
	var itype: String = str(layer.get("type", "burst"))
	var params: Dictionary = layer.get("params", {}) as Dictionary
	var count: int = int(params.get("particle_count", 8))
	var lifetime: float = float(params.get("lifetime", 0.4))
	var radius: float = float(params.get("radius", 20.0))
	var speed_scale: float = float(params.get("speed_scale", 1.0))

	var emitter := GPUParticles2D.new()
	emitter.amount = count
	emitter.lifetime = lifetime
	emitter.one_shot = true
	emitter.explosiveness = 0.9
	emitter.emitting = true

	var mat := ParticleProcessMaterial.new()
	var speed: float = (radius / lifetime) * speed_scale

	match itype:
		"burst":
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
			mat.spread = 180.0
			mat.initial_velocity_min = speed * 0.5
			mat.initial_velocity_max = speed * 1.2
			emitter.texture = get_soft_circle()
		"ring_expand":
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
			mat.emission_ring_radius = 4.0
			mat.emission_ring_inner_radius = 2.0
			mat.emission_ring_height = 0.0
			mat.emission_ring_axis = Vector3(0, 0, 1)
			mat.spread = 180.0
			mat.initial_velocity_min = speed * 1.0
			mat.initial_velocity_max = speed * 1.5
			emitter.texture = get_ring()
		"shatter_lines":
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
			mat.spread = 180.0
			mat.initial_velocity_min = speed * 0.4
			mat.initial_velocity_max = speed * 1.5
			emitter.texture = get_sparkle()
		"nova_flash":
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
			mat.spread = 180.0
			mat.initial_velocity_min = speed * 1.5
			mat.initial_velocity_max = speed * 2.5
			emitter.texture = get_soft_circle()
			emitter.amount = count + 4  # extra for nova
		"ripple":
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
			mat.emission_ring_radius = 2.0
			mat.emission_ring_inner_radius = 0.0
			mat.emission_ring_height = 0.0
			mat.emission_ring_axis = Vector3(0, 0, 1)
			mat.spread = 180.0
			mat.initial_velocity_min = speed * 0.6
			mat.initial_velocity_max = speed * 1.0
			emitter.texture = get_ring()

	# Color: HDR weapon color -> dim -> transparent
	var gradient := Gradient.new()
	var hdr_color := Color(color.r * 2.5, color.g * 2.5, color.b * 2.5, 1.0)
	gradient.set_color(0, hdr_color)
	gradient.add_point(0.3, Color(color.r * 1.5, color.g * 1.5, color.b * 1.5, 0.8))
	gradient.set_color(gradient.get_point_count() - 1, Color(color, 0.0))
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp

	# Scale
	var scale_curve := CurveTexture.new()
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.2))
	curve.add_point(Vector2(0.5, 0.8))
	curve.add_point(Vector2(1.0, 0.0))
	scale_curve.curve = curve
	mat.scale_curve = scale_curve
	mat.scale_min = 0.5
	mat.scale_max = 1.5

	mat.damping_min = 30.0
	mat.damping_max = 60.0

	emitter.process_material = mat

	# Additive
	var canvas_mat := CanvasItemMaterial.new()
	canvas_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	emitter.material = canvas_mat

	emitter.finished.connect(emitter.queue_free)
	return emitter


## Create a "TV shutoff" deflect impact — a bright flash that collapses into a
## horizontal line and fades. Sprite + tween based (not particles). Auto-frees.
static func create_deflect_impact(color: Color, width: float = 40.0, duration: float = 0.35) -> Node2D:
	var root := Node2D.new()

	# HDR flash color for bloom
	var hdr := Color(color.r * 3.0, color.g * 3.0, color.b * 3.0, 1.0)

	# Create a white rect sprite to animate
	var sprite := Sprite2D.new()
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.scale = Vector2(width / 4.0, width * 0.6 / 4.0)
	sprite.modulate = hdr
	root.add_child(sprite)

	# Additive blend for glow
	var canvas_mat := CanvasItemMaterial.new()
	canvas_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.material = canvas_mat

	# Animate: flash -> squish to line -> shrink line -> fade
	root.set_meta("_anim_sprite", sprite)
	root.set_meta("_anim_width", width)
	root.set_meta("_anim_duration", duration)
	root.set_meta("_anim_hdr", hdr)
	root.ready.connect(func() -> void:
		var s: Sprite2D = root.get_meta("_anim_sprite") as Sprite2D
		var w: float = float(root.get_meta("_anim_width"))
		var dur: float = float(root.get_meta("_anim_duration"))
		var hdr_col: Color = root.get_meta("_anim_hdr") as Color

		var _start_scale := Vector2(w / 4.0, w * 0.6 / 4.0)
		var line_scale := Vector2(w * 1.2 / 4.0, 0.3 / 4.0)  # Wide thin line
		var end_scale := Vector2(2.0 / 4.0, 0.15 / 4.0)  # Tiny dot

		var tween := root.create_tween()
		tween.set_parallel(true)

		# Phase 1 (0 -> 40% of duration): Squish into horizontal line
		tween.tween_property(s, "scale", line_scale, dur * 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(s, "modulate", hdr_col, dur * 0.1)

		# Phase 2 (40% -> 100%): Shrink line and fade out
		tween.tween_property(s, "scale", end_scale, dur * 0.6).set_delay(dur * 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(s, "modulate", Color(hdr_col, 0.0), dur * 0.6).set_delay(dur * 0.4).set_ease(Tween.EASE_IN)

		tween.set_parallel(false)
		tween.tween_callback(root.queue_free)
	)

	return root


# ── Shader Sprite Helpers ───────────────────────────────────

static func _load_energy_shader() -> Shader:
	if _energy_shader == null:
		_energy_shader = load("res://assets/shaders/projectile_energy.gdshader") as Shader
	return _energy_shader


static func _load_plasma_shader() -> Shader:
	if _plasma_shader == null:
		_plasma_shader = load("res://assets/shaders/projectile_plasma.gdshader") as Shader
	return _plasma_shader


static func _load_beam_shader() -> Shader:
	if _beam_shader == null:
		_beam_shader = load("res://assets/shaders/projectile_beam.gdshader") as Shader
	return _beam_shader


static func _load_fire_shader() -> Shader:
	if _fire_shader == null:
		_fire_shader = load("res://assets/shaders/projectile_fire.gdshader") as Shader
	return _fire_shader


static func _load_electric_shader() -> Shader:
	if _electric_shader == null:
		_electric_shader = load("res://assets/shaders/projectile_electric.gdshader") as Shader
	return _electric_shader


static func _load_void_shader() -> Shader:
	if _void_shader == null:
		_void_shader = load("res://assets/shaders/projectile_void.gdshader") as Shader
	return _void_shader


static func _load_ice_shader() -> Shader:
	if _ice_shader == null:
		_ice_shader = load("res://assets/shaders/projectile_ice.gdshader") as Shader
	return _ice_shader


static func _load_toxic_shader() -> Shader:
	if _toxic_shader == null:
		_toxic_shader = load("res://assets/shaders/projectile_toxic.gdshader") as Shader
	return _toxic_shader


static func _load_hologram_shader() -> Shader:
	if _hologram_shader == null:
		_hologram_shader = load("res://assets/shaders/projectile_hologram.gdshader") as Shader
	return _hologram_shader


static func _load_glitch_shader() -> Shader:
	if _glitch_shader == null:
		_glitch_shader = load("res://assets/shaders/projectile_glitch.gdshader") as Shader
	return _glitch_shader


static func _load_pulse_shader() -> Shader:
	if _pulse_shader == null:
		_pulse_shader = load("res://assets/shaders/projectile_pulse.gdshader") as Shader
	return _pulse_shader


static func _load_smoke_shader() -> Shader:
	if _smoke_shader == null:
		_smoke_shader = load("res://assets/shaders/projectile_smoke.gdshader") as Shader
	return _smoke_shader


static func _load_nebula_dual_shader() -> Shader:
	if _nebula_dual_shader == null:
		_nebula_dual_shader = load("res://assets/shaders/projectile_nebula_dual.gdshader") as Shader
	return _nebula_dual_shader


static func _load_nebula_voronoi_shader() -> Shader:
	if _nebula_voronoi_shader == null:
		_nebula_voronoi_shader = load("res://assets/shaders/projectile_nebula_voronoi.gdshader") as Shader
	return _nebula_voronoi_shader


static func _load_nebula_swirl_shader() -> Shader:
	if _nebula_swirl_shader == null:
		_nebula_swirl_shader = load("res://assets/shaders/projectile_nebula_swirl.gdshader") as Shader
	return _nebula_swirl_shader


static func _load_nebula_wispy_shader() -> Shader:
	if _nebula_wispy_shader == null:
		_nebula_wispy_shader = load("res://assets/shaders/projectile_nebula_wispy.gdshader") as Shader
	return _nebula_wispy_shader


static func _load_nebula_electric_shader() -> Shader:
	if _nebula_electric_shader == null:
		_nebula_electric_shader = load("res://assets/shaders/projectile_nebula_electric.gdshader") as Shader
	return _nebula_electric_shader


## Create a Sprite2D with a shader material for shader-based shape types.
## Returns null if the shape type is not shader-based.
static func create_shader_sprite(shape_type: String, color: Color, width: float, height: float) -> Sprite2D:
	var shader: Shader = null
	match shape_type:
		"energy":
			shader = _load_energy_shader()
		"plasma":
			shader = _load_plasma_shader()
		"beam_shader":
			shader = _load_beam_shader()
		_:
			return null

	if shader == null:
		return null

	var sprite := Sprite2D.new()
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("weapon_color", color)
	sprite.material = mat

	# Use a white texture sized to the projectile dimensions
	var tex := _generate_white_rect(int(ceilf(width)), int(ceilf(height)))
	sprite.texture = tex

	# Additive blend on the sprite's CanvasItem
	var canvas_mat := CanvasItemMaterial.new()
	canvas_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# Note: material is already ShaderMaterial, so we set the CanvasItem light mode instead
	# Actually for canvas_item shaders, the blend comes from the material blend mode
	# We'll handle this by making the shader output HDR values that bloom picks up

	return sprite


## Get a fill shader by name (for ProjectileStyle system).
static func get_fill_shader(shader_name: String) -> Shader:
	match shader_name:
		"energy":
			return _load_energy_shader()
		"plasma":
			return _load_plasma_shader()
		"beam":
			return _load_beam_shader()
		"fire":
			return _load_fire_shader()
		"electric":
			return _load_electric_shader()
		"void":
			return _load_void_shader()
		"ice":
			return _load_ice_shader()
		"toxic":
			return _load_toxic_shader()
		"hologram":
			return _load_hologram_shader()
		"glitch":
			return _load_glitch_shader()
		"pulse":
			return _load_pulse_shader()
		"smoke":
			return _load_smoke_shader()
		"nebula_dual":
			return _load_nebula_dual_shader()
		"nebula_voronoi":
			return _load_nebula_voronoi_shader()
		"nebula_swirl":
			return _load_nebula_swirl_shader()
		"nebula_wispy":
			return _load_nebula_wispy_shader()
		"nebula_electric":
			return _load_nebula_electric_shader()
	return _load_energy_shader()


## Create a Sprite2D from a ProjectileStyle (mask + fill shader + color).
## Masks in res://data/ are loaded via Image (not engine import).
static func create_styled_sprite(style: ProjectileStyle, color: Color) -> Sprite2D:
	var shader: Shader = get_fill_shader(style.fill_shader)
	if shader == null:
		push_error("VFXFactory: shader '%s' failed to load for style '%s'" % [style.fill_shader, style.id])
		return null

	var sprite := Sprite2D.new()
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("weapon_color", color)

	# Apply shader params from style
	for param_name in style.shader_params:
		mat.set_shader_parameter(param_name, float(style.shader_params[param_name]))

	# Load mask: procedural shape or PNG file
	if style.procedural_mask_shape != "":
		var mask_tex: ImageTexture = generate_procedural_mask(style.procedural_mask_shape, style.procedural_mask_feather)
		if mask_tex:
			mat.set_shader_parameter("mask_texture", mask_tex)
			mat.set_shader_parameter("use_mask", true)
	elif style.mask_path != "":
		var img := Image.new()
		var err: Error = img.load(style.mask_path)
		if err == OK:
			var mask_tex: ImageTexture = ImageTexture.create_from_image(img)
			mat.set_shader_parameter("mask_texture", mask_tex)
			mat.set_shader_parameter("use_mask", true)

	# Secondary color for nebula_dual shader
	if style.fill_shader == "nebula_dual":
		mat.set_shader_parameter("secondary_color", style.secondary_color)

	sprite.material = mat

	# White rect texture sized to base_scale
	var w: int = int(ceilf(style.base_scale.x))
	var h: int = int(ceilf(style.base_scale.y))
	sprite.texture = _generate_white_rect(w, h)

	# Flip UV.y to reverse shader scroll direction
	sprite.flip_v = style.flip_shader

	return sprite


# ── Procedural Mask Generation ─────────────────────────────

static var _procedural_mask_cache: Dictionary = {}  # "shape_feather" -> ImageTexture


static func generate_procedural_mask(shape: String, feather: float) -> ImageTexture:
	var cache_key: String = shape + "_" + str(snappedi(int(feather * 100), 1))
	if _procedural_mask_cache.has(cache_key):
		return _procedural_mask_cache[cache_key] as ImageTexture

	var size: int = 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center: float = float(size) / 2.0
	var half: float = center

	for y in size:
		for x in size:
			var dx: float = (float(x) - center) / half
			var dy: float = (float(y) - center) / half
			var dist: float = _mask_shape_distance(shape, dx, dy)
			var alpha: float = _smoothstep(1.0, 1.0 - maxf(feather, 0.01), dist)
			img.set_pixel(x, y, Color(1, 1, 1, alpha))

	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_procedural_mask_cache[cache_key] = tex
	return tex


static func _mask_shape_distance(shape: String, dx: float, dy: float) -> float:
	match shape:
		"circle":
			return Vector2(dx, dy).length()
		"diamond":
			return absf(dx) + absf(dy)
		"rounded_rect":
			var ax: float = maxf(absf(dx) - 0.6, 0.0)
			var ay: float = maxf(absf(dy) - 0.6, 0.0)
			return maxf(absf(dx), absf(dy)) * 0.7 + Vector2(ax, ay).length() * 0.6
		"star":
			var angle: float = atan2(dy, dx)
			var r: float = Vector2(dx, dy).length()
			var star_shape: float = 0.6 + 0.4 * cos(angle * 5.0)
			return r / star_shape
		"hexagon":
			var ax: float = absf(dx)
			var ay: float = absf(dy)
			return maxf(ax * 0.866 + ay * 0.5, ay)
		"arrow":
			var ay: float = absf(dy)
			# Arrow pointing up: wider at bottom, narrow at top
			var width: float = lerpf(0.8, 0.15, (dy + 1.0) * 0.5)
			var edge_x: float = absf(dx) / maxf(width, 0.01)
			return maxf(edge_x, ay * 0.5)
		"cross":
			var ax: float = absf(dx)
			var ay: float = absf(dy)
			var cross: float = minf(ax, ay)
			var outer: float = maxf(ax, ay)
			return lerpf(cross, outer, 0.6)
	return Vector2(dx, dy).length()  # fallback circle


static func _generate_white_rect(w: int, h: int) -> ImageTexture:
	var img := Image.create(maxi(w, 4), maxi(h, 4), false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


# ── WorldEnvironment Helper ─────────────────────────────────

## Add a WorldEnvironment with ACES bloom to a SubViewport.
## All bloom in the project happens via this function — root viewport bloom is disabled.
## Reads glow params from ThemeManager so Style Editor sliders affect all viewports.
## Add ACES tonemapping to a SubViewport. Glow is DISABLED here — Godot's 2D
## bloom only runs on the root viewport (ThemeManager's WorldEnvironment).
## SubViewport ACES ensures consistent color mapping; root bloom is the single
## bloom source for all content.
static func add_bloom_to_viewport(viewport: SubViewport) -> void:
	viewport.use_hdr_2d = true
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = false  # Root viewport handles all bloom
	world_env.environment = env
	viewport.add_child(world_env)


## Live-update all tracked ACES bloom environments from ThemeManager values.
## Called by bloom tuning panel when sliders change.
static func update_all_bloom() -> void:
	var intensity: float = ThemeManager.get_float("glow_intensity")
	var bloom: float = ThemeManager.get_float("glow_bloom")
	var threshold: float = ThemeManager.get_float("glow_hdr_threshold")
	var levels: Array[bool] = []
	for i in 7:
		levels.append(ThemeManager.get_float("glow_level_%d" % i) > 0.5)

	for env in _bloom_envs:
		if env and is_instance_valid(env):
			env.glow_intensity = intensity
			env.glow_bloom = bloom
			env.glow_hdr_threshold = threshold
			for i in 7:
				env.set_glow_level(i, levels[i])


# ── Field Shader Helpers ──────────────────────────────────

## Get a field shader by name (lazy-load cached).
static func get_field_shader(shader_name: String) -> Shader:
	if _field_shaders.has(shader_name):
		return _field_shaders[shader_name] as Shader
	var path: String = "res://assets/shaders/field_" + shader_name + ".gdshader"
	var shader: Shader = load(path) as Shader
	if shader:
		_field_shaders[shader_name] = shader
	else:
		push_warning("VFXFactory: field shader '%s' not found at %s" % [shader_name, path])
	return shader


## Create a ShaderMaterial configured for a FieldStyle at a given radius.
static func create_field_material(style: FieldStyle, _radius: float) -> ShaderMaterial:
	var shader: Shader = get_field_shader(style.field_shader)
	if not shader:
		shader = get_field_shader("force_bubble")
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("field_color", style.color)
	mat.set_shader_parameter("brightness", style.glow_intensity)
	mat.set_shader_parameter("radius_ratio", style.radius_ratio)
	mat.set_shader_parameter("pulse_intensity", 0.0)
	mat.set_shader_parameter("pulse_tint", style.pulse_tint)
	mat.set_shader_parameter("opacity", 1.0)
	# Apply per-shader params
	for param_name in style.shader_params:
		mat.set_shader_parameter(param_name, float(style.shader_params[param_name]))
	return mat
