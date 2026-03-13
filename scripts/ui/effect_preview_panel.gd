class_name EffectPreviewPanel
extends HardNeonPreview
## Live preview for the Effect Designer. Simulates projectiles with all 4 layers
## (muzzle, shape, trail, impact) rendered in _draw(). No real GPUParticles2D.

var effect_profile: EffectProfile = null

var _projectiles: Array[Dictionary] = []
var _muzzle_effects: Array[Dictionary] = []
var _impact_effects: Array[Dictionary] = []
var _target_pos: Vector2 = Vector2.ZERO
var _target_hp: int = 3
var _target_respawn_timer: float = 0.0

const TARGET_RESPAWN_DELAY := 1.2


func _ready() -> void:
	super._ready()
	apply_preset("tight")


func _recalculate_positions() -> void:
	super._recalculate_positions()
	_target_pos = enemy_pos


func _on_beat_hit(_beat_index: int) -> void:
	super._on_beat_hit(_beat_index)
	_fire_projectile()


func _fire_projectile() -> void:
	var vp := get_rect().size
	var cx := vp.x * 0.5
	var sy := vp.y * 0.76
	var spawn_pos := Vector2(cx, sy - 20)
	_projectiles.append({
		"pos": spawn_pos,
		"vel": Vector2(0, -220.0),
		"age": 0.0,
		"trail": [] as Array[Dictionary],
		"base_x": spawn_pos.x,
	})
	# Muzzle effect
	_spawn_muzzle_effect(spawn_pos)


func _spawn_muzzle_effect(pos: Vector2) -> void:
	if not effect_profile or effect_profile.muzzle_type == "none":
		return
	var mp := effect_profile.muzzle_params
	match effect_profile.muzzle_type:
		"radial_burst", "directional_flash":
			var md := EffectProfile.get_muzzle_defaults(effect_profile.muzzle_type)
			var count := int(mp.get("particle_count", md["particle_count"]))
			var lt := float(mp.get("lifetime", md["lifetime"]))
			var spread := float(mp.get("spread_angle", md["spread_angle"]))
			var vel_max := float(mp.get("velocity_max", md["velocity_max"]))
			var particles: Array[Dictionary] = []
			for i in count:
				var angle: float
				if effect_profile.muzzle_type == "directional_flash":
					angle = deg_to_rad(-90.0 + randf_range(-spread / 2.0, spread / 2.0))
				else:
					angle = deg_to_rad(randf_range(-spread / 2.0, spread / 2.0) - 90.0)
				var spd := randf_range(vel_max * 0.4, vel_max)
				particles.append({
					"offset": Vector2(cos(angle), sin(angle)) * spd,
					"alpha": 1.0,
				})
			_muzzle_effects.append({
				"pos": pos,
				"age": 0.0,
				"lifetime": lt,
				"particles": particles,
				"type": "particles",
			})
		"ring_pulse":
			var md := EffectProfile.get_muzzle_defaults("ring_pulse")
			_muzzle_effects.append({
				"pos": pos,
				"age": 0.0,
				"lifetime": float(mp.get("lifetime", md["lifetime"])),
				"radius_end": float(mp.get("radius_end", md["radius_end"])),
				"segments": int(mp.get("segments", md["segments"])),
				"line_width": float(mp.get("line_width", md["line_width"])),
				"type": "ring",
			})
		"spiral_burst":
			var md := EffectProfile.get_muzzle_defaults("spiral_burst")
			var count := int(mp.get("particle_count", md["particle_count"]))
			var lt := float(mp.get("lifetime", md["lifetime"]))
			var vel_max := float(mp.get("velocity_max", md["velocity_max"]))
			var spiral_spd := float(mp.get("spiral_speed", md["spiral_speed"]))
			var particles: Array[Dictionary] = []
			for i in count:
				var base_angle := TAU * float(i) / float(count)
				var spd := randf_range(vel_max * 0.4, vel_max)
				particles.append({
					"base_angle": base_angle,
					"speed": spd,
					"spiral_speed": spiral_spd,
				})
			_muzzle_effects.append({
				"pos": pos,
				"age": 0.0,
				"lifetime": lt,
				"particles": particles,
				"type": "spiral",
			})


