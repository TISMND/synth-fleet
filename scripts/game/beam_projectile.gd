class_name BeamProjectile
extends Node2D
## Sustained beam visual + hitbox attached to hardpoint position.
## Three-phase lifecycle: appear → sustain → disappear.
## Appearance modes: flow_in (grows from ship) or expand_out (expands width).

var weapon_color: Color = Color.CYAN
var damage_per_tick: float = 5.0
var beam_duration: float = 0.3
var beam_transition_time: float = 0.1
var max_length: float = 400.0
var beam_width: float = 16.0
var beam_style: BeamStyle = null
var skips_shields: bool = false
var passthrough: bool = true
var appearance_mode: String = "flow_in"
var preview_mode: bool = false
var is_enemy: bool = false  # if true, use enemy collision layers (layer 8, mask 1)
var flip_shader: bool = false
var track_node: Node2D = null  # if set, beam follows this node's global_position each frame
var _direction_source: Callable  # if set, called each frame to get aim direction (returns float degrees)
var _has_direction_source: bool = false

static var _debug_printed: bool = false
var _age: float = 0.0
var _damage_accumulator: float = 0.0
var _sprite: Sprite2D = null
var _collision_area: Area2D = null
var _collision_shape: CollisionShape2D = null
var _rect_shape: RectangleShape2D = null
var _overlapping_enemies: Array[Area2D] = []
var _blocked_length: float = -1.0  # if >= 0, beam is shortened to this (no-passthrough)
var _impact_cooldown: float = 0.0  # throttle impact effects for no-passthrough


func set_direction_source(source: Callable) -> void:
	_direction_source = source
	_has_direction_source = true


func _ready() -> void:
	_setup_visual()
	if not preview_mode:
		_setup_collision()


