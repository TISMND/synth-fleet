class_name VFXFactory
extends RefCounted
## Factory for GPU particle emitters and procedural VFX textures.
## Generates soft circle / sparkle / ring textures at runtime (no external assets needed).

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
			mat.spread = 180.0  # full circle
			mat.initial_velocity_min = 80.0
			mat.initial_velocity_max = 200.0
		"directional_flash":
			mat.spread = spread / 2.0
			mat.direction = Vector3(0, -1, 0)
			mat.initial_velocity_min = 100.0
			mat.initial_velocity_max = 250.0
		"ring_pulse":
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
			mat.emission_ring_radius = 8.0
			mat.emission_ring_inner_radius = 6.0
			mat.emission_ring_height = 0.0
			mat.emission_ring_axis = Vector3(0, 0, 1)
			mat.spread = 180.0
			mat.initial_velocity_min = 100.0
			mat.initial_velocity_max = 150.0
		"spiral_burst":
			mat.spread = 180.0
			mat.initial_velocity_min = 80.0
			mat.initial_velocity_max = 160.0
			mat.angular_velocity_min = 200.0
			mat.angular_velocity_max = 400.0

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
			emitter.amount = 8
			mat.spread = 30.0
			mat.direction = Vector3(0, 1, 0)  # emit backward (projectile moves up)
			mat.initial_velocity_min = 10.0
			mat.initial_velocity_max = 40.0
			mat.gravity = Vector3(0, 20, 0)
		"sparkle":
			emitter.amount = 6
			mat.spread = 90.0
			mat.direction = Vector3(0, 1, 0)
			mat.initial_velocity_min = 20.0
			mat.initial_velocity_max = 60.0
			emitter.texture = get_sparkle()
		"afterimage":
			emitter.amount = 4
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

	# Scale down over lifetime
	var scale_curve := CurveTexture.new()
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.8))
	curve.add_point(Vector2(1.0, 0.1))
	scale_curve.curve = curve
	mat.scale_curve = scale_curve
	mat.scale_min = 0.3
	mat.scale_max = 0.7

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

	var emitter := GPUParticles2D.new()
	emitter.amount = count
	emitter.lifetime = lifetime
	emitter.one_shot = true
	emitter.explosiveness = 0.9
	emitter.emitting = true

	var mat := ParticleProcessMaterial.new()
	var speed: float = radius / lifetime

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


static func _generate_white_rect(w: int, h: int) -> ImageTexture:
	var img := Image.create(maxi(w, 4), maxi(h, 4), false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


# ── WorldEnvironment Helper ─────────────────────────────────

## Add a WorldEnvironment with bloom settings to a SubViewport for preview rendering.
static func add_bloom_to_viewport(viewport: SubViewport) -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 0.8
	env.set_glow_level(0, true)
	env.set_glow_level(1, true)
	env.set_glow_level(2, true)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	world_env.environment = env
	viewport.add_child(world_env)
