class_name Enemy
extends Area2D
## Enemy that drifts down the screen or follows a flight path curve.
## Takes damage from projectiles, awards credits on death.

var health: int = 30
var shield: int = 0
var drift_speed: float = 100.0
var enemy_color: Color = Color(1.0, 0.3, 0.5)
var visual_id: String = ""
var render_mode_str: String = "neon"
var grid_size: Vector2i = Vector2i(32, 32)
var ship_id: String = ""

# Path-following mode (set externally; null = drift mode)
var path_curve: Curve2D = null
var path_speed: float = 200.0
var path_progress: float = 0.0  # distance traveled along curve
var path_offset: Vector2 = Vector2.ZERO  # formation slot offset
var path_origin: Vector2 = Vector2.ZERO  # x_offset from level encounter
var rotate_with_path: bool = false
var _has_entered_screen: bool = false

# Melee chase mode
var is_melee: bool = false
var melee_speed: float = 200.0
var melee_turn_speed: float = 90.0  # degrees per second
var _melee_heading: float = PI / 2.0  # radians, starts pointing down
var _melee_target: Node2D = null

# Whether this enemy's weapons are active (set by encounter data)
var weapons_active: bool = true

# Currency drop config (set by encounter data via WaveManager)
# Per-segment speed (precomputed at spawn time)
var segment_speeds_array: Array[float] = []
var _segment_cumulative: Array[float] = []  # Cumulative lengths for segment lookup

var drop_chance: float = 0.0
var drop_table: Array = []
var drop_seed: int = 0
var pickups_container: Node2D = null

# Boss strafe mode — hovers near top, oscillates left/right
var is_boss_strafe: bool = false
var boss_strafe_y: float = 200.0      # Y position to hover at
var boss_strafe_speed: float = 80.0   # horizontal oscillation speed (pixels/sec amplitude)
var boss_strafe_width: float = 300.0  # how far left/right from center
var _boss_strafe_time: float = 0.0

# Boss V-sweep mode — sweeps between bottom corners and top center
var is_boss_v_sweep: bool = false
var boss_v_sweep_speed: float = 250.0
const _V_SWEEP_POINTS: Array[Vector2] = [
	Vector2(200.0, 800.0),   # bottom-left
	Vector2(960.0, 150.0),   # top-center
	Vector2(1720.0, 800.0),  # bottom-right
	Vector2(960.0, 150.0),   # top-center
]
var _v_sweep_index: int = 0
var _v_sweep_progress: float = 0.0

# Boss segment linking
var boss_core: Enemy = null           # if set, this segment follows the core
var boss_segment_offset: Vector2 = Vector2.ZERO  # offset from core position
var boss_segments: Array = []         # core tracks its segments (Array[Enemy])
var is_boss_immune: bool = false      # if true, takes no damage (plays immune VFX/SFX instead)

# Boss enrage state
var _boss_enraged: bool = false
var _boss_data_ref: Variant = null    # BossData, set at spawn for enrage config

var _renderer: ShipRenderer = null
var _baked_sprite: Sprite2D = null
var _flash_material: ShaderMaterial = null
var _weapon_controller: EnemyWeaponController = null

# Set externally before adding to scene tree for weapon setup
var ship_data_ref: ShipData = null
var player_ref: Node2D = null
var projectiles_container: Node2D = null
var shared_renderer: EnemySharedRenderer = null

# Boss weapon overrides — Array of {hardpoint_index: int, weapon_id: String}
# When non-empty, these override the ship's weapon_id for specific hardpoints
var weapon_overrides: Array = []