func _spawn_impact_effect(pos: Vector2) -> void:
	if not effect_profile or effect_profile.impact_type == "none":
		return
	var ip := effect_profile.impact_params
	match effect_profile.impact_type:
		"burst":
			var id := EffectProfile.get_impact_defaults("burst")
			var count := int(ip.get("particle_count", id["particle_count"]))
			var lt := float(ip.get("lifetime", id["lifetime"]))
			var vel_max := float(ip.get("velocity_max", id["velocity_max"]))
			var particles: Array[Dictionary] = []
			for i in count:
				var angle := randf_range(0.0, TAU)
				var spd := randf_range(vel_max * 0.3, vel_max)
				particles.append({
					"offset": Vector2(cos(angle), sin(angle)) * spd,
					"alpha": 1.0,
				})
			_impact_effects.append({
				"pos": pos, "age": 0.0, "lifetime": lt,
				"particles": particles, "type": "particles",
			})
		"ring_expand":
			var id := EffectProfile.get_impact_defaults("ring_expand")
			_impact_effects.append({
				"pos": pos, "age": 0.0,
				"lifetime": float(ip.get("lifetime", id["lifetime"])),
				"radius_end": float(ip.get("radius_end", id["radius_end"])),
				"segments": int(ip.get("segments", id["segments"])),
				"type": "ring",
			})
		"shatter_lines":
			var id := EffectProfile.get_impact_defaults("shatter_lines")
			var lc := int(ip.get("line_count", id["line_count"]))
			var lines: Array[Dictionary] = []
			for i in lc:
				var angle := TAU * float(i) / float(lc) + randf_range(-0.3, 0.3)
				lines.append({"angle": angle})
			_impact_effects.append({
				"pos": pos, "age": 0.0,
				"lifetime": float(ip.get("lifetime", id["lifetime"])),
				"line_length": float(ip.get("line_length", id["line_length"])),
				"velocity": float(ip.get("velocity", id["velocity"])),
				"lines": lines, "type": "shatter",
			})
		"nova_flash":
			var id := EffectProfile.get_impact_defaults("nova_flash")
			_impact_effects.append({
				"pos": pos, "age": 0.0,
				"lifetime": float(ip.get("lifetime", id["lifetime"])),
				"radius": float(ip.get("radius", id["radius"])),
				"intensity": float(ip.get("intensity", id["intensity"])),
				"type": "nova",
			})
		"ripple":
			var id := EffectProfile.get_impact_defaults("ripple")
			var ring_count := int(ip.get("ring_count", id["ring_count"]))
			var stagger: float = ip.get("stagger", id["stagger"])
			for ri in ring_count:
				_impact_effects.append({
					"pos": pos, "age": -stagger * float(ri),
					"lifetime": float(ip.get("lifetime", id["lifetime"])),
					"radius_end": float(ip.get("radius_end", id["radius_end"])),
					"segments": int(ip.get("segments", id["segments"])),
					"type": "ring",
				})


func set_effect_profile(ep: EffectProfile) -> void:
	effect_profile = ep
	_projectiles.clear()
	_muzzle_effects.clear()
	_impact_effects.clear()


func _process(delta: float) -> void:
	super._process(delta)

	var vp := get_rect().size

	# Target respawn
	if _target_hp <= 0:
		_target_respawn_timer += delta
		if _target_respawn_timer >= TARGET_RESPAWN_DELAY:
			_target_hp = 3
			_target_respawn_timer = 0.0

	# Move projectiles
	var to_remove: Array[int] = []
	for i in _projectiles.size():
		var p: Dictionary = _projectiles[i]
		p["age"] += delta
		p["pos"] += p["vel"] * delta
		# Apply motion modifiers in preview
		if effect_profile and effect_profile.motion_type != "none":
			var mp := effect_profile.motion_params
			var md := EffectProfile.get_motion_defaults(effect_profile.motion_type)
			var amp: float = mp.get("amplitude", md.get("amplitude", 8.0))
			var freq: float = mp.get("frequency", md.get("frequency", 3.0))
			var phase: float = mp.get("phase_offset", md.get("phase_offset", 0.0))
			var age: float = p["age"]
			var base_x: float = p["base_x"]
			match effect_profile.motion_type:
				"sine_wave":
					p["pos"].x = base_x + sin(age * freq * TAU + phase) * amp
				"corkscrew":
					p["pos"].x = base_x + cos(age * freq * TAU + phase) * amp
				"wobble":
					p["pos"].x = base_x + sin(age * freq * TAU + phase) * amp * sin(age * freq * 2.0)

		# Trail recording
		var trail: Array = p["trail"]
		trail.append({"pos": Vector2(p["pos"]), "alpha": 1.0})
		if trail.size() > 15:
			trail.pop_front()
		# Fade trail entries
		for t_entry in trail:
			t_entry["alpha"] = maxf(0.0, t_entry["alpha"] - delta * 4.0)

		# Check collision with target
		if _target_hp > 0 and p["pos"].distance_to(_target_pos) < 18.0:
			_target_hp -= 1
			_spawn_impact_effect(p["pos"])
			to_remove.append(i)
			continue

		# Remove off-screen
		if p["pos"].y < -30 or p["pos"].y > vp.y + 30:
			to_remove.append(i)

	to_remove.reverse()
	for idx in to_remove:
		_projectiles.remove_at(idx)

	# Update muzzle effects
	var muzzle_remove: Array[int] = []
	for i in _muzzle_effects.size():
		_muzzle_effects[i]["age"] += delta
		if _muzzle_effects[i]["age"] >= _muzzle_effects[i]["lifetime"]:
			muzzle_remove.append(i)
	muzzle_remove.reverse()
	for idx in muzzle_remove:
		_muzzle_effects.remove_at(idx)

	# Update impact effects
	var impact_remove: Array[int] = []
	for i in _impact_effects.size():
		_impact_effects[i]["age"] += delta
		if _impact_effects[i]["age"] >= _impact_effects[i]["lifetime"]:
			impact_remove.append(i)
	impact_remove.reverse()
	for idx in impact_remove:
		_impact_effects.remove_at(idx)


