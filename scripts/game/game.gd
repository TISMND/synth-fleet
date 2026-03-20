extends Node2D
## Game orchestrator — loads ship + weapons from ShipRegistry + GameState slot_config.

const WAVE_CONFIG: Array[Dictionary] = [
	{"count": 6, "health": 30, "speed_min": 80.0, "speed_max": 140.0, "spawn_interval": 1.2, "delay_after": 3.0},
	{"count": 6, "health": 30, "speed_min": 80.0, "speed_max": 140.0, "spawn_interval": 1.2, "delay_after": 3.0},
	{"count": 6, "health": 30, "speed_min": 80.0, "speed_max": 140.0, "spawn_interval": 1.2, "delay_after": 3.0},
]

var _player: Node2D = null
var _wave_manager: WaveManager = null
var _hud: Control = null
var _projectiles: Node2D = null
var _enemies: Node2D = null
var _parallax_bg: ParallaxBackground = null
var _nebula_container: Node2D = null
var _level_data: LevelData = null
var _scroll_distance: float = 0.0
var _scroll_speed: float = 80.0
var _presence_counts: Dictionary = {}  # ship_id -> int (active enemy count)
var _presence_loops: Dictionary = {}   # ship_id -> presence_loop_path

# Nebula status effects
var _nebula_areas: Array = []  # Array of {area: Area2D, nebula_data: NebulaData}
var _active_nebula_effects: Array = []  # NebulaData objects currently overlapping the player
var _nebula_bar_accumulators: Dictionary = {}  # bar_name -> float accumulator for sub-frame amounts
var _player_base_speed: float = 400.0
var _player_base_modulate_a: float = 1.0

const NEBULA_STYLES: Dictionary = {
	"classic_fbm": {"shader": "res://assets/shaders/nebula_classic_fbm.gdshader", "dual": false},
	"wispy_filaments": {"shader": "res://assets/shaders/nebula_wispy_filaments.gdshader", "dual": false},
	"dual_color": {"shader": "res://assets/shaders/nebula_dual_color.gdshader", "dual": true},
	"voronoi": {"shader": "res://assets/shaders/nebula_voronoi.gdshader", "dual": false},
	"turbulent_swirl": {"shader": "res://assets/shaders/nebula_turbulent_swirl.gdshader", "dual": false},
	"electric_filaments": {"shader": "res://assets/shaders/nebula_electric_filaments.gdshader", "dual": false},
	"lightning_strike": {"shader": "res://assets/shaders/nebula_lightning_strike.gdshader", "dual": false},
	"arc_discharge": {"shader": "res://assets/shaders/nebula_arc_discharge.gdshader", "dual": false},
	"energy_flare": {"shader": "res://assets/shaders/nebula_energy_flare.gdshader", "dual": false},
	"dual_swirl": {"shader": "res://assets/shaders/nebula_dual_swirl.gdshader", "dual": true},
	"dual_voronoi": {"shader": "res://assets/shaders/nebula_dual_voronoi.gdshader", "dual": true},
}

## Set this before adding to the scene tree to use a specific level.
var level_id: String = ""


