class_name Projectile
extends Area2D
## Projectile fired by hardpoints. Uses EffectLayerRenderer for composable effect layers.
## GPU particles for trails, shader sprites for energy/plasma shapes, HDR bloom for glow.

var direction: Vector2 = Vector2.UP
var speed: float = 600.0
var damage: int = 10
var weapon_color: Color = Color.CYAN
var effect_profile: Dictionary = {}
var trigger_index: int = -1
var projectile_style: ProjectileStyle = null

var _age: float = 0.0
var _base_x: float = 0.0
var _trail_points: Array = []
var _trail_particles: Array = []

# Resolved once at spawn — layer arrays per slot
var _resolved_layers: Dictionary = {}
var _beat_fx_particles: Array = []
var _has_shader_shape: bool = false
var _shader_sprite: Sprite2D = null
var _gpu_trail_emitters: Array = []


func _ready() -> void:
	collision_layer = 2
	collision_mask = 4
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4, 12)
	shape.shape = rect
	add_child(shape)
	area_entered.connect(_on_area_entered)
	_base_x = position.x
	# Resolve layers once at spawn
	_resolved_layers = EffectLayerRenderer.resolve_layers(effect_profile, trigger_index)

	# Setup styled sprite (ProjectileStyle takes priority over shape layers)
	if projectile_style:
		_setup_styled_sprite()
	else:
		var shape_layers: Array = _resolved_layers.get("shape", []) as Array
		_has_shader_shape = EffectLayerRenderer.has_shader_shape(shape_layers)
		if _has_shader_shape:
			_setup_shader_sprite(shape_layers)

	# Setup GPU trail emitters
	_setup_gpu_trails()


func _setup_styled_sprite() -> void:
	_has_shader_shape = true
	_shader_sprite = VFXFactory.create_styled_sprite(projectile_style, weapon_color)
	if _shader_sprite:
		add_child(_shader_sprite)


func _setup_shader_sprite(shape_layers: Array) -> void:
	for layer in shape_layers:
		var layer_dict: Dictionary = layer as Dictionary
		var stype: String = str(layer_dict.get("type", "rect"))
		if stype in EffectLayerRenderer.SHADER_SHAPES:
			var params: Dictionary = layer_dict.get("params", {}) as Dictionary
			var w: float = float(params.get("width", 24.0))
			var h: float = float(params.get("height", 32.0))
			_shader_sprite = VFXFactory.create_shader_sprite(stype, weapon_color, w, h)
			if _shader_sprite:
				add_child(_shader_sprite)
			break  # only one shader shape


func _setup_gpu_trails() -> void:
	var trail_layers: Array = _resolved_layers.get("trail", []) as Array
	for layer in trail_layers:
		var layer_dict: Dictionary = layer as Dictionary
		var ttype: String = str(layer_dict.get("type", "none"))
		# GPU particles for particle/sparkle/afterimage trails
		if ttype == "particle" or ttype == "sparkle" or ttype == "afterimage":
			var trail_color: Color = EffectLayerRenderer.get_layer_color(layer_dict, weapon_color)
			var emitter: GPUParticles2D = VFXFactory.create_trail_emitter(layer_dict, trail_color)
			add_child(emitter)
			_gpu_trail_emitters.append(emitter)


func _process(delta: float) -> void:
	_age += delta

	# --- Motion (summed from all motion layers) ---
	var x_offset: float = EffectLayerRenderer.compute_motion_offset(
		_resolved_layers.get("motion", []) as Array, _age
	)

	position.y += direction.y * speed * delta
	_base_x += direction.x * speed * delta
	position.x = _base_x + x_offset

	# --- Trail points (for ribbon trails) ---
	_trail_points.append(global_position)
	if _trail_points.size() > 20:
		_trail_points.pop_front()

	# --- Beat FX evaluation ---
	var beat_fx_layers: Array = _resolved_layers.get("beat_fx", []) as Array
	if not beat_fx_layers.is_empty():
		var fx_result: Dictionary = EffectLayerRenderer.evaluate_beat_fx(
			beat_fx_layers, weapon_color, _age, delta
		)
		# Collect sparkle particles from beat fx
		var sparkles: Array = fx_result.get("sparkle_particles", []) as Array
		for sparkle in sparkles:
			var s: Dictionary = sparkle as Dictionary
			s["pos"] = (s["pos"] as Vector2) + global_position
			_beat_fx_particles.append(s)

	# --- Age beat_fx particles ---
	_age_particles(_beat_fx_particles, delta)

	# --- Off-screen check ---
	if position.y < -50 or position.y > 1130 or position.x < -50 or position.x > 1970:
		_die()
		return

	queue_redraw()


