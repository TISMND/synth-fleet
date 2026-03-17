extends Node2D
## Player ship — chrome Stiletto rendering with banking, movement, health, and hardpoint controllers.

signal died

var ship_data: ShipData = null
var hull: int = 100
var hull_max: int = 100
var shield: float = 50.0
var shield_max: int = 50
var shield_regen: float = 5.0
var thermal: float = 0.0
var thermal_max: float = 100.0
var electric: float = 100.0
var electric_max: float = 100.0
var _hull_accumulator: float = 0.0
var speed: float = 400.0
var _hardpoint_controllers: Array = []
var _player_area: Area2D = null
var _hud: CanvasLayer = null
var _weapon_data_per_hp: Array = []
var _space_state: int = 0  # 0=all off, 1=all on

# Chrome Stiletto drawing
var _bank: float = 0.0
var _time: float = 0.0
var _prev_x: float = 0.0

# Chrome palette
const CHROME_DARK := Color(0.12, 0.13, 0.18)
const CHROME_MID := Color(0.35, 0.38, 0.45)
const CHROME_LIGHT := Color(0.65, 0.70, 0.80)
const CHROME_BRIGHT := Color(0.85, 0.88, 0.95)
const CHROME_SPEC := Color(1.0, 1.0, 1.0, 0.9)

var hull_color := Color(0.0, 0.9, 1.0)
var accent_color := Color(1.0, 0.2, 0.6)
var engine_color := Color(1.0, 0.5, 0.1)
var canopy_color := Color(0.4, 0.2, 1.0)
var detail_color := Color(0.0, 1.0, 0.7)


func setup(ship: ShipData, loadout: LoadoutData, proj_container: Node2D) -> void:
	ship_data = ship
	var stats: Dictionary = ship_data.stats
	hull_max = int(stats.get("hull_max", 100))
	hull = hull_max
	shield_max = int(stats.get("shield_max", 50))
	shield = float(shield_max)
	speed = float(stats.get("speed", 400))
	shield_regen = float(stats.get("shield_regen", 5.0))

	# Apply device modifiers
	for slot_key in GameState.device_config:
		var device_id: String = str(GameState.device_config[slot_key])
		if device_id == "":
			continue
		var dev: DeviceData = DeviceDataManager.load_by_id(device_id)
		if dev:
			var mods: Dictionary = dev.stats_modifiers
			shield_max += int(mods.get("shield_max", 0))
			hull_max += int(mods.get("hull_max", 0))
			speed += float(mods.get("speed", 0))
	shield = float(shield_max)
	hull = hull_max

	# Create hardpoint controllers from loadout assignments — all fire from center
	var assignments: Dictionary = loadout.hardpoint_assignments
	var hp_index: int = 0
	for hp in ship_data.hardpoints:
		var hp_id: String = str(hp.get("id", ""))
		var hp_label: String = str(hp.get("label", hp_id))

		var assignment: Dictionary = assignments.get(hp_id, {})
		var weapon_id: String = str(assignment.get("weapon_id", ""))
		if weapon_id == "":
			hp_index += 1
			continue
		var weapon: WeaponData = WeaponDataManager.load_by_id(weapon_id)
		if not weapon:
			hp_index += 1
			continue
		var controller := Node2D.new()
		controller.set_script(load("res://scripts/game/hardpoint_controller.gd"))
		controller.position = Vector2.ZERO
		add_child(controller)
		controller.setup(weapon, weapon.direction_deg, proj_container, hp_index)
		controller.bar_effect_fired.connect(apply_bar_effects)
		# Hardpoints start deactivated
		_hardpoint_controllers.append(controller)
		_weapon_data_per_hp.append({
			"label": hp_label,
			"weapon": weapon,
		})
		hp_index += 1

	# Player collision area for contact damage
	_player_area = Area2D.new()
	_player_area.collision_layer = 1
	_player_area.collision_mask = 4
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 15.0
	shape.shape = circle
	_player_area.add_child(shape)
	_player_area.area_entered.connect(_on_contact)
	add_child(_player_area)

	_prev_x = position.x


func _process(delta: float) -> void:
	# Input movement
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	position += input_dir * speed * delta
	# Clamp to screen
	position.x = clampf(position.x, 50.0, 1870.0)
	position.y = clampf(position.y, 50.0, 936.0)
	# Shield regen
	shield = minf(shield + shield_regen * delta, float(shield_max))

	# Banking animation from horizontal velocity
	var velocity_x: float = (position.x - _prev_x) / maxf(delta, 0.001)
	_prev_x = position.x
	var target_bank: float = clampf(-velocity_x / maxf(speed, 1.0), -1.0, 1.0)
	_bank = lerpf(_bank, target_bank, minf(delta * 8.0, 1.0))
	_time += delta
	queue_redraw()