func _ready() -> void:
	# Build ShipData — start from registry, then apply user overrides for stats/render
	var ship: ShipData = ShipRegistry.build_ship_data(GameState.current_ship_index)
	var ship_override: ShipData = ShipDataManager.load_by_id(ship.id)
	if ship_override:
		ship.stats = ship_override.stats
		ship.render_mode = ship_override.render_mode
	var loadout: LoadoutData = GameState.get_loadout_data()

	# Load level data if available
	if level_id == "" and GameState.current_level_id != "":
		level_id = GameState.current_level_id
		GameState.current_level_id = ""
	if level_id != "":
		_level_data = LevelDataManager.load_by_id(level_id)

	if _level_data:
		_scroll_speed = _level_data.scroll_speed

	# Build scene tree
	_setup_parallax()
	_setup_nebulas()

	_projectiles = Node2D.new()
	_projectiles.name = "Projectiles"
	add_child(_projectiles)

	_enemies = Node2D.new()
	_enemies.name = "Enemies"
	add_child(_enemies)

	# Player
	_player = Node2D.new()
	_player.set_script(load("res://scripts/game/player_ship.gd"))
	_player.name = "PlayerShip"
	add_child(_player)
	_player.setup(ship, loadout, _projectiles)
	_player.position = Vector2(960, 850)

	# Wave manager
	_wave_manager = WaveManager.new()
	_wave_manager.name = "WaveManager"
	add_child(_wave_manager)
	_wave_manager.all_waves_cleared.connect(_on_all_waves_cleared)
	_wave_manager.presence_pre_trigger.connect(_on_presence_pre_trigger)

	# HUD — Control (not CanvasLayer) so bars get WorldEnvironment glow
	_hud = Control.new()
	_hud.set_script(load("res://scripts/game/hud.gd"))
	_hud.name = "HUD"
	_hud.size = Vector2(1920, 1080)
	_hud.z_index = 50  # Render on top of game elements
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)

	# Pass ship segment counts to HUD
	_hud.set_bar_segments(ship.stats)

	# Wire HUD to player for hardpoint + core display
	_player._hud = _hud
	_player._update_hud_hardpoints()
	_player._update_hud_cores()

	# Store base speed for nebula slow effect restoration
	_player_base_speed = _player.speed
	_player_base_modulate_a = _player.modulate.a

	# Pre-register presence loops for all enemy types used in this level (start muted)
	_register_presence_loops()

	# Start immediately
	LoopMixer.start_all()
	_start_waves()


func _process(delta: float) -> void:
	if _parallax_bg:
		_parallax_bg.scroll_offset.y += _scroll_speed * delta
	_scroll_distance += _scroll_speed * delta
	if _nebula_container:
		_nebula_container.position.y = _scroll_distance
	if _wave_manager:
		_wave_manager.advance_scroll(_scroll_distance)
	# Apply nebula status effects each frame
	_apply_nebula_bar_effects(delta)
	if _hud and _player:
		_hud.update_all_bars(_player.shield, _player.shield_max, _player.hull, _player.hull_max, _player.thermal, _player.thermal_max, _player.electric, _player.electric_max)
		_hud.update_bar_pulses(delta)
		_hud.update_credits(GameState.credits)


func _start_waves() -> void:
	if _level_data:
		_scroll_distance = 0.0
		_wave_manager.setup_level(_level_data, _enemies, _player, _projectiles)
	else:
		var waves: Array = []
		for w in WAVE_CONFIG:
			waves.append(w)
		_wave_manager.setup(waves, _enemies, _player, _projectiles)
		_wave_manager.start()


func _on_all_waves_cleared() -> void:
	# Restart waves continuously
	_start_waves()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_return_to_menu()


func _register_presence_loops() -> void:
	## Scan all enemy ship IDs used in encounters and add their presence loops to LoopMixer (muted).
	var seen_ids: Dictionary = {}
	if _level_data:
		for enc in _level_data.encounters:
			var sid: String = str(enc.get("ship_id", ""))
			if sid != "" and not seen_ids.has(sid):
				seen_ids[sid] = true
	for sid in seen_ids:
		var ship: ShipData = ShipDataManager.load_by_id(sid)
		if ship and ship.presence_loop_path != "":
			var loop_id: String = "presence_" + sid
			_presence_loops[sid] = ship.presence_loop_path
			_presence_counts[sid] = 0
			if not LoopMixer.has_loop(loop_id):
				LoopMixer.add_loop(loop_id, ship.presence_loop_path, "Master", 0.0, true)


