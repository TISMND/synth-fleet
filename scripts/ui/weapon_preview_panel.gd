class_name WeaponPreviewPanel
extends HardNeonPreview
## Visual weapon fire pattern renderer for the Studio weapons tab.
## Draws ship at bottom and spawns visual-only projectiles based on fire_pattern.

const COLOR_MAP := {
	"cyan": Color(0, 1, 1),
	"magenta": Color(1, 0, 1),
	"yellow": Color(1, 1, 0),
	"green": Color(0, 1, 0.5),
	"orange": Color(1, 0.5, 0),
	"red": Color(1, 0.2, 0.2),
	"blue": Color(0.3, 0.3, 1),
	"white": Color(1, 1, 1),
}

var _weapon: WeaponData
var _projectiles: Array[Dictionary] = []
var _preview_color: Color = Color(0, 1, 1)
var _fire_pattern: String = "single"
var _burst_queue: int = 0
var _burst_timer: float = 0.0
var _beam_active: bool = false
var _beam_pulse: float = 0.0


func _ready() -> void:
	super._ready()
	apply_preset("tight")


func set_weapon(w: WeaponData) -> void:
	_weapon = w
	_fire_pattern = w.fire_pattern
	_projectiles.clear()
	_burst_queue = 0
	_beam_active = false


func set_preview_color(c: String) -> void:
	if COLOR_MAP.has(c):
		_preview_color = COLOR_MAP[c]
		projectile_color = _preview_color


func _on_beat_hit(_beat_index: int) -> void:
	super._on_beat_hit(_beat_index)
	if not _weapon:
		return
	_spawn_projectiles()


func _spawn_projectiles() -> void:
	var vp := get_rect().size
	var cx := vp.x * 0.5
	var sy := vp.y * 0.76
	var speed := 200.0

	match _fire_pattern:
		"single":
			_projectiles.append({"pos": Vector2(cx, sy - 20), "vel": Vector2(0, -speed), "age": 0.0})
		"burst":
			_burst_queue = 3
			_burst_timer = 0.0
		"dual":
			_projectiles.append({"pos": Vector2(cx - 15, sy - 20), "vel": Vector2(0, -speed), "age": 0.0})
			_projectiles.append({"pos": Vector2(cx + 15, sy - 20), "vel": Vector2(0, -speed), "age": 0.0})
		"wave":
			_projectiles.append({"pos": Vector2(cx, sy - 20), "vel": Vector2(0, -speed), "age": 0.0, "wave": true, "base_x": cx})
		"spread":
			for angle_deg in [-20.0, 0.0, 20.0]:
				var rad := deg_to_rad(angle_deg - 90.0)
				var vel := Vector2(cos(rad), sin(rad)) * speed
				_projectiles.append({"pos": Vector2(cx, sy - 20), "vel": vel, "age": 0.0})
		"beam":
			_beam_active = true
			_beam_pulse = 1.0
		"scatter":
			for i in 4:
				var angle_deg := randf_range(-40.0, 40.0)
				var rad := deg_to_rad(angle_deg - 90.0)
				var vel := Vector2(cos(rad), sin(rad)) * speed * randf_range(0.8, 1.2)
				_projectiles.append({"pos": Vector2(cx, sy - 20), "vel": vel, "age": 0.0})


func _process(delta: float) -> void:
	super._process(delta)

	# Handle burst firing
	if _burst_queue > 0:
		_burst_timer += delta
		if _burst_timer >= 0.06:
			_burst_timer = 0.0
			_burst_queue -= 1
			var vp := get_rect().size
			var cx := vp.x * 0.5
			var sy := vp.y * 0.76
			_projectiles.append({"pos": Vector2(cx, sy - 20), "vel": Vector2(0, -200.0), "age": 0.0})

	# Beam decay
	if _beam_active:
		_beam_pulse = move_toward(_beam_pulse, 0.0, delta * 2.0)
		if _beam_pulse <= 0.0:
			_beam_active = false

	# Move projectiles
	var vp := get_rect().size
	var to_remove: Array[int] = []
	for i in _projectiles.size():
		var p: Dictionary = _projectiles[i]
		p["age"] += delta
		p["pos"] += p["vel"] * delta

		# Wave pattern: apply sine to x
		if p.get("wave", false):
			p["pos"].x = p["base_x"] + sin(p["age"] * 8.0) * 30.0

		# Remove off-screen
		if p["pos"].y < -20 or p["pos"].y > vp.y + 20 or p["pos"].x < -20 or p["pos"].x > vp.x + 20:
			to_remove.append(i)

	# Remove in reverse order
	to_remove.reverse()
	for idx in to_remove:
		_projectiles.remove_at(idx)


func _draw() -> void:
	# Background
	draw_rect(Rect2(Vector2.ZERO, get_rect().size), Color(0.02, 0.02, 0.05, 1.0))

	var pulse := _pulse_t * pulse_strength
	var vp := get_rect().size

	# Ship at bottom
	_draw_neon_poly(closed_poly(offset_points(SHIP_POINTS, ship_pos)), ship_color, pulse)

	# Beam
	if _beam_active:
		var cx := vp.x * 0.5
		var sy := vp.y * 0.76 - 20
		var beam_width := 3.0 + _beam_pulse * 6.0
		var beam_points := PackedVector2Array([
			Vector2(cx, sy),
			Vector2(cx, 0),
		])
		_draw_neon_poly(beam_points, _preview_color, _beam_pulse)

	# Projectiles
	var pr := PROJECTILE_RECT
	for p in _projectiles:
		var pos: Vector2 = p["pos"]
		var proj_points := PackedVector2Array([
			pos + Vector2(pr.position.x, pr.position.y),
			pos + Vector2(pr.position.x + pr.size.x, pr.position.y),
			pos + Vector2(pr.position.x + pr.size.x, pr.position.y + pr.size.y),
			pos + Vector2(pr.position.x, pr.position.y + pr.size.y),
			pos + Vector2(pr.position.x, pr.position.y),
		])
		_draw_neon_poly(proj_points, _preview_color, pulse)

	# Weapon name label
	if _weapon:
		draw_string(ThemeDB.fallback_font, Vector2(10, 24), _weapon.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, _preview_color)
