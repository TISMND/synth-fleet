class_name ExplosionEffect
extends Node2D
## Animated explosion VFX for enemy deaths.
## Uses GPU particles for burst + expanding rings drawn with _draw().
## Self-destructs after animation completes.

var explosion_color: Color = Color(1.0, 0.3, 0.5)
var explosion_size: float = 1.0  # multiplier based on enemy size
var enable_screen_shake: bool = false  # only for boss deaths

var _age: float = 0.0
var _duration: float = 0.6
var _flash_alpha: float = 1.0
var _rings: Array[Dictionary] = []
var _debris: Array[Dictionary] = []
var _shake_target: Node2D = null
var _shake_remaining: float = 0.0
var _shake_amplitude: float = 3.0
var _shake_original_pos: Vector2 = Vector2.ZERO

# Additive blend for glow
var _canvas_mat: CanvasItemMaterial = null


func _ready() -> void:
	_canvas_mat = CanvasItemMaterial.new()
	_canvas_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = _canvas_mat

	_duration = 0.5 + explosion_size * 0.15
	_setup_rings()
	_setup_debris()
	_spawn_gpu_burst()

	# Screen shake — offset the game root node (boss deaths only)
	if enable_screen_shake:
		var game_node: Node2D = _find_game_root()
		if game_node:
			_shake_target = game_node
			_shake_original_pos = game_node.position
			_shake_remaining = 0.25
			_shake_amplitude = 2.0 + explosion_size * 1.5


func _find_game_root() -> Node2D:
	# Walk up to find the game orchestrator node
	var node: Node = get_parent()
	while node != null:
		if node is Node2D and node.name != "Enemies" and node.name != "Projectiles":
			# Check if this looks like the game root (has Enemies/Projectiles children)
			if node.has_node("Enemies") or node.has_node("PlayerShip"):
				return node as Node2D
		node = node.get_parent()
	return null


func _setup_rings() -> void:
	var ring_count: int = 2 + int(explosion_size * 0.5)
	for i in ring_count:
		_rings.append({
			"radius": 0.0,
			"max_radius": (20.0 + float(i) * 15.0) * explosion_size,
			"width": 2.5 - float(i) * 0.3,
			"speed": (120.0 + float(i) * 40.0) * explosion_size,
			"alpha": 1.0,
			"delay": float(i) * 0.05,
		})


func _setup_debris() -> void:
	var count: int = 8 + int(explosion_size * 4.0)
	for i in count:
		var angle: float = randf() * TAU
		var spd: float = randf_range(60.0, 200.0) * explosion_size
		var length: float = randf_range(4.0, 12.0) * explosion_size
		_debris.append({
			"pos": Vector2.ZERO,
			"vel": Vector2(cos(angle), sin(angle)) * spd,
			"length": length,
			"angle": angle,
			"alpha": 1.0,
			"lifetime": randf_range(0.2, 0.5),
			"age": 0.0,
		})


func _spawn_gpu_burst() -> void:
	# Main particle burst using VFXFactory textures
	var emitter := GPUParticles2D.new()
	var count: int = 12 + int(explosion_size * 8.0)
	emitter.amount = count
	emitter.lifetime = _duration * 0.8
	emitter.one_shot = true
	emitter.explosiveness = 0.95
	emitter.emitting = true

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	mat.spread = 180.0
	mat.initial_velocity_min = 60.0 * explosion_size
	mat.initial_velocity_max = 180.0 * explosion_size
	mat.damping_min = 40.0
	mat.damping_max = 80.0

	# Color gradient: white-hot -> explosion color -> transparent
	var gradient := Gradient.new()
	var hdr_color := Color(explosion_color.r * 3.0, explosion_color.g * 3.0, explosion_color.b * 3.0, 1.0)
	gradient.set_color(0, Color(3.0, 3.0, 3.0, 1.0))  # white-hot start
	gradient.add_point(0.2, hdr_color)
	gradient.add_point(0.6, Color(explosion_color.r * 1.5, explosion_color.g * 1.5, explosion_color.b * 1.5, 0.6))
	gradient.set_color(gradient.get_point_count() - 1, Color(explosion_color, 0.0))
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = gradient
	mat.color_ramp = color_ramp

	# Scale: expand then shrink
	var scale_curve := CurveTexture.new()
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.6))
	curve.add_point(Vector2(0.2, 1.2))
	curve.add_point(Vector2(1.0, 0.0))
	scale_curve.curve = curve
	mat.scale_curve = scale_curve
	mat.scale_min = 0.4 * explosion_size
	mat.scale_max = 1.0 * explosion_size

	emitter.process_material = mat
	emitter.texture = VFXFactory.get_soft_circle()

	var canvas_mat := CanvasItemMaterial.new()
	canvas_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	emitter.material = canvas_mat

	emitter.finished.connect(emitter.queue_free)
	add_child(emitter)

	# Secondary spark burst — smaller, faster particles
	var spark_emitter := GPUParticles2D.new()
	spark_emitter.amount = 6 + int(explosion_size * 4.0)
	spark_emitter.lifetime = _duration * 0.5
	spark_emitter.one_shot = true
	spark_emitter.explosiveness = 0.9
	spark_emitter.emitting = true

	var spark_mat := ParticleProcessMaterial.new()
	spark_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	spark_mat.spread = 180.0
	spark_mat.initial_velocity_min = 100.0 * explosion_size
	spark_mat.initial_velocity_max = 280.0 * explosion_size
	spark_mat.damping_min = 20.0
	spark_mat.damping_max = 50.0

	var spark_gradient := Gradient.new()
	spark_gradient.set_color(0, Color(3.0, 3.0, 3.0, 1.0))
	spark_gradient.set_color(1, Color(explosion_color, 0.0))
	var spark_ramp := GradientTexture1D.new()
	spark_ramp.gradient = spark_gradient
	spark_mat.color_ramp = spark_ramp
	spark_mat.scale_min = 0.2
	spark_mat.scale_max = 0.5

	spark_emitter.process_material = spark_mat
	spark_emitter.texture = VFXFactory.get_sparkle()

	var spark_canvas := CanvasItemMaterial.new()
	spark_canvas.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	spark_emitter.material = spark_canvas

	spark_emitter.finished.connect(spark_emitter.queue_free)
	add_child(spark_emitter)


