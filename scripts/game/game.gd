extends Node2D
## Game orchestrator — loads ship + weapons from ShipRegistry + GameState slot_config.

const WAVE_CONFIG: Array[Dictionary] = [
	{"count": 6, "health": 30, "speed_min": 80.0, "speed_max": 140.0, "spawn_interval": 1.2, "delay_after": 3.0},
	{"count": 6, "health": 30, "speed_min": 80.0, "speed_max": 140.0, "spawn_interval": 1.2, "delay_after": 3.0},
	{"count": 6, "health": 30, "speed_min": 80.0, "speed_max": 140.0, "spawn_interval": 1.2, "delay_after": 3.0},
]

var _player: Node2D = null
var _wave_manager: WaveManager = null
var _hud: CanvasLayer = null
var _projectiles: Node2D = null
var _enemies: Node2D = null
var _parallax_bg: ParallaxBackground = null
var _level_data: LevelData = null
var _scroll_distance: float = 0.0
var _scroll_speed: float = 80.0

## Set this before adding to the scene tree to use a specific level.
var level_id: String = ""


func _ready() -> void:
	_setup_world_environment()

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

	# Set BPM (from level or default)
	var bpm: float = _level_data.bpm if _level_data else 110.0
	BeatClock.bpm = bpm
	if _level_data:
		_scroll_speed = _level_data.scroll_speed

	# Build scene tree
	_setup_parallax()

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

	# HUD
	_hud = CanvasLayer.new()
	_hud.set_script(load("res://scripts/game/hud.gd"))
	_hud.name = "HUD"
	add_child(_hud)

	# Pass ship segment counts to HUD
	_hud.set_bar_segments(ship.stats)

	# Wire HUD to player for hardpoint + core display
	_player._hud = _hud
	_player._update_hud_hardpoints()
	_player._update_hud_cores()

	# Start immediately
	BeatClock.start(bpm)
	LoopMixer.start_all()
	_start_waves()


func _process(delta: float) -> void:
	if _parallax_bg:
		_parallax_bg.scroll_offset.y += _scroll_speed * delta
	_scroll_distance += _scroll_speed * delta
	if _wave_manager:
		_wave_manager.advance_scroll(_scroll_distance)
	if _hud and _player:
		_hud.update_all_bars(_player.shield, _player.shield_max, _player.hull, _player.hull_max, _player.thermal, _player.thermal_max, _player.electric, _player.electric_max)
		_hud.update_bar_pulses(delta)
		_hud.update_credits(GameState.credits)


func _start_waves() -> void:
	if _level_data:
		_scroll_distance = 0.0
		_wave_manager.setup_level(_level_data, _enemies, _player)
	else:
		var waves: Array = []
		for w in WAVE_CONFIG:
			waves.append(w)
		_wave_manager.setup(waves, _enemies)
		_wave_manager.start()


func _on_all_waves_cleared() -> void:
	# Restart waves continuously
	_start_waves()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_return_to_menu()


func _return_to_menu() -> void:
	BeatClock.stop()
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


func _setup_world_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 0.8
	env.set_glow_level(0, true)
	env.set_glow_level(1, true)
	env.set_glow_level(2, true)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	world_env.environment = env
	add_child(world_env)


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