func _ready() -> void:
	add_to_group("enemies")

	collision_layer = 4
	collision_mask = 0
	var col_shape := CollisionShape2D.new()
	if ship_data_ref:
		var col_result: Dictionary = _make_collision_shape(ship_data_ref)
		col_shape.shape = col_result["shape"]
		col_shape.rotation = float(col_result["rotation"])
		if "collision_offset_x" in ship_data_ref:
			col_shape.position = Vector2(ship_data_ref.collision_offset_x, ship_data_ref.collision_offset_y)
	else:
		var circle := CircleShape2D.new()
		circle.radius = maxf(float(maxi(grid_size.x, grid_size.y)) * 0.4, 12.0)
		col_shape.shape = circle
	add_child(col_shape)

	# Try shared bake viewport first — falls back to per-instance ShipRenderer
	var vid: String = visual_id if visual_id != "" else "sentinel"
	var bake_tex: ViewportTexture = null
	if shared_renderer:
		bake_tex = shared_renderer.get_texture(vid, render_mode_str, enemy_color)

	if bake_tex:
		_baked_sprite = Sprite2D.new()
		_baked_sprite.texture = bake_tex
		_flash_material = shared_renderer.create_flash_material()
		_baked_sprite.material = _flash_material
		# Hide until viewport texture has rendered (2-frame delay)
		_baked_sprite.visible = false
		add_child(_baked_sprite)
		get_tree().process_frame.connect(_reveal_sprite_frame_1, CONNECT_ONE_SHOT)
		shared_renderer.ref(vid, render_mode_str, enemy_color)
	else:
		# Fallback: per-instance ShipRenderer (for unregistered appearances or no bake manager)
		_renderer = ShipRenderer.new()
		_renderer.ship_id = -1
		_renderer.enemy_visual_id = vid
		_renderer.render_mode = ShipRenderer.RenderMode.CHROME if render_mode_str == "chrome" else ShipRenderer.RenderMode.NEON
		_renderer.hull_color = enemy_color
		_renderer.accent_color = Color(1.0, 0.2, 0.6)
		add_child(_renderer)

	# Universal enemy hit effects from VFX config
	var vfx: VfxConfig = VfxConfigManager.load_config()
	var extent: float = ship_data_ref.bounding_extent() if ship_data_ref else 40.0
	_setup_hit_field("ShieldField", vfx.enemy_shield_field_style_id, vfx.enemy_shield_ratio * extent, vfx.enemy_shield_pulse_duration)

	# Setup weapon controller if ship has a weapon assigned
	var has_weapon: bool = ship_data_ref and ship_data_ref.weapon_id != ""
	var has_overrides: bool = weapon_overrides.size() > 0
	if (has_weapon or has_overrides) and ship_data_ref and projectiles_container:
		_weapon_controller = EnemyWeaponController.new()
		_weapon_controller.projectile_color = enemy_color
		_weapon_controller.weapons_enabled = weapons_active
		add_child(_weapon_controller)
		if has_overrides:
			_weapon_controller.setup_with_overrides(ship_data_ref, weapon_overrides, self, player_ref, projectiles_container)
		else:
			_weapon_controller.setup(ship_data_ref, self, player_ref, projectiles_container)

	# Always clean up weapon controller when leaving tree (death, off-screen, etc.)
	tree_exiting.connect(_on_cleanup)


static func _make_collision_shape(ship: ShipData) -> Dictionary:
	## Returns {"shape": Shape2D, "rotation": float} — rotation needed for horizontal capsules.
	var w: float = ship.collision_width
	var h: float = ship.collision_height
	match ship.collision_shape:
		"rectangle":
			var rect := RectangleShape2D.new()
			rect.size = Vector2(w, h)
			return {"shape": rect, "rotation": 0.0}
		"capsule":
			var cap := CapsuleShape2D.new()
			if w > h:
				cap.radius = h * 0.5
				cap.height = maxf(w, h)
				return {"shape": cap, "rotation": PI * 0.5}
			else:
				cap.radius = w * 0.5
				cap.height = maxf(h, w)
				return {"shape": cap, "rotation": 0.0}
		_:  # "circle"
			var circle := CircleShape2D.new()
			circle.radius = w * 0.5
			return {"shape": circle, "rotation": 0.0}


func force_cleanup_weapons() -> void:
	if _weapon_controller:
		_weapon_controller.cleanup()
		_weapon_controller = null


func _on_cleanup() -> void:
	if _weapon_controller:
		_weapon_controller.cleanup()
		_weapon_controller = null
	if _baked_sprite and shared_renderer:
		var vid: String = visual_id if visual_id != "" else "sentinel"
		shared_renderer.unref(vid, render_mode_str, enemy_color)


func _reveal_sprite_frame_1() -> void:
	if not is_instance_valid(self):
		return
	if not is_inside_tree():
		return
	get_tree().process_frame.connect(_reveal_sprite_frame_2, CONNECT_ONE_SHOT)