func _input(event: InputEvent) -> void:
	# Individual hardpoint toggles (1-9)
	for i in mini(_hardpoint_controllers.size(), 9):
		var action: String = "hardpoint_" + str(i + 1)
		if event.is_action_pressed(action):
			_hardpoint_controllers[i].toggle()
			_update_hud_hardpoints()
			return

	# Space: toggle all on/off
	if event.is_action_pressed("hardpoints_max"):
		_space_state = 1 - _space_state
		for c in _hardpoint_controllers:
			if _space_state == 1:
				c.activate()
			else:
				c.deactivate()
		_update_hud_hardpoints()
		return

	# Deactivate all (C)
	if event.is_action_pressed("hardpoints_off"):
		for c in _hardpoint_controllers:
			c.deactivate()
		_update_hud_hardpoints()
		return


func _update_hud_hardpoints() -> void:
	if not _hud or not _hud.has_method("update_hardpoints"):
		return
	var data: Array = []
	for i in _hardpoint_controllers.size():
		var controller: Node2D = _hardpoint_controllers[i]
		var hp_info: Dictionary = _weapon_data_per_hp[i]
		var weapon: WeaponData = hp_info["weapon"]
		data.append({
			"label": hp_info["label"],
			"weapon_name": weapon.display_name if weapon.display_name != "" else weapon.id,
			"color": Color.CYAN,
			"active": controller.is_active(),
		})
	_hud.update_hardpoints(data)


func take_damage(amount: int) -> void:
	var remaining: int = amount
	if shield > 0.0:
		var absorbed: int = mini(remaining, int(shield))
		shield -= float(absorbed)
		remaining -= absorbed
	hull -= remaining
	if hull <= 0:
		hull = 0
		died.emit()


func stop_all() -> void:
	for c in _hardpoint_controllers:
		if c.has_method("deactivate"):
			c.deactivate()
		if c.has_method("cleanup"):
			c.cleanup()


func apply_bar_effects(effects: Dictionary) -> void:
	for bar_type in effects:
		var delta: float = float(effects[bar_type])
		match str(bar_type):
			"shield":
				shield = clampf(shield + delta, 0.0, float(shield_max))
			"hull":
				_hull_accumulator += delta
				if absf(_hull_accumulator) >= 1.0:
					var int_part: int = int(_hull_accumulator)
					hull = clampi(hull + int_part, 0, hull_max)
					_hull_accumulator -= float(int_part)
			"thermal":
				thermal = clampf(thermal + delta, 0.0, thermal_max)
			"electric":
				electric = clampf(electric + delta, 0.0, electric_max)


func _on_contact(area: Area2D) -> void:
	take_damage(15)


# ── Chrome Stiletto Drawing ──────────────────────────────────────

func _bx(x: float, s: float, intensity: float) -> float:
	var sf: float = signf(x) if x != 0.0 else 0.0
	return x * (1.0 + _bank * sf * intensity) * s

func _bp(x: float, y: float, s: float, intensity: float) -> Vector2:
	return Vector2(_bx(x, s, intensity) + _bank * 2.5 * s, y * s)

func _side_color(base: Color, side: float) -> Color:
	var col := base
	col.a = clampf(col.a + _bank * side * 0.06, 0.5, 1.0)
	return col


func _draw() -> void:
	_draw_stiletto()