func _draw() -> void:
	# Background
	draw_rect(Rect2(Vector2.ZERO, get_rect().size), Color(0.02, 0.02, 0.05, 1.0))

	var pulse := _pulse_t * pulse_strength
	var col := projectile_color

	# Ship
	_draw_neon_poly(closed_poly(offset_points(SHIP_POINTS, ship_pos)), ship_color, pulse)

	# Target (enemy)
	if _target_hp > 0:
		var target_alpha := float(_target_hp) / 3.0
		var tc := Color(enemy_color.r, enemy_color.g, enemy_color.b, target_alpha)
		_draw_neon_poly(closed_poly(offset_points(ENEMY_POINTS, _target_pos)), tc, pulse)

	# Projectile trails
	for p in _projectiles:
		_draw_projectile_trail(p, col)

	# Projectiles (shape from profile)
	for p in _projectiles:
		var shape_pts := _get_shape_points()
		# Pulse orb shimmer
		var scale_factor := 1.0
		if effect_profile and effect_profile.shape_type == "pulse_orb":
			var sp2 := effect_profile.shape_params
			var pulse_spd: float = sp2.get("pulse_speed", 4.0)
			var pulse_amt: float = sp2.get("pulse_amount", 1.5)
			var age: float = p["age"]
			scale_factor = 1.0 + sin(age * pulse_spd * TAU) * (pulse_amt - 1.0) * 0.5
		var pts := PackedVector2Array()
		for sp in shape_pts:
			pts.append(sp * scale_factor + p["pos"])
		if pts.size() > 0:
			pts.append(pts[0])
		_draw_neon_poly(pts, col, pulse)

	# Muzzle effects
	for fx in _muzzle_effects:
		_draw_muzzle_effect(fx, col)

	# Impact effects
	for fx in _impact_effects:
		_draw_impact_effect(fx, col)

	# Label
	if effect_profile:
		var name_text := effect_profile.display_name if effect_profile.display_name != "" else "Untitled Effect"
		draw_string(ThemeDB.fallback_font, Vector2(10, 24), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)


func _get_shape_points() -> PackedVector2Array:
	if effect_profile:
		return effect_profile.get_shape_points()
	return PackedVector2Array([Vector2(-2, -6), Vector2(2, -6), Vector2(2, 6), Vector2(-2, 6)])


func _draw_projectile_trail(p: Dictionary, col: Color) -> void:
	if not effect_profile:
		return
	var trail_type := effect_profile.trail_type if effect_profile else "none"
	if trail_type == "none":
		return

	var trail: Array = p["trail"]
	match trail_type:
		"particle", "sparkle":
			for t_entry in trail:
				var alpha: float = t_entry["alpha"] * 0.4
				if alpha <= 0.01:
					continue
				var tc := Color(col.r, col.g, col.b, alpha)
				var tpos: Vector2 = t_entry["pos"]
				draw_circle(tpos, 1.5, tc)
		"ribbon":
			if trail.size() >= 2:
				var pts := PackedVector2Array()
				for t_entry in trail:
					pts.append(t_entry["pos"])
				var tp := effect_profile.trail_params
				var td := EffectProfile.get_trail_defaults("ribbon")
				var ws: float = tp.get("width_start", td["width_start"])
				var tc := Color(col.r, col.g, col.b, 0.5)
				draw_polyline(pts, tc, ws, true)
		"afterimage":
			var shape_pts := _get_shape_points()
			var count := 0
			for i in range(trail.size() - 1, -1, -2):
				if count >= 5:
					break
				var t_entry: Dictionary = trail[i]
				var alpha: float = t_entry["alpha"] * 0.3
				if alpha <= 0.01:
					continue
				var pts := PackedVector2Array()
				for sp in shape_pts:
					pts.append(sp + t_entry["pos"])
				if pts.size() > 0:
					pts.append(pts[0])
				var tc := Color(col.r, col.g, col.b, alpha)
				draw_polyline(pts, tc, 1.5, true)
				count += 1
		"sine_ribbon":
			if trail.size() >= 2:
				var tp2 := effect_profile.trail_params if effect_profile else {}
				var td2 := EffectProfile.get_trail_defaults("sine_ribbon")
				var ws2: float = tp2.get("width_start", td2["width_start"])
				var wave_amp: float = tp2.get("wave_amplitude", td2["wave_amplitude"])
				var wave_freq: float = tp2.get("wave_frequency", td2["wave_frequency"])
				var pts := PackedVector2Array()
				for ti in trail.size():
					var tpos: Vector2 = trail[ti]["pos"]
					var wave_offset := sin(float(ti) / float(trail.size()) * wave_freq * TAU) * wave_amp
					pts.append(tpos + Vector2(wave_offset, 0))
				var tc := Color(col.r, col.g, col.b, 0.5)
				draw_polyline(pts, tc, ws2, true)


