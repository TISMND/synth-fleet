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
var pierce_count: int = 0  # 0 = die on hit, N = pass through N enemies, -1 = infinite
var splash_enabled: bool = false
var splash_radius: float = 0.0
var skips_shields: bool = false
var is_enemy: bool = false  # if true, use enemy collision layers (layer 8, mask 1)

static var _debug_printed: bool = false
var _age: float = 0.0
var _base_x: float = 0.0
var _trail_points: Array = []
var _trail_particles: Array = []
var _ribbon_max_points: int = 20
var _pierced_enemies: Array = []  # enemies already hit (for pierce)
var _pierce_remaining: int = 0

# Resolved once at spawn — layer arrays per slot
var _resolved_layers: Dictionary = {}
var _has_shader_shape: bool = false
var _shader_sprite: Sprite2D = null
var _gpu_trail_emitters: Array = []
var _visual_rotation: float = 0.0  # rotate visuals to face travel direction


func _ready() -> void:
	if is_enemy:
		collision_layer = 8
		collision_mask = 1
	else:
		collision_layer = 2
		collision_mask = 4

	# Store visual rotation for sprite/draw (don't rotate node — that breaks trails)
	_visual_rotation = direction.angle() - PI / 2.0

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4, 12)
	shape.shape = rect
	add_child(shape)
	area_entered.connect(_on_area_entered)
	_base_x = position.x
	_pierce_remaining = pierce_count
	# Resolve layers once at spawn — fall back to style's effect_profile if weapon has none
	var profile: Dictionary = effect_profile
	var defaults: Dictionary = profile.get("defaults", {}) as Dictionary
	if defaults.is_empty() and projectile_style and not projectile_style.effect_profile.is_empty():
		profile = projectile_style.effect_profile
	_resolved_layers = EffectLayerRenderer.resolve_layers(profile, trigger_index)
	_ribbon_max_points = EffectLayerRenderer.get_ribbon_max_points(
		_resolved_layers.get("trail", []) as Array
	)

	if not _debug_printed:
		_debug_printed = true
		var vp: Viewport = get_viewport()
		var vp_size: String = str(vp.size) if vp else "null"
		print("[PROJECTILE] color=%s modulate=%s viewport=%s" % [str(weapon_color), str(modulate), vp_size])

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
		_shader_sprite.rotation = _visual_rotation
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
				_shader_sprite.rotation = _visual_rotation
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
	if _trail_points.size() > _ribbon_max_points:
		_trail_points.pop_front()

	# --- Off-screen check ---
	if position.y < -50 or position.y > 1130 or position.x < -50 or position.x > 1970:
		_die()
		return

	queue_redraw()


func _draw() -> void:
	# --- Draw ribbon trails ---
	EffectLayerRenderer.draw_ribbon_trails(
		self, _resolved_layers.get("trail", []) as Array,
		_trail_points, weapon_color, global_position, _age
	)

	# --- Draw shape stack (skip if shader sprite handles it) ---
	if not _has_shader_shape:
		draw_set_transform(Vector2.ZERO, _visual_rotation)
		EffectLayerRenderer.draw_shape_stack(
			self, Vector2.ZERO,
			_resolved_layers.get("shape", []) as Array,
			weapon_color, _age
		)
		draw_set_transform(Vector2.ZERO, 0.0)



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
	# Skip enemies already hit by this projectile (pierce)
	if _pierced_enemies.has(area):
		return

	if area.has_method("take_damage"):
		area.take_damage(damage, skips_shields)
	_pierced_enemies.append(area)

	# Splash damage — hit all enemies within radius (except the direct target)
	if splash_enabled and splash_radius > 0.0:
		var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
		for node in enemies:
			if node == area or not node is Node2D:
				continue
			if _pierced_enemies.has(node):
				continue
			var enemy: Node2D = node as Node2D
			if global_position.distance_to(enemy.global_position) <= splash_radius:
				if enemy.has_method("take_damage"):
					enemy.take_damage(damage, skips_shields)

	# Pierce: keep going or die
	if pierce_count == -1:
		# Infinite pierce — never die from hits
		return
	if _pierce_remaining > 0:
		_pierce_remaining -= 1
		return
	_die()