func _process(delta: float) -> void:
	_age += delta

	# Update flash
	_flash_alpha = maxf(1.0 - _age / (_duration * 0.3), 0.0)

	# Update rings
	for ring in _rings:
		var r: Dictionary = ring
		var delay: float = float(r["delay"])
		if _age > delay:
			var ring_age: float = _age - delay
			r["radius"] = float(r["radius"]) + float(r["speed"]) * delta
			r["alpha"] = maxf(1.0 - float(r["radius"]) / float(r["max_radius"]), 0.0)

	# Update debris lines
	for d in _debris:
		var debris: Dictionary = d
		var debris_age: float = float(debris["age"])
		debris_age += delta
		debris["age"] = debris_age
		var lt: float = float(debris["lifetime"])
		debris["alpha"] = maxf(1.0 - debris_age / lt, 0.0)
		var vel: Vector2 = debris["vel"] as Vector2
		var pos: Vector2 = debris["pos"] as Vector2
		debris["pos"] = pos + vel * delta
		# Slow down debris
		debris["vel"] = vel * (1.0 - delta * 3.0)

	# Screen shake
	if _shake_remaining > 0.0 and _shake_target != null:
		_shake_remaining -= delta
		if _shake_remaining <= 0.0:
			_shake_target.position = _shake_original_pos
		else:
			var intensity: float = _shake_remaining / 0.25  # normalized 1->0
			var offset_x: float = sin(_age * 60.0) * _shake_amplitude * intensity
			var offset_y: float = cos(_age * 45.0) * _shake_amplitude * intensity * 0.7
			_shake_target.position = _shake_original_pos + Vector2(offset_x, offset_y)

	queue_redraw()

	# Self-destruct when animation is done
	if _age >= _duration:
		if _shake_target != null and _shake_remaining > 0.0:
			_shake_target.position = _shake_original_pos
		queue_free()


func _draw() -> void:
	# Central flash
	if _flash_alpha > 0.01:
		var flash_radius: float = (8.0 + _age * 60.0) * explosion_size
		var flash_hdr: float = 3.0 * _flash_alpha
		# Outer glow
		draw_circle(Vector2.ZERO, flash_radius * 1.5, Color(
			explosion_color.r * flash_hdr * 0.5,
			explosion_color.g * flash_hdr * 0.5,
			explosion_color.b * flash_hdr * 0.5,
			_flash_alpha * 0.3
		))
		# Core flash — white-hot
		draw_circle(Vector2.ZERO, flash_radius, Color(
			flash_hdr, flash_hdr, flash_hdr, _flash_alpha * 0.8
		))

	# Expanding rings
	for ring in _rings:
		var r: Dictionary = ring
		var radius: float = float(r["radius"])
		var alpha: float = float(r["alpha"])
		var w: float = float(r["width"])
		if radius > 0.1 and alpha > 0.01:
			var hdr: float = 2.0 * alpha
			var ring_color := Color(
				explosion_color.r * hdr,
				explosion_color.g * hdr,
				explosion_color.b * hdr,
				alpha * 0.7
			)
			var segments: int = maxi(int(radius * 0.4), 24)
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, segments, ring_color, w, true)

	# Debris lines
	for d in _debris:
		var debris: Dictionary = d
		var alpha: float = float(debris["alpha"])
		if alpha > 0.01:
			var pos: Vector2 = debris["pos"] as Vector2
			var angle: float = float(debris["angle"])
			var length: float = float(debris["length"])
			var end: Vector2 = pos + Vector2(cos(angle), sin(angle)) * length
			var hdr: float = 2.0 * alpha
			var line_color := Color(
				explosion_color.r * hdr,
				explosion_color.g * hdr,
				explosion_color.b * hdr,
				alpha
			)
			draw_line(pos, end, line_color, 1.5, true)