func _on_presence_pre_trigger(sid: String, loop_path: String) -> void:
	## Pre-fade: unmute the loop early without incrementing the ref count.
	## The actual ref count is managed by register/unregister when enemies spawn/die.
	if sid == "" or loop_path == "":
		return
	var loop_id: String = "presence_" + sid
	# Lazily register if not pre-registered
	if not _presence_loops.has(sid):
		_presence_loops[sid] = loop_path
		_presence_counts[sid] = 0
		if not LoopMixer.has_loop(loop_id):
			LoopMixer.add_loop(loop_id, loop_path, "Master", 0.0, true)
			if LoopMixer.is_playing():
				LoopMixer.start_all()
	# Only unmute if no enemies of this type are alive yet
	if int(_presence_counts.get(sid, 0)) == 0:
		LoopMixer.unmute(loop_id, 2000)


func register_enemy_presence(sid: String, loop_path: String) -> void:
	## Called when an enemy enters the scene. Increments count, unmutes on 0->1.
	if sid == "" or loop_path == "":
		return
	var loop_id: String = "presence_" + sid
	# Lazily register if not pre-registered (e.g. fallback wave spawns)
	if not _presence_loops.has(sid):
		_presence_loops[sid] = loop_path
		_presence_counts[sid] = 0
		if not LoopMixer.has_loop(loop_id):
			LoopMixer.add_loop(loop_id, loop_path, "Master", 0.0, true)
			if LoopMixer.is_playing():
				LoopMixer.start_all()

	var count: int = int(_presence_counts.get(sid, 0))
	count += 1
	_presence_counts[sid] = count
	if count == 1:
		LoopMixer.unmute(loop_id, 2000)


func unregister_enemy_presence(sid: String) -> void:
	## Called when an enemy exits the scene. Decrements count, mutes on 1->0.
	if sid == "" or not _presence_counts.has(sid):
		return
	var loop_id: String = "presence_" + sid
	var count: int = int(_presence_counts.get(sid, 0))
	count = maxi(count - 1, 0)
	_presence_counts[sid] = count
	if count == 0:
		LoopMixer.mute(loop_id, 2000)


func _on_nebula_entered(_area: Area2D, ndata: NebulaData) -> void:
	if ndata not in _active_nebula_effects:
		_active_nebula_effects.append(ndata)
		_apply_special_effects()


func _on_nebula_exited(_area: Area2D, ndata: NebulaData) -> void:
	_active_nebula_effects.erase(ndata)
	_apply_special_effects()


func _apply_nebula_bar_effects(delta: float) -> void:
	## Apply bar drain/fill from all overlapping nebulas each frame.
	if _active_nebula_effects.is_empty() or not _player:
		return
	var combined_rates: Dictionary = {}
	for ndata in _active_nebula_effects:
		for bar_name in ndata.bar_effects:
			var rate: float = float(ndata.bar_effects[bar_name])
			if combined_rates.has(bar_name):
				combined_rates[bar_name] = float(combined_rates[bar_name]) + rate
			else:
				combined_rates[bar_name] = rate
	for bar_name in combined_rates:
		var rate: float = float(combined_rates[bar_name])
		var amount: float = rate * delta
		if not _nebula_bar_accumulators.has(bar_name):
			_nebula_bar_accumulators[bar_name] = 0.0
		_nebula_bar_accumulators[bar_name] = float(_nebula_bar_accumulators[bar_name]) + amount
		var accumulated: float = float(_nebula_bar_accumulators[bar_name])
		if absf(accumulated) >= 0.01:
			_player.apply_bar_effects({bar_name: accumulated})
			_nebula_bar_accumulators[bar_name] = 0.0