func _setup_visual() -> void:
	_sprite = Sprite2D.new()

	var tex_w: int = maxi(int(beam_width), 4)
	var tex_h: int = maxi(int(max_length), 4)
	var img := Image.create(tex_w, tex_h, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_sprite.texture = ImageTexture.create_from_image(img)

	# Apply fill shader
	var mat := ShaderMaterial.new()
	var shader_name: String = "beam"
	if beam_style:
		shader_name = beam_style.fill_shader
	mat.shader = VFXFactory.get_fill_shader(shader_name)

	var color: Color = weapon_color
	if beam_style:
		color = beam_style.color
	mat.set_shader_parameter("weapon_color", color)

	if beam_style:
		for param in beam_style.shader_params:
			mat.set_shader_parameter(str(param), float(beam_style.shader_params[param]))

	_sprite.material = mat
	if not _debug_printed:
		_debug_printed = true
		var vp: Viewport = get_viewport()
		var vp_size: String = str(vp.size) if vp else "null"
		print("[BEAM] shader=%s color=%s viewport=%s" % [shader_name, str(color), vp_size])

	# Flip shader direction if requested (reverses UV.y scroll)
	var should_flip: bool = flip_shader
	if beam_style:
		should_flip = beam_style.flip_shader
	_sprite.flip_v = should_flip

	add_child(_sprite)

	# Set initial geometry based on appearance mode
	if appearance_mode == "flow_in":
		_update_beam_geometry(0.001, 1.0)
	elif appearance_mode == "expand_out":
		_update_beam_geometry(1.0, 0.001)
	else:
		_update_beam_geometry(1.0, 1.0)


func _setup_collision() -> void:
	_collision_area = Area2D.new()
	if is_enemy:
		_collision_area.collision_layer = 8
		_collision_area.collision_mask = 1
	else:
		_collision_area.collision_layer = 2
		_collision_area.collision_mask = 4
	_collision_shape = CollisionShape2D.new()
	_rect_shape = RectangleShape2D.new()
	_rect_shape.size = Vector2(beam_width, max_length)
	_collision_shape.shape = _rect_shape
	_collision_shape.position = Vector2(0, -max_length / 2.0)
	_collision_area.add_child(_collision_shape)
	add_child(_collision_area)
	_collision_area.area_entered.connect(_on_area_entered)
	_collision_area.area_exited.connect(_on_area_exited)


func _process(delta: float) -> void:
	_age += delta

	# Track parent hardpoint position and direction
	if track_node and is_instance_valid(track_node):
		global_position = track_node.global_position
	if _has_direction_source:
		var dir_deg: float = _direction_source.call()
		rotation = deg_to_rad(dir_deg)

	# Auto-destroy after duration
	if _age >= beam_duration:
		queue_free()
		return

	# No-passthrough: find nearest enemy and shorten beam
	if not passthrough and not preview_mode:
		_update_blocked_length()

	# Determine phase and progress
	var appear_end: float = beam_transition_time
	var disappear_start: float = beam_duration - beam_transition_time
	if disappear_start < appear_end:
		disappear_start = appear_end

	var length_ratio: float = 1.0
	var width_ratio: float = 1.0

	if _age < appear_end:
		var t: float = _age / maxf(appear_end, 0.001)
		if appearance_mode == "flow_in":
			length_ratio = t
			width_ratio = 1.0
		else:
			length_ratio = 1.0
			width_ratio = t
	elif _age >= disappear_start:
		var t: float = (_age - disappear_start) / maxf(beam_duration - disappear_start, 0.001)
		t = clampf(t, 0.0, 1.0)
		if appearance_mode == "flow_in":
			length_ratio = 1.0 - t
			width_ratio = 1.0
		else:
			length_ratio = 1.0
			width_ratio = 1.0 - t

	_update_beam_geometry(length_ratio, width_ratio)

	# Damage tick — apply DPS to all tracked overlapping enemies
	if not preview_mode and not _overlapping_enemies.is_empty():
		_damage_accumulator += damage_per_tick * delta
		if _damage_accumulator >= 1.0:
			var tick_damage: int = int(_damage_accumulator)
			_damage_accumulator -= float(tick_damage)
			_apply_damage_to_tracked(tick_damage)


func _update_blocked_length() -> void:
	# Find nearest enemy along beam's local -Y axis (the beam direction)
	_blocked_length = -1.0
	if _overlapping_enemies.is_empty():
		return
	var best_dist: float = INF
	var best_area: Area2D = null
	for area in _overlapping_enemies:
		if not is_instance_valid(area):
			continue
		# Distance along beam axis: project enemy position into beam's local space
		var local_pos: Vector2 = to_local(area.global_position)
		var dist_along_beam: float = -local_pos.y  # beam extends in -Y
		if dist_along_beam > 0.0 and dist_along_beam < best_dist:
			best_dist = dist_along_beam
			best_area = area
	if best_area:
		# Shorten beam to stop at the nearest enemy (plus a small overshoot for visual)
		_blocked_length = best_dist + 10.0
		# Only damage the nearest enemy
		_overlapping_enemies = [best_area]
		# Spawn continuous impact effect at the blocked point (throttled)
		_impact_cooldown -= get_process_delta_time()
		if _impact_cooldown <= 0.0:
			_impact_cooldown = 0.3
			_spawn_impact_at(best_area.global_position)


func _update_beam_geometry(length_ratio: float, width_ratio: float) -> void:
	# Use blocked length if no-passthrough and an enemy is hit
	var effective_max: float = max_length
	if _blocked_length >= 0.0 and _blocked_length < max_length:
		effective_max = _blocked_length
	var current_length: float = effective_max * maxf(length_ratio, 0.001)
	var current_width: float = beam_width * maxf(width_ratio, 0.001)
	if _sprite:
		_sprite.scale = Vector2(maxf(width_ratio, 0.001), maxf(current_length / maxf(max_length, 1.0), 0.001))
		_sprite.position = Vector2(0, -current_length / 2.0)
	if _rect_shape:
		_rect_shape.size = Vector2(current_width, current_length)
		_collision_shape.position = Vector2(0, -current_length / 2.0)


func _apply_damage_to_tracked(dmg: int) -> void:
	var i: int = _overlapping_enemies.size() - 1
	while i >= 0:
		var area: Area2D = _overlapping_enemies[i]
		if not is_instance_valid(area):
			_overlapping_enemies.remove_at(i)
		elif area.has_method("take_damage"):
			area.take_damage(dmg, skips_shields)
		i -= 1


func _on_area_entered(area: Area2D) -> void:
	if preview_mode:
		return
	if area.has_method("take_damage"):
		if area not in _overlapping_enemies:
			_overlapping_enemies.append(area)
		# Immediate first-hit damage
		var initial_dmg: int = int(maxf(damage_per_tick * 0.1, 1.0))
		area.take_damage(initial_dmg, skips_shields)
		# Spawn impact effect at enemy position
		_spawn_impact_at(area.global_position)


func _spawn_impact_at(pos: Vector2) -> void:
	if not beam_style or beam_style.effect_profile.is_empty():
		return
	var profile: Dictionary = beam_style.effect_profile
	var resolved: Dictionary = EffectLayerRenderer.resolve_layers(profile, -1)
	var impact_layers: Array = resolved.get("impact", []) as Array
	if impact_layers.is_empty():
		return
	var color: Color = beam_style.color if beam_style else weapon_color
	for layer in impact_layers:
		var layer_dict: Dictionary = layer as Dictionary
		var itype: String = str(layer_dict.get("type", "none"))
		if itype == "none":
			continue
		var layer_color: Color = EffectLayerRenderer.get_layer_color(layer_dict, color)
		var emitter: GPUParticles2D = VFXFactory.create_impact_emitter(layer_dict, layer_color)
		emitter.global_position = pos
		get_parent().add_child(emitter)


func _on_area_exited(area: Area2D) -> void:
	var idx: int = _overlapping_enemies.find(area)
	if idx >= 0:
		_overlapping_enemies.remove_at(idx)