func _reveal_sprite_frame_2() -> void:
	if _baked_sprite and is_instance_valid(_baked_sprite):
		_baked_sprite.visible = true


func set_melee_target(target: Node2D) -> void:
	_melee_target = target


func _process(delta: float) -> void:
	# Store position before movement for lead prediction
	set_meta("_prev_pos", global_position)
	set_meta("_prev_dt", delta)

	# Boss segment — follow core position + offset
	if boss_core and is_instance_valid(boss_core):
		position = boss_core.position + boss_segment_offset
		rotation = boss_core.rotation
		return
	elif boss_core and not is_instance_valid(boss_core):
		# Core was destroyed — segment dies too
		queue_free()
		return

	# Boss V-sweep — sweep between bottom corners and top center
	if is_boss_v_sweep:
		var target: Vector2 = _V_SWEEP_POINTS[_v_sweep_index]
		var dist: float = position.distance_to(target)
		if dist < 5.0:
			_v_sweep_index = (_v_sweep_index + 1) % _V_SWEEP_POINTS.size()
		else:
			position = position.move_toward(target, boss_v_sweep_speed * delta)
		return

	# Boss strafe — hover at top, oscillate left/right
	if is_boss_strafe:
		_boss_strafe_time += delta
		var center_x: float = 960.0
		position.x = center_x + sin(_boss_strafe_time * boss_strafe_speed / boss_strafe_width) * boss_strafe_width
		position.y = move_toward(position.y, boss_strafe_y, 60.0 * delta)
		return

	if is_melee:
		# Melee chase mode — turn-rate-limited steering toward player
		if is_instance_valid(_melee_target):
			var desired_angle: float = (_melee_target.global_position - global_position).angle()
			var max_turn: float = deg_to_rad(melee_turn_speed) * delta
			_melee_heading = rotate_toward(_melee_heading, desired_angle, max_turn)
		position += Vector2(cos(_melee_heading), sin(_melee_heading)) * melee_speed * delta
		rotation = _melee_heading - PI / 2.0
		# Wider despawn bounds so chasers can loop back
		if position.y > 2420 or position.y < -500 or position.x < -500 or position.x > 2420:
			queue_free()
	elif path_curve != null and path_curve.point_count >= 2:
		# Path-following mode — encounter speed * per-segment multiplier
		var move_speed: float = path_speed
		if segment_speeds_array.size() > 0 and _segment_cumulative.size() > 0:
			move_speed = path_speed * _get_current_segment_multiplier()
		path_progress += move_speed * delta
		var total_len: float = path_curve.get_baked_length()
		if path_progress >= total_len:
			queue_free()
			return
		var curve_pos: Vector2 = path_curve.sample_baked(path_progress)
		position = curve_pos + path_offset + path_origin
		if rotate_with_path:
			var behind: float = maxf(path_progress - 10.0, 0.0)
			var ahead: float = minf(path_progress + 10.0, total_len)
			var dir: Vector2 = path_curve.sample_baked(ahead) - path_curve.sample_baked(behind)
			if dir.length_squared() > 0.01:
				rotation = dir.angle() - PI / 2.0
		# Despawn if off screen (skip until enemy has entered the play area once)
		if _has_entered_screen:
			if position.y > 1200 or position.y < -200 or position.x < -200 or position.x > 2120:
				queue_free()
		elif position.y >= 0.0 and position.y <= 1080.0 and position.x >= 0.0 and position.x <= 1920.0:
			_has_entered_screen = true
	else:
		# Drift mode (legacy)
		position.y += drift_speed * delta
		if position.y > 1130:
			queue_free()


func _spawn_explosion() -> void:
	var explosion: ExplosionEffect = ExplosionEffect.new()
	if ship_data_ref:
		explosion.explosion_color = ship_data_ref.explosion_color
		explosion.explosion_size = ship_data_ref.explosion_size
		explosion.enable_screen_shake = ship_data_ref.enable_screen_shake
	else:
		explosion.explosion_color = enemy_color
		explosion.explosion_size = maxf(float(maxi(grid_size.x, grid_size.y)) / 32.0, 0.8)
	explosion.global_position = global_position
	# Add to parent (enemies container) so it persists after enemy queue_free
	var container: Node = get_parent()
	if container:
		container.add_child(explosion)