func _apply_special_effects() -> void:
	## Apply or remove special effects based on currently overlapping nebulas.
	if not _player:
		return
	var active_specials: Array[String] = []
	for ndata in _active_nebula_effects:
		for effect_id in ndata.special_effects:
			if effect_id not in active_specials:
				active_specials.append(effect_id)
	# Cloak: reduce player opacity
	if "cloak" in active_specials:
		_player.modulate.a = 0.3
	else:
		_player.modulate.a = _player_base_modulate_a
	# Slow: reduce player speed
	if "slow" in active_specials:
		_player.speed = _player_base_speed * 0.5
	else:
		_player.speed = _player_base_speed
	# Damage boost: set meta flag
	if _player.has_meta("nebula_damage_boost"):
		_player.remove_meta("nebula_damage_boost")
	if "damage_boost" in active_specials:
		_player.set_meta("nebula_damage_boost", true)


func _return_to_menu() -> void:
	LoopMixer.remove_all_loops()
	if _wave_manager:
		_wave_manager.stop()
	if _player:
		_player.stop_all()
	var dest: String = GameState.return_scene
	GameState.return_scene = ""
	if dest != "":
		get_tree().change_scene_to_file(dest)
	else:
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")



func _setup_parallax() -> void:
	var grid_bg := ColorRect.new()
	grid_bg.size = Vector2(1920, 1080)
	grid_bg.z_index = -10
	ThemeManager.apply_grid_background(grid_bg)
	add_child(grid_bg)

	_parallax_bg = ParallaxBackground.new()
	_parallax_bg.name = "ParallaxBG"
	add_child(_parallax_bg)
	_add_star_layer(0.3, 80, Color(0.3, 0.3, 0.5, 0.5), 1)
	_add_star_layer(0.7, 50, Color(0.5, 0.5, 0.8, 0.7), 2)


func _add_star_layer(motion_scale: float, star_count: int, color: Color, seed_val: int) -> void:
	var layer := ParallaxLayer.new()
	layer.motion_scale = Vector2(0, motion_scale)
	layer.motion_mirroring = Vector2(0, 1200)
	_parallax_bg.add_child(layer)

	var stars := _StarField.new()
	stars.star_count = star_count
	stars.star_color = color
	stars.star_seed = seed_val
	stars.size = Vector2(1920, 1200)
	layer.add_child(stars)


