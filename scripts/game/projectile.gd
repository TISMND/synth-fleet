class_name Projectile
extends Area2D
## Projectile fired by hardpoints. Uses EffectLayerRenderer for composable effect layers.

var direction: Vector2 = Vector2.UP
var speed: float = 600.0
var damage: int = 10
var weapon_color: Color = Color.CYAN
var effect_profile: Dictionary = {}
var trigger_index: int = -1

var _age: float = 0.0
var _base_x: float = 0.0
var _trail_points: Array = []
var _trail_particles: Array = []

# Resolved once at spawn — layer arrays per slot
var _resolved_layers: Dictionary = {}
var _beat_fx_particles: Array = []


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


func _process(delta: float) -> void:
	_age += delta

	# --- Motion (summed from all motion layers) ---
	var x_offset: float = EffectLayerRenderer.compute_motion_offset(
		_resolved_layers.get("motion", []) as Array, _age
	)

	position.y += direction.y * speed * delta
	_base_x += direction.x * speed * delta
	position.x = _base_x + x_offset

	# --- Trail particles (from all trail layers) ---
	EffectLayerRenderer.spawn_trail_particles(
		_resolved_layers.get("trail", []) as Array,
		global_position, weapon_color, _trail_particles
	)

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

	# --- Age trail particles ---
	_age_particles(_trail_particles, delta)
	_age_particles(_beat_fx_particles, delta)

	# --- Off-screen check ---
	if position.y < -50 or position.y > 1130 or position.x < -50 or position.x > 1970:
		_die()
		return

	queue_redraw()


func _draw() -> void:
	# --- Draw trail particles ---
	for p in _trail_particles:
		EffectLayerRenderer.draw_particle(self, p, global_position)

	# --- Draw beat fx particles ---
	for p in _beat_fx_particles:
		EffectLayerRenderer.draw_particle(self, p, global_position)

	# --- Draw ribbon trails ---
	EffectLayerRenderer.draw_ribbon_trails(
		self, _resolved_layers.get("trail", []) as Array,
		_trail_points, weapon_color, global_position
	)

	# --- Draw shape stack ---
	# Apply beat fx scale modifier
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
	_spawn_impact_effect()
	queue_free()


func _spawn_impact_effect() -> void:
	var impact_layers: Array = _resolved_layers.get("impact", []) as Array
	if impact_layers.is_empty():
		return
	var particles: Array = EffectLayerRenderer.spawn_impact_stack(impact_layers, weapon_color)
	if particles.is_empty():
		return
	var container: Node2D = get_parent()
	if container:
		var fx: EffectParticles = EffectParticles.new()
		fx.position = global_position
		fx.setup(particles, weapon_color)
		container.add_child(fx)


func _on_area_entered(area: Area2D) -> void:
	if area.has_method("take_damage"):
		area.take_damage(damage)
	_die()