func take_damage(amount: int, skips_shields: bool = false, hit_position: Vector2 = Vector2.ZERO) -> void:
	# Immune boss core — deflect damage, play immune feedback
	if is_boss_immune:
		_play_immune_hit(hit_position)
		return

	var remaining: int = amount
	if shield > 0 and not skips_shields:
		var absorbed: int = mini(remaining, shield)
		shield -= absorbed
		remaining -= absorbed
		SfxPlayer.play("enemy_shield_hit")
		var shield_field: FieldRenderer = get_node_or_null("ShieldField") as FieldRenderer
		if shield_field:
			shield_field.pulse()
	if remaining > 0:
		health -= remaining
		SfxPlayer.play("enemy_hull_hit")
		_flash_hull_hit()
	if health <= 0:
		_die()


func _die() -> void:
	if _weapon_controller:
		_weapon_controller.cleanup()
		_weapon_controller = null
	GameState.level_stats["enemies_destroyed"] = int(GameState.level_stats.get("enemies_destroyed", 0)) + 1
	GameState.level_stats["score"] = int(GameState.level_stats.get("score", 0)) + 10

	# Boss core: multi-explosion death sequence before final blast
	if boss_segments.size() > 0 or _is_boss_core:
		_start_boss_death_sequence()
		return

	SfxPlayer.play_random_explosion()
	_spawn_explosion()
	_try_spawn_pickup()
	# If this is a segment, unregister from core
	if boss_core and is_instance_valid(boss_core):
		boss_core.boss_segments.erase(self)
		boss_core._update_immunity()
	queue_free()


func _try_spawn_pickup() -> void:
	if drop_table.size() == 0 or drop_chance <= 0.0:
		return
	if not is_instance_valid(pickups_container):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = drop_seed
	if rng.randf() > drop_chance:
		return
	# Weighted selection from drop table
	var total_weight: int = 0
	for entry in drop_table:
		total_weight += int(entry.get("weight", 1))
	if total_weight <= 0:
		return
	var roll: int = rng.randi_range(0, total_weight - 1)
	var cumulative: int = 0
	var selected_id: String = ""
	for entry in drop_table:
		cumulative += int(entry.get("weight", 1))
		if roll < cumulative:
			selected_id = str(entry.get("item_id", ""))
			break
	if selected_id == "":
		return
	var item: ItemData = ItemDataManager.load_by_id(selected_id)
	if not item:
		return
	var pickup := Pickup.new()
	pickup.item_data = item
	pickup.global_position = global_position
	pickups_container.add_child(pickup)


func _get_current_segment_multiplier() -> float:
	for i in range(_segment_cumulative.size()):
		if path_progress <= _segment_cumulative[i]:
			return segment_speeds_array[i] if i < segment_speeds_array.size() else 1.0
	# Past the last segment boundary
	if segment_speeds_array.size() > 0:
		return segment_speeds_array[segment_speeds_array.size() - 1]
	return 1.0


func precompute_segment_lengths() -> void:
	## Call after path_curve is set. Builds cumulative length array for per-segment speed lookup.
	_segment_cumulative.clear()
	if not path_curve or path_curve.point_count < 2:
		return
	var cumulative: float = 0.0
	for i in range(path_curve.point_count - 1):
		# Approximate segment length by sampling the baked curve
		var p0_dist: float = 0.0
		if i > 0:
			p0_dist = _segment_cumulative[i - 1]
		# Sample points along this segment
		var p0: Vector2 = path_curve.get_point_position(i)
		var p0_out: Vector2 = p0 + path_curve.get_point_out(i)
		var p1: Vector2 = path_curve.get_point_position(i + 1)
		var p1_in: Vector2 = p1 + path_curve.get_point_in(i + 1)
		var seg_len: float = 0.0
		var prev_pt: Vector2 = p0
		for j in range(1, 21):
			var t: float = float(j) / 20.0
			var pt: Vector2 = p0.bezier_interpolate(p0_out, p1_in, p1, t)
			seg_len += prev_pt.distance_to(pt)
			prev_pt = pt
		cumulative += seg_len
		_segment_cumulative.append(cumulative)


var _is_boss_core: bool = false  # Set true when this enemy is a boss core