func _setup_nebulas() -> void:
	if not _level_data:
		return
	if _level_data.nebula_placements.size() == 0:
		return

	_nebula_container = Node2D.new()
	_nebula_container.name = "Nebulas"
	_nebula_container.z_index = -5  # Behind gameplay, above stars
	add_child(_nebula_container)

	for placement in _level_data.nebula_placements:
		var nebula_id: String = str(placement.get("nebula_id", ""))
		var trigger_y: float = float(placement.get("trigger_y", 0.0))
		var x_offset: float = float(placement.get("x_offset", 0.0))
		var radius: float = float(placement.get("radius", 300.0))

		var ndata: NebulaData = NebulaDataManager.load_by_id(nebula_id)
		if not ndata:
			continue

		var style_info: Dictionary = NEBULA_STYLES.get(ndata.style_id, {})
		var shader_path: String = style_info.get("shader", "") as String
		if shader_path == "":
			continue
		var shader_res: Shader = load(shader_path) as Shader
		if not shader_res:
			continue

		# Build shader material from nebula params
		var mat := ShaderMaterial.new()
		mat.shader = shader_res
		var params: Dictionary = ndata.shader_params
		var defaults: Dictionary = NebulaData.default_params()

		var color_arr: Array = params.get("nebula_color", defaults["nebula_color"]) as Array
		if color_arr.size() >= 4:
			mat.set_shader_parameter("nebula_color", Color(float(color_arr[0]), float(color_arr[1]), float(color_arr[2]), float(color_arr[3])))

		if style_info.get("dual", false):
			var color2_arr: Array = params.get("secondary_color", defaults["secondary_color"]) as Array
			if color2_arr.size() >= 4:
				mat.set_shader_parameter("secondary_color", Color(float(color2_arr[0]), float(color2_arr[1]), float(color2_arr[2]), float(color2_arr[3])))

		mat.set_shader_parameter("brightness", float(params.get("brightness", defaults["brightness"])))
		mat.set_shader_parameter("animation_speed", float(params.get("animation_speed", defaults["animation_speed"])))
		mat.set_shader_parameter("density", float(params.get("density", defaults["density"])))
		mat.set_shader_parameter("seed_offset", float(params.get("seed_offset", defaults["seed_offset"])))
		mat.set_shader_parameter("radial_spread", float(params.get("radial_spread", defaults["radial_spread"])))

		# Create sprite with white texture for shader to render on
		var sprite := Sprite2D.new()
		var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		sprite.texture = ImageTexture.create_from_image(img)
		sprite.material = mat

		# Scale sprite to desired radius (texture is 2x2, scale = radius to get diameter)
		sprite.scale = Vector2(radius, radius)

		# Position: x from screen center, y negative (scrolls into view)
		sprite.position = Vector2(960.0 + x_offset, -trigger_y + 540.0)

		# Apply bottom layer opacity from nebula params
		var bottom_opacity: float = float(params.get("bottom_opacity", defaults["bottom_opacity"]))
		sprite.modulate.a = bottom_opacity
		_nebula_container.add_child(sprite)

		# Top veil layer — same visual, reduced opacity, renders above ships
		var top_opacity: float = float(params.get("top_opacity", defaults["top_opacity"]))
		if top_opacity > 0.0:
			var top_sprite := Sprite2D.new()
			top_sprite.texture = sprite.texture
			top_sprite.material = mat
			top_sprite.scale = sprite.scale
			top_sprite.position = sprite.position
			top_sprite.z_index = 10  # Relative to container at -5, so effective z = +5
			top_sprite.modulate.a = top_opacity
			_nebula_container.add_child(top_sprite)

		# Debug hitbox outline — shrink to where nebula is ~50% visible
		var spread: float = float(params.get("radial_spread", defaults["radial_spread"]))
		var effective_radius: float = radius * (1.0 - spread / 2.0)
		var debug_ring := _NebulaDebugRing.new()
		debug_ring.radius = effective_radius
		debug_ring.position = sprite.position
		debug_ring.z_index = 15
		_nebula_container.add_child(debug_ring)

		# Collision area for status effects (if nebula has any effects defined)
		if ndata.bar_effects.size() > 0 or ndata.special_effects.size() > 0:
			var area := Area2D.new()
			area.collision_layer = 0
			area.collision_mask = 1  # Detects player (layer 1)
			area.position = sprite.position
			var col_shape := CollisionShape2D.new()
			var circle := CircleShape2D.new()
			circle.radius = effective_radius
			col_shape.shape = circle
			area.add_child(col_shape)
			_nebula_container.add_child(area)
			_nebula_areas.append({"area": area, "nebula_data": ndata})
			area.area_entered.connect(_on_nebula_entered.bind(ndata))
			area.area_exited.connect(_on_nebula_exited.bind(ndata))


class _NebulaDebugRing extends Node2D:
	var radius: float = 300.0

	func _draw() -> void:
		var segments: int = maxi(int(radius * 0.3), 48)
		var pts := PackedVector2Array()
		for i in range(segments + 1):
			var angle: float = TAU * float(i) / float(segments)
			pts.append(Vector2(cos(angle), sin(angle)) * radius)
		draw_polyline(pts, Color(1.0, 1.0, 0.0, 0.7), 2.0, true)


class _StarField extends Control:
	var star_count: int = 60
	var star_color: Color = Color(0.5, 0.5, 0.8, 0.6)
	var star_seed: int = 1
	var _positions: PackedVector2Array = PackedVector2Array()
	var _sizes: PackedFloat32Array = PackedFloat32Array()

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = star_seed
		for i in star_count:
			_positions.append(Vector2(rng.randf() * 1920.0, rng.randf() * 1200.0))
			_sizes.append(rng.randf_range(1.0, 2.5))

	func _draw() -> void:
		for i in _positions.size():
			draw_circle(_positions[i], _sizes[i], star_color)