func _draw_stiletto() -> void:
	var s := 1.4

	# Diamond faceted body
	var hull_poly := PackedVector2Array([
		_bp(0, -35, s, 0.1),
		_bp(14, -12, s, 0.15),
		_bp(28, 4, s, 0.2),
		_bp(22, 14, s, 0.18),
		_bp(10, 24, s, 0.1),
		_bp(-10, 24, s, 0.1),
		_bp(-22, 14, s, 0.18),
		_bp(-28, 4, s, 0.2),
		_bp(-14, -12, s, 0.15),
	])
	_draw_chrome_polygon(hull_poly, hull_color, _bank)

	# Facet edge lines
	_draw_chrome_line(_bp(0, -32, s, 0.1), _bp(14, -12, s, 0.15), detail_color, 0.8 * s)
	_draw_chrome_line(_bp(0, -32, s, 0.1), _bp(-14, -12, s, 0.15), detail_color, 0.8 * s)
	_draw_chrome_line(_bp(14, -12, s, 0.15), _bp(10, 24, s, 0.1), detail_color, 0.8 * s)
	_draw_chrome_line(_bp(-14, -12, s, 0.15), _bp(-10, 24, s, 0.1), detail_color, 0.8 * s)
	# Cross facet
	_draw_chrome_line(_bp(-14, -12, s, 0.15), _bp(14, -12, s, 0.15), detail_color, 0.6 * s)

	# Angular canopy slit
	var cx: float = -_bank * 1.2 * s
	var can := PackedVector2Array([
		_bp(0, -28, s, 0.05) + Vector2(cx, 0),
		_bp(7, -14, s, 0.05) + Vector2(cx, 0),
		_bp(5, -6, s, 0.05) + Vector2(cx, 0),
		_bp(-5, -6, s, 0.05) + Vector2(cx, 0),
		_bp(-7, -14, s, 0.05) + Vector2(cx, 0),
	])
	_draw_chrome_canopy(can, _bank)

	# Spine
	_draw_chrome_line(_bp(0, -6, s, 0.1), _bp(0, 20, s, 0.1), accent_color, 1.2 * s)

	# Twin tight engines
	var exhaust := Color(1.0, 0.8, 0.3, 0.8)
	_draw_chrome_line(_bp(-4, 22, s, 0.08), _bp(-4, 30, s, 0.08), exhaust, 3.0 * s)
	_draw_chrome_line(_bp(4, 22, s, 0.08), _bp(4, 30, s, 0.08), exhaust, 3.0 * s)


# ── Chrome rendering helpers ─────────────────────────────────────

func _draw_chrome_polygon(points: PackedVector2Array, tint_color: Color, bk: float) -> void:
	if points.size() < 3:
		return
	draw_colored_polygon(points, CHROME_DARK)

	var min_y := points[0].y
	var max_y := points[0].y
	var min_x := points[0].x
	var max_x := points[0].x
	for pt in points:
		min_y = minf(min_y, pt.y)
		max_y = maxf(max_y, pt.y)
		min_x = minf(min_x, pt.x)
		max_x = maxf(max_x, pt.x)
	var height: float = max_y - min_y
	var width: float = max_x - min_x
	if height < 0.5 or width < 0.5:
		return

	# Horizontal gradient bands
	var band_colors: Array[Color] = [
		CHROME_DARK.lerp(CHROME_MID, 0.3),
		CHROME_MID,
		CHROME_LIGHT,
		CHROME_BRIGHT,
	]
	var band_count: int = band_colors.size()
	for i in range(band_count):
		var t0: float = float(i) / float(band_count)
		var t1: float = float(i + 1) / float(band_count)
		var y0: float = max_y - t0 * height
		var y1: float = max_y - t1 * height
		var band_rect := PackedVector2Array([
			Vector2(min_x - 5.0, y0),
			Vector2(max_x + 5.0, y0),
			Vector2(max_x + 5.0, y1),
			Vector2(min_x - 5.0, y1),
		])
		var clipped: Array = Geometry2D.intersect_polygons(points, band_rect)
		for clip_idx in range(clipped.size()):
			var clip_poly: PackedVector2Array = clipped[clip_idx]
			if clip_poly.size() >= 3:
				draw_colored_polygon(clip_poly, band_colors[i])

	# Bank-reactive left/right shading
	var center_x: float = (min_x + max_x) * 0.5
	var left_rect := PackedVector2Array([
		Vector2(min_x - 5.0, min_y - 5.0),
		Vector2(center_x, min_y - 5.0),
		Vector2(center_x, max_y + 5.0),
		Vector2(min_x - 5.0, max_y + 5.0),
	])
	var right_rect := PackedVector2Array([
		Vector2(center_x, min_y - 5.0),
		Vector2(max_x + 5.0, min_y - 5.0),
		Vector2(max_x + 5.0, max_y + 5.0),
		Vector2(center_x, max_y + 5.0),
	])

	var left_alpha: float = clampf(-bk * 0.15, -0.08, 0.15)
	var right_alpha: float = clampf(bk * 0.15, -0.08, 0.15)
	if left_alpha > 0.01:
		var left_clips: Array = Geometry2D.intersect_polygons(points, left_rect)
		for clip_idx in range(left_clips.size()):
			var clip_poly: PackedVector2Array = left_clips[clip_idx]
			if clip_poly.size() >= 3:
				draw_colored_polygon(clip_poly, Color(1.0, 1.0, 1.0, left_alpha))
	elif left_alpha < -0.01:
		var left_clips: Array = Geometry2D.intersect_polygons(points, left_rect)
		for clip_idx in range(left_clips.size()):
			var clip_poly: PackedVector2Array = left_clips[clip_idx]
			if clip_poly.size() >= 3:
				draw_colored_polygon(clip_poly, Color(0.0, 0.0, 0.0, -left_alpha))
	if right_alpha > 0.01:
		var right_clips: Array = Geometry2D.intersect_polygons(points, right_rect)
		for clip_idx in range(right_clips.size()):
			var clip_poly: PackedVector2Array = right_clips[clip_idx]
			if clip_poly.size() >= 3:
				draw_colored_polygon(clip_poly, Color(1.0, 1.0, 1.0, right_alpha))
	elif right_alpha < -0.01:
		var right_clips: Array = Geometry2D.intersect_polygons(points, right_rect)
		for clip_idx in range(right_clips.size()):
			var clip_poly: PackedVector2Array = right_clips[clip_idx]
			if clip_poly.size() >= 3:
				draw_colored_polygon(clip_poly, Color(0.0, 0.0, 0.0, -right_alpha))

	# Specular highlight
	var spec_x: float = center_x + bk * width * 0.4 + sin(_time * 0.8) * width * 0.05
	var spec_brightness: float = 0.9 + sin(_time * 1.2) * 0.1
	var gleam_layers: Array[Array] = [
		[width * 0.22, 0.06],
		[width * 0.14, 0.12],
		[width * 0.08, 0.20],
		[width * 0.03, 0.35],
	]
	for layer in gleam_layers:
		var half_w: float = layer[0]
		var alpha: float = layer[1] * spec_brightness
		var strip := PackedVector2Array([
			Vector2(spec_x - half_w, min_y - 5.0),
			Vector2(spec_x + half_w, min_y - 5.0),
			Vector2(spec_x + half_w, max_y + 5.0),
			Vector2(spec_x - half_w, max_y + 5.0),
		])
		var strip_clips: Array = Geometry2D.intersect_polygons(points, strip)
		for clip_idx in range(strip_clips.size()):
			var clip_poly: PackedVector2Array = strip_clips[clip_idx]
			if clip_poly.size() >= 3:
				draw_colored_polygon(clip_poly, Color(1.0, 1.0, 1.0, alpha))

	# Color tint overlay
	var tint := tint_color
	tint.a = 0.08
	draw_colored_polygon(points, tint)

	# Chrome edges
	_draw_chrome_edges(points, bk)