func _start_boss_death_sequence() -> void:
	# Disable collision so player can't keep hitting a dying boss
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	var container: Node = get_parent()
	if not container:
		_finish_boss_death()
		return

	# Spawn 6-10 small explosions at random offsets over ~1.5 seconds
	var explosion_count: int = randi_range(6, 10)
	var base_size: float = 0.4
	if ship_data_ref:
		base_size = ship_data_ref.explosion_size * 0.35
	var spread: float = maxf(float(maxi(grid_size.x, grid_size.y)) * 0.4, 30.0)

	for i in explosion_count:
		var delay: float = float(i) * (1.5 / float(explosion_count))
		var timer := get_tree().create_timer(delay)
		timer.timeout.connect(_spawn_mini_explosion.bind(container, spread, base_size))

	# Final big explosion + cleanup after the sequence
	var final_timer := get_tree().create_timer(1.8)
	final_timer.timeout.connect(_finish_boss_death)


func _spawn_mini_explosion(container: Node, spread: float, base_size: float) -> void:
	if not is_instance_valid(self):
		return
	var offset := Vector2(randf_range(-spread, spread), randf_range(-spread, spread))
	var explosion: ExplosionEffect = ExplosionEffect.new()
	if ship_data_ref:
		explosion.explosion_color = ship_data_ref.explosion_color
	else:
		explosion.explosion_color = enemy_color
	explosion.explosion_size = base_size * randf_range(0.6, 1.2)
	explosion.enable_screen_shake = true
	explosion.global_position = global_position + offset
	container.add_child(explosion)
	SfxPlayer.play_random_explosion()


func _finish_boss_death() -> void:
	if not is_instance_valid(self):
		return
	SfxPlayer.play_random_explosion()
	_spawn_explosion()
	# Kill all remaining segments
	for seg in boss_segments:
		if is_instance_valid(seg):
			var segment: Enemy = seg as Enemy
			segment.boss_core = null
			segment._die()
	boss_segments.clear()
	queue_free()


func _update_immunity() -> void:
	## Recalculate immunity: immune if any segment is still alive.
	## When all segments die, drop immunity and trigger enrage if configured.
	if not is_boss_immune:
		return  # Was never immune, skip
	var any_alive := false
	for seg in boss_segments:
		if is_instance_valid(seg):
			any_alive = true
			break
	is_boss_immune = any_alive
	if not any_alive and not _boss_enraged:
		_trigger_enrage()


func _trigger_enrage() -> void:
	_boss_enraged = true
	if not _boss_data_ref:
		return
	var boss: BossData = _boss_data_ref as BossData

	# Switch movement pattern
	var enrage_movement: String = boss.enrage_movement
	if enrage_movement == "v_sweep":
		is_boss_strafe = false
		is_boss_v_sweep = true
		boss_v_sweep_speed = boss_strafe_speed * boss.enrage_speed_mult

	# Swap to enrage weapons — single source of truth from the enrage tab
	if boss.enrage_core_weapon_overrides.size() > 0 and ship_data_ref and projectiles_container:
		if _weapon_controller:
			_weapon_controller.cleanup()
			_weapon_controller = null
		_weapon_controller = EnemyWeaponController.new()
		_weapon_controller.setup_with_overrides(ship_data_ref, boss.enrage_core_weapon_overrides, self, player_ref, projectiles_container)

	# Apply enrage render mode to core
	if boss.enrage_core_render_mode != "":
		_apply_enrage_render_mode(boss.enrage_core_render_mode)


func _apply_enrage_render_mode(new_mode: String) -> void:
	var vid: String = visual_id if visual_id != "" else "sentinel"
	var old_mode: String = render_mode_str
	# Unref old shared texture
	if _baked_sprite and shared_renderer:
		shared_renderer.unref(vid, old_mode, enemy_color)
	render_mode_str = new_mode
	# Try to get new shared texture
	if shared_renderer:
		var new_tex: ViewportTexture = shared_renderer.get_texture(vid, new_mode, enemy_color)
		if new_tex and _baked_sprite:
			_baked_sprite.texture = new_tex
			shared_renderer.ref(vid, new_mode, enemy_color)
			return
	# Fallback: update per-instance renderer
	if _renderer:
		_renderer.render_mode = ShipRenderer.RenderMode.CHROME if new_mode == "chrome" else ShipRenderer.RenderMode.NEON
		_renderer.queue_redraw()