func _draw() -> void:
	# --- Draw beat fx particles ---
	for p in _beat_fx_particles:
		EffectLayerRenderer.draw_particle(self, p, global_position)

	# --- Draw ribbon trails ---
	EffectLayerRenderer.draw_ribbon_trails(
		self, _resolved_layers.get("trail", []) as Array,
		_trail_points, weapon_color, global_position
	)

	# --- Draw shape stack (skip if shader sprite handles it) ---
	if not _has_shader_shape:
		var beat_fx_layers: Array = _resolved_layers.get("beat_fx", []) as Array
		var scale_mult: float = 1.0
		if not beat_fx_layers.is_empty():
			var fx_result: Dictionary = EffectLayerRenderer.evaluate_beat_fx(
				beat_fx_layers, weapon_color, _age, 0.0
			)
			scale_mult = float(fx_result.get("scale_mult", 1.0))

		if scale_mult != 1.0:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(scale_mult, scale_mult))

		EffectLayerRenderer.draw_shape_stack(
			self, Vector2.ZERO,
			_resolved_layers.get("shape", []) as Array,
			weapon_color, _age
		)

		if scale_mult != 1.0:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		# Apply beat fx scale to shader sprite
		var beat_fx_layers: Array = _resolved_layers.get("beat_fx", []) as Array
		if not beat_fx_layers.is_empty() and _shader_sprite:
			var fx_result: Dictionary = EffectLayerRenderer.evaluate_beat_fx(
				beat_fx_layers, weapon_color, _age, 0.0
			)
			var scale_mult: float = float(fx_result.get("scale_mult", 1.0))
			_shader_sprite.scale = Vector2(scale_mult, scale_mult)


func _age_particles(particles: Array, delta: float) -> void:
	var dead: Array = []
	for p in particles:
		p["age"] = float(p["age"]) + delta
		p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta
		if float(p["age"]) >= float(p["lifetime"]):
			dead.append(p)
	for p in dead:
		particles.erase(p)


# --- Death / Impact ---

func _die() -> void:
	# Stop GPU trail emitters before freeing so particles finish naturally
	for emitter in _gpu_trail_emitters:
		if is_instance_valid(emitter):
			emitter.emitting = false
			# Reparent to projectile container so it outlives this node
			var parent: Node = get_parent()
			if parent:
				remove_child(emitter)
				emitter.position = global_position
				parent.add_child(emitter)
				# Auto-free after particles expire
				var timer := Timer.new()
				timer.one_shot = true
				timer.wait_time = emitter.lifetime + 0.1
				timer.timeout.connect(emitter.queue_free)
				emitter.add_child(timer)
				timer.start()
	_gpu_trail_emitters.clear()

	_spawn_impact_effect()
	queue_free()


func _spawn_impact_effect() -> void:
	var impact_layers: Array = _resolved_layers.get("impact", []) as Array
	if impact_layers.is_empty():
		return
	var container: Node2D = get_parent()
	if not container:
		return

	# Spawn GPU particle impact emitters
	for layer in impact_layers:
		var layer_dict: Dictionary = layer as Dictionary
		var itype: String = str(layer_dict.get("type", "none"))
		if itype == "none":
			continue
		var impact_color: Color = EffectLayerRenderer.get_layer_color(layer_dict, weapon_color)
		var emitter: GPUParticles2D = VFXFactory.create_impact_emitter(layer_dict, impact_color)
		emitter.position = global_position
		container.add_child(emitter)


func _on_area_entered(area: Area2D) -> void:
	if area.has_method("take_damage"):
		area.take_damage(damage)
	_die()