func _draw_chrome_edges(points: PackedVector2Array, bk: float) -> void:
	if points.size() < 2:
		return
	var light_dir := Vector2(bk * 0.7, -1.0).normalized()
	for i in range(points.size()):
		var ni: int = (i + 1) % points.size()
		var a: Vector2 = points[i]
		var b: Vector2 = points[ni]
		var edge_dir: Vector2 = (b - a).normalized()
		var edge_normal := Vector2(-edge_dir.y, edge_dir.x)
		var facing: float = edge_normal.dot(light_dir)
		var brightness: float = clampf(facing * 0.5 + 0.5, 0.15, 1.0)
		var edge_col := CHROME_DARK.lerp(CHROME_SPEC, brightness)
		edge_col.a = 0.6 + brightness * 0.4
		draw_line(a, b, edge_col, 1.5, true)


func _draw_chrome_line(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	var perp: Vector2 = (b - a).normalized()
	perp = Vector2(-perp.y, perp.x)
	var shadow_off: Vector2 = perp * 1.0
	draw_line(a + shadow_off, b + shadow_off, CHROME_DARK, width * 1.2, true)
	draw_line(a - shadow_off, b - shadow_off, CHROME_BRIGHT, width * 0.8, true)
	var mid := CHROME_MID.lerp(color, 0.15)
	draw_line(a, b, mid, width, true)
	var spec_brightness: float = 0.9 + sin(_time * 1.2) * 0.1
	var spec := CHROME_SPEC
	spec.a = 0.4 * spec_brightness
	draw_line(a, b, spec, width * 0.3, true)


func _draw_chrome_canopy(points: PackedVector2Array, bk: float) -> void:
	if points.size() < 3:
		return
	var glass := Color(0.05, 0.08, 0.2, 0.85)
	draw_colored_polygon(points, glass)
	_draw_chrome_edges(points, bk)