func _draw_muzzle_effect(fx: Dictionary, col: Color) -> void:
	var t: float = fx["age"] / fx["lifetime"]
	if t < 0.0:
		return
	var alpha := 1.0 - t

	match fx["type"]:
		"particles":
			for particle in fx["particles"]:
				var pos: Vector2 = fx["pos"] + particle["offset"] * (fx["age"])
				var pc := Color(col.r, col.g, col.b, alpha * 0.6)
				draw_circle(pos, 1.5, pc)
		"ring":
			var radius := lerpf(0.0, fx["radius_end"], t)
			var segs: int = fx["segments"]
			var pts := PackedVector2Array()
			for i in segs + 1:
				var angle := TAU * float(i) / float(segs)
				pts.append(fx["pos"] + Vector2(cos(angle) * radius, sin(angle) * radius))
			var rc := Color(col.r, col.g, col.b, alpha * 0.7)
			draw_polyline(pts, rc, fx.get("line_width", 3.0) * (1.0 - t * 0.5), true)
		"spiral":
			for particle in fx["particles"]:
				var base_angle: float = particle["base_angle"]
				var spd: float = particle["speed"]
				var spiral_spd: float = particle["spiral_speed"]
				var cur_angle: float = base_angle + float(fx["age"]) * spiral_spd
				var dist: float = spd * float(fx["age"])
				var pos: Vector2 = fx["pos"] + Vector2(cos(cur_angle), sin(cur_angle)) * dist
				var pc := Color(col.r, col.g, col.b, alpha * 0.6)
				draw_circle(pos, 1.5, pc)


func _draw_impact_effect(fx: Dictionary, col: Color) -> void:
	if fx["age"] < 0.0:
		return
	var t: float = fx["age"] / fx["lifetime"]
	var alpha := 1.0 - t

	match fx["type"]:
		"particles":
			for particle in fx["particles"]:
				var pos: Vector2 = fx["pos"] + particle["offset"] * fx["age"]
				var pc := Color(col.r, col.g, col.b, alpha * 0.6)
				draw_circle(pos, 2.0, pc)
		"ring":
			var radius := lerpf(0.0, fx["radius_end"], t)
			var segs: int = fx["segments"]
			var pts := PackedVector2Array()
			for i in segs + 1:
				var angle := TAU * float(i) / float(segs)
				pts.append(fx["pos"] + Vector2(cos(angle) * radius, sin(angle) * radius))
			var rc := Color(col.r, col.g, col.b, alpha * 0.7)
			draw_polyline(pts, rc, 3.0 * (1.0 - t * 0.5), true)
		"shatter":
			var dist: float = fx["velocity"] * fx["age"]
			var ll: float = fx["line_length"] * (1.0 - t * 0.5)
			for line_data in fx["lines"]:
				var angle: float = line_data["angle"]
				var dir := Vector2(cos(angle), sin(angle))
				var start: Vector2 = fx["pos"] + dir * dist
				var end_pt: Vector2 = fx["pos"] + dir * (dist + ll)
				var lc := Color(col.r, col.g, col.b, alpha * 0.7)
				draw_line(start, end_pt, lc, 2.0, true)
		"nova":
			var current_radius := lerpf(fx["radius"] * 0.3, fx["radius"], t)
			var nova_alpha: float = alpha * fx["intensity"]
			var gc := Color(col.r, col.g, col.b, nova_alpha * 0.3)
			draw_circle(fx["pos"], current_radius * 1.3, gc)
			var mc := col.lerp(Color.WHITE, 0.4)
			mc.a = nova_alpha * 0.6
			draw_circle(fx["pos"], current_radius, mc)