func _setup_hit_field(node_name: String, style_id: String, radius: float, pulse_duration_override: float = 0.0) -> void:
	if style_id == "":
		return
	var style: FieldStyle = FieldStyleManager.load_by_id(style_id)
	if not style:
		return
	if pulse_duration_override > 0.0:
		style.pulse_total_duration = pulse_duration_override
	var field := FieldRenderer.new()
	field.name = node_name
	field._stay_visible = false
	field.visible = false
	add_child(field)
	field.setup(style, radius)


func _flash_hull_hit() -> void:
	var vfx: VfxConfig = VfxConfigManager.load_config()
	var intensity: float = vfx.enemy_hull_flash_intensity
	var duration: float = vfx.enemy_hull_flash_duration
	var count: int = vfx.enemy_hull_flash_count
	var step_time: float = duration / (count * 2.0)

	if _flash_material:
		# Baked sprite path — animate flash_mix shader uniform (0.0 = off, 1.0 = white)
		var flash_strength: float = clampf(intensity / 3.0, 0.0, 1.0)
		var tween := create_tween()
		for i in count:
			tween.tween_method(func(v: float) -> void:
				if _flash_material:
					_flash_material.set_shader_parameter("flash_mix", v)
			, flash_strength, 0.0, step_time)
		tween.tween_callback(func() -> void:
			if _flash_material:
				_flash_material.set_shader_parameter("flash_mix", 0.0)
		)
	elif _renderer:
		# Per-instance ShipRenderer fallback — animate modulate
		var color_arr: Array = vfx.enemy_hull_flash_color
		var flash_color := Color(float(color_arr[0]), float(color_arr[1]), float(color_arr[2]), 1.0)
		var tween := create_tween()
		for i in count:
			var bright := flash_color * intensity
			bright.a = 1.0
			tween.tween_property(_renderer, "modulate", bright, step_time * 0.1)
			tween.tween_property(_renderer, "modulate", Color.WHITE, step_time * 0.9)
		tween.tween_property(_renderer, "modulate", Color.WHITE, 0.0)


func _play_immune_hit(hit_pos: Vector2 = Vector2.ZERO) -> void:
	SfxPlayer.play("immune_hit")
	var vfx: VfxConfig = VfxConfigManager.load_config()
	var local_hit: Vector2 = to_local(hit_pos) if hit_pos != Vector2.ZERO else Vector2.ZERO

	# Main immune field effect (around ship)
	if vfx.immune_field_style_id != "":
		var style: FieldStyle = FieldStyleManager.load_by_id(vfx.immune_field_style_id)
		if style:
			var field := FieldRenderer.new()
			field._stay_visible = false
			add_child(field)
			var immune_px: float = vfx.immune_ratio * (ship_data_ref.bounding_extent() if ship_data_ref else 40.0)
			field.setup(style, immune_px)
			field.pulse()
			var cleanup_time: float = style.pulse_total_duration + 0.1
			get_tree().create_timer(cleanup_time).timeout.connect(func() -> void:
				if is_instance_valid(field):
					field.queue_free()
			)

	# Impact burst at point of contact
	if vfx.immune_impact_type != "":
		var color_arr: Array = vfx.immune_impact_color
		var impact_color := Color(float(color_arr[0]), float(color_arr[1]), float(color_arr[2]), float(color_arr[3]))
		if vfx.immune_impact_type == "deflect":
			var deflect := VFXFactory.create_deflect_impact(impact_color, vfx.immune_impact_radius * 2.0, vfx.immune_impact_lifetime * 2.0)
			if deflect:
				deflect.position = local_hit
				add_child(deflect)
		else:
			var layer: Dictionary = {
				"type": vfx.immune_impact_type,
				"params": {
					"particle_count": vfx.immune_impact_particle_count,
					"lifetime": vfx.immune_impact_lifetime,
					"radius": vfx.immune_impact_radius,
					"speed_scale": vfx.immune_impact_speed_scale,
				}
			}
			var emitter: GPUParticles2D = VFXFactory.create_impact_emitter(layer, impact_color)
			if emitter:
				emitter.position = local_hit
				add_child(emitter)
