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
var _doodad_container: Node2D = null
var _bg_shader_mat: ShaderMaterial = null  # reference for setting scroll_offset on static shaders
var _game_viewport: SubViewport = null
var _game_viewport_container: SubViewportContainer = null
var _shared_renderer: EnemySharedRenderer = null
var _mouse_nav_indicator: Node2D = null
var _level_data: LevelData = null
var _scroll_distance: float = 0.0
var _scroll_speed: float = 80.0

# Debug parallax grids (F3 toggle)
var _deep_debug_grid: Node2D = null
var _bg_debug_grid: Node2D = null
var _debug_grids_visible: bool = false
# Nebula status effects
var _nebula_areas: Array = []  # Array of {area: Area2D, nebula_data: NebulaData}
var _active_nebula_counts: Dictionary = {}  # nebula_id -> int (ref count of overlapping zones)
var _active_nebula_data: Dictionary = {}    # nebula_id -> NebulaData (representative instance)
var _nebula_bar_accumulators: Dictionary = {}  # bar_name -> float accumulator for sub-frame amounts
var _player_base_speed: float = 400.0
var _player_base_modulate_a: float = 1.0
var _current_key_shift: int = 0
var _pending_key_shift: int = 0
var _active_fade_duration: float = 0.15
var _prev_loop_pos: float = -1.0  # For bar-boundary detection
var _key_change_presets: Dictionary = {}  # nebula_id -> KeyChangeData
var _reversed_stream_cache: Dictionary = {}  # sfx_path -> AudioStreamWAV (reversed)

# Death sequence
var _death_sequence_active: bool = false
var _death_timer: float = 0.0
var _death_explosion_accum: float = 0.0
var _death_player_pos: Vector2 = Vector2.ZERO  # Snapshot of player position at death
var _game_over_overlay: Control = null
const DEATH_EXPLOSION_DURATION: float = 3.0

# Death during power loss — dramatic bulkhead collapse
var _power_death_active: bool = false
var _power_death_timer: float = 0.0
var _power_death_explosion_accum: float = 0.0
const POWER_DEATH_DURATION: float = 2.5

# Boss transition sequence
var _boss_transition_active: bool = false
var _boss_transition_timer: float = 0.0
var _boss_transition_event: Dictionary = {}
var _boss_transition_overlay: Control = null
var _boss_transition_warning_box: Control = null
var _boss_transition_lead_loops: Array[String] = []  # Loop IDs registered for audio lead
var _boss_health_bar: BossHealthBar = null
var _boss_enemies: Array = []  # All boss enemy nodes (core + segments) for health tracking
# Typing system (reboot-style RichTextLabel)
var _bt_typing_label: RichTextLabel = null
var _bt_typing_lines: Array[String] = []
var _bt_typing_line_idx: int = 0
var _bt_typing_char_idx: int = 0
var _bt_typing_char_timer: float = 0.0
var _bt_typing_pause_timer: float = 0.0  # Inter-line pause countdown
var _bt_typing_completed_lines: Array[String] = []
var _bt_typing_fast: bool = false
var _bt_typing_player: AudioStreamPlayer = null
var _bt_typing_active: bool = false
var _bt_typing_finished: bool = false
# Music degradation
var _bt_degrade_active: bool = false
var _bt_remodulated: bool = false
var _bt_debug_y_offset: float = 0.0  # Stacks debug labels vertically

# Screen shake (general purpose — reusable for any damage event)
var _screen_shake_remaining: float = 0.0
var _screen_shake_amplitude: float = 0.0
var _screen_shake_original_pos: Vector2 = Vector2.ZERO

# Game events system (visual + SFX events triggered by nebulas, bosses, etc.)
var _static_overlay: ColorRect = null
var _static_shader_mat: ShaderMaterial = null
var _lightning_overlay: ColorRect = null
var _game_event_cache: Dictionary = {}  # event_id -> GameEventData
var _nebula_event_timers: Dictionary = {}  # nebula_id -> float (countdown to next event)
var _events_audition_mode: bool = false  # When true: empty level, hotkeys trigger events
var _events_audition_ids: Array[String] = []  # Loaded event IDs for hotkey mapping
var _events_audition_legend: Control = null
var _tutorial_controller: TutorialController = null
var _active_lightning_count: int = 0
var _active_lightning_timer: float = 0.0
var _active_lightning_interval: float = 0.0
var _active_lightning_color: Color = Color.WHITE
var _active_lightning_intensity: float = 1.0

# Level intro sequence
var _intro_active: bool = false
var _intro_timer: float = 0.0
var _intro_measure_dur: float = 2.18  # seconds per measure, calculated from BPM
var _intro_phase: int = 0  # 0=level number, 1=level name + bar fill, 2=done
var _intro_title_box: Control = null
const INTRO_LOOP_PATH: String = "res://assets/audio/atmosphere/intro_loop.wav"
const INTRO_FADE_START: float = 0.5  # seconds before measure boundary to start text fade

# Warning rotator state
var _hull_damaged_timer: float = 0.0  # Transient "HULL DAMAGED" display timer
const HULL_DAMAGED_DISPLAY_TIME: float = 2.0

# Warning alarm audio — looping players keyed by warning ID
var _alarm_players: Dictionary = {}  # warning_id -> AudioStreamPlayer
var _active_alarm_ids: Array[String] = []  # Warning IDs currently active (last frame)

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
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	_load_warning_colors()
	GameState.reset_level_stats()
	GameState.fade_out_menu_music()
	# Force fresh SFX cache on every game start
	SfxPlayer.reload()
	# Reassign key bindings to sequential 1-2-3... based on current ship's slot counts
	KeyBindingManager.reassign_sequential_keys()
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

	# Game content renders in its own SubViewport with HDR + ACES + bloom —
	# the exact same pipeline that component tab previews use.
	var svc := SubViewportContainer.new()
	_game_viewport_container = svc
	svc.name = "GameViewportContainer"
	svc.position = Vector2.ZERO
	svc.size = Vector2(1920, 1080)
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)

	_game_viewport = SubViewport.new()
	_game_viewport.name = "GameViewport"
	_game_viewport.size = Vector2i(1920, 1080)
	_game_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_game_viewport.transparent_bg = false
	svc.add_child(_game_viewport)
	VFXFactory.add_bloom_to_viewport(_game_viewport)

	# Build scene tree inside the game viewport
	_setup_parallax()
	_setup_nebulas()
	_setup_debug_grids()

	_projectiles = Node2D.new()
	_projectiles.name = "Projectiles"
	_game_viewport.add_child(_projectiles)

	_enemies = Node2D.new()
	_enemies.name = "Enemies"
	_game_viewport.add_child(_enemies)

	# Shared enemy renderers — one live ShipRenderer per unique enemy type,
	# all instances share the viewport texture instead of running their own _draw()
	# Lives on root (not inside game SubViewport) to avoid nested viewport overhead
	_shared_renderer = EnemySharedRenderer.new()
	_shared_renderer.name = "EnemySharedRenderer"
	add_child(_shared_renderer)
	if _level_data:
		var appearances: Array = _collect_enemy_appearances(_level_data)
		_shared_renderer.register_appearances(appearances, _shared_renderer)

	# Player
	_player = Node2D.new()
	_player.set_script(load("res://scripts/game/player_ship.gd"))
	_player.name = "PlayerShip"
	_game_viewport.add_child(_player)
	_player.setup(ship, loadout, _projectiles)
	_player.position = Vector2(960, 850)
	_player.died.connect(_on_player_died)
	_player.died_during_power_loss.connect(_on_player_died_during_power_loss)
	_player.hull_hit_during_power_loss.connect(func(): trigger_screen_shake(4.0, 0.2))
	_player.hull_hit.connect(func(): _hull_damaged_timer = HULL_DAMAGED_DISPLAY_TIME)
	_player.power_loss_started.connect(_on_power_loss_started)
	_player.power_loss_ended.connect(_on_power_loss_ended)

	# Mouse navigation indicator
	_mouse_nav_indicator = _MouseNavIndicator.new()
	_mouse_nav_indicator.z_index = 45  # Above game elements, below HUD
	_game_viewport.add_child(_mouse_nav_indicator)

	# Wave manager
	_wave_manager = WaveManager.new()
	_wave_manager.name = "WaveManager"
	_game_viewport.add_child(_wave_manager)
	_wave_manager.all_waves_cleared.connect(_on_all_waves_cleared)
	_wave_manager.boss_transition_triggered.connect(_on_boss_transition)


	# HUD stays on root viewport — LED bars must NOT go through ACES tonemapping
	# or their led_glow HDR rects get boosted and bloom blows out. Root bloom
	# processes them with LINEAR tonemap, matching hangar bar appearance.
	_hud = Control.new()
	_hud.set_script(load("res://scripts/game/hud.gd"))
	_hud.name = "HUD"
	_hud.size = Vector2(1920, 1080)
	_hud.z_index = 50  # Render on top of game elements
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)

	# Pass ship segment counts to HUD
	_hud.set_bar_segments(ship.stats)
	_hud.register_chrome_materials()

	# Wire HUD to player for hardpoint + core display
	_player._hud = _hud
	_player._update_hud_hardpoints()
	_player._update_hud_cores()
	_player._update_hud_devices()

	# Store base speed for nebula slow effect restoration
	_player_base_speed = _player.speed
	_player_base_modulate_a = _player.modulate.a

	# Game event overlays — siblings to game viewport, rendered on top
	_setup_game_event_overlays()

	# Check for events audition mode
	if GameState.has_meta("events_audition"):
		GameState.remove_meta("events_audition")
		_events_audition_mode = true
		_setup_events_audition()
	elif _level_data and _level_data.id == "tutorial":
		_tutorial_controller = TutorialController.new()
		add_child(_tutorial_controller)
		_tutorial_controller.setup(_player, _hud, self)
	else:
		# Waves start immediately (scroll-based spawning)
		_start_waves()

	# Level intro — titles + bar fill overlay, 1.5s silence then all loops start in sync
	if not _events_audition_mode:
		_start_intro()

	# Delay all loop playback by 1.5s so intro loop and weapon loops start from beat 1 together
	get_tree().create_timer(1.5).timeout.connect(func(): LoopMixer.start_all())


# ── Level intro sequence ──────────────────────────────────────────────

func _start_intro() -> void:
	var bpm: float = _level_data.bpm if _level_data else 110.0
	_intro_measure_dur = 60.0 / maxf(bpm, 1.0) * 4.0  # 4/4 time
	_intro_active = true
	_intro_timer = -1.5  # 1.5 second delay before first hit
	_intro_phase = 0

	# Bars start in natural state — no charge-up animation

	# Extract level number and name from display_name (e.g. "01 - Welcome Void")
	var level_num: String = "LEVEL 1"
	var level_name: String = ""
	if _level_data:
		var dn: String = _level_data.display_name
		var dash_pos: int = dn.find(" - ")
		if dash_pos >= 0:
			level_num = "LEVEL " + dn.substr(0, dash_pos).strip_edges()
			level_name = dn.substr(dash_pos + 3).strip_edges()
		else:
			level_num = "LEVEL"
			level_name = dn

	# Create title box (holographic style)
	_intro_title_box = _IntroTitleBox.new()
	_intro_title_box.level_number_text = level_num
	_intro_title_box.level_name_text = level_name
	_intro_title_box.measure_duration = _intro_measure_dur
	_intro_title_box.fade_lead_time = INTRO_FADE_START
	var box_w: float = 400.0
	var box_h: float = 80.0
	_intro_title_box.box_size = Vector2(box_w, box_h)
	_intro_title_box.position = Vector2((1920 - box_w) * 0.5, 440)
	_intro_title_box.size = Vector2(box_w, box_h)
	_intro_title_box.z_index = 55
	_intro_title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_intro_title_box)

	# Add intro loop to LoopMixer — starts with start_all() after 1.5s delay, in sync with weapons
	if INTRO_LOOP_PATH != "" and FileAccess.file_exists(INTRO_LOOP_PATH):
		LoopMixer.add_loop("__intro_loop", INTRO_LOOP_PATH, "Atmosphere", 0.0, false)


func _process_intro(delta: float) -> void:
	var prev_time: float = _intro_timer
	_intro_timer += delta


	# Hit 1 = time 0 (level number). Hit 2 = 2 measures in (level name + bar fill).
	# Total intro = 4 measures.
	var hit2_time: float = _intro_measure_dur * 2.0
	var end_time: float = _intro_measure_dur * 4.0

	# Phase 0: showing level number (measures 1-2)
	if _intro_phase == 0 and _intro_timer >= hit2_time:
		_intro_phase = 1
		# Fade out intro loop when second title appears
		var fade_ms: int = int(_intro_measure_dur * 4.0 * 1000.0)
		LoopMixer.mute("__intro_loop", fade_ms)
		# Remove after fade completes
		get_tree().create_timer(_intro_measure_dur * 4.0 + 0.5).timeout.connect(func():
			LoopMixer.remove_loop("__intro_loop")
		)

	# Phase 1: showing level name (measures 3-4), end intro when done
	if _intro_phase == 1:
		if _intro_timer >= end_time:
			_end_intro()

	# Update title box timing
	if _intro_title_box:
		_intro_title_box.intro_time = _intro_timer


func _end_intro() -> void:
	_intro_active = false
	_intro_phase = 2

	# Bars already in natural state — no intro bars to stop

	# Remove title box
	if _intro_title_box:
		_intro_title_box.queue_free()
		_intro_title_box = null

	# Intro loop fade already started at phase 1 transition — nothing to do here


# ── Main game loop ───────────────────────────────────────────────────

func _process(delta: float) -> void:
	# Intro sequence — runs alongside scrolling/parallax but blocks waves/combat
	if _intro_active:
		_process_intro(delta)

	if not _end_of_level_active:
		GameState.level_stats["time_elapsed"] = float(GameState.level_stats.get("time_elapsed", 0.0)) + delta
	if _end_of_level_active:
		_process_end_of_level(delta)
	if _tutorial_controller:
		_tutorial_controller.process(delta)
	if _parallax_bg:
		_parallax_bg.scroll_offset.y += _scroll_speed * delta
	_scroll_distance += _scroll_speed * delta
	if _doodad_container:
		_doodad_container.position.y = _scroll_distance
	if _bg_shader_mat:
		_bg_shader_mat.set_shader_parameter("scroll_offset", _scroll_distance)
	if _nebula_container:
		_nebula_container.position.y = _scroll_distance
	if _bg_debug_grid and _bg_debug_grid.visible:
		_bg_debug_grid.position.y = fmod(_scroll_distance, _bg_debug_grid.line_spacing)
	if _wave_manager and not _death_sequence_active:
		_wave_manager.advance_scroll(_scroll_distance)
	# Apply nebula status effects each frame
	if not _death_sequence_active:
		_apply_nebula_bar_effects(delta)
		_process_nebula_events(delta)
		_check_measure_boundary_key_shift()
	_process_lightning_chain(delta)
	# Death explosion sequence
	if _death_sequence_active:
		_process_death_sequence(delta)
	if _power_death_active:
		_process_power_loss_death(delta)
	if _boss_transition_active:
		_process_boss_transition(delta)
	_update_boss_health_bar()
	_process_screen_shake(delta)
	if _hud and _player and not _game_over_overlay and not _power_death_active:
		_hud.update_all_bars(_player.shield, _player.shield_max, _player.hull, _player.hull_max, _player.thermal, _player.thermal_max, _player.electric, _player.electric_max)
		_hud.update_bar_pulses(delta)
		_hud.process_power_death_bars(delta)
		_hud.process_shield_arcs(delta)
		_hud.process_fire_effect(delta)
		_hud.update_credits(GameState.credits)
		if not _player._drifting and not _player._blackout_active:
			_update_warning_rotator(delta)
	# Mouse navigation indicator
	if _mouse_nav_indicator:
		var kbd_active: bool = Input.get_vector("move_left", "move_right", "move_up", "move_down").length_squared() > 0.0
		var show: bool = GameState.show_mouse_nav_indicator and not kbd_active
		_mouse_nav_indicator.visible = show
		if show:
			_mouse_nav_indicator.position = _game_viewport.get_mouse_position()


func _collect_enemy_appearances(level: LevelData) -> Array:
	## Scan level encounters to find unique (visual_id, render_mode, color) combos.
	## Also scans boss encounters for all boss part appearances.
	var seen: Dictionary = {}
	var result: Array = []
	for enc in level.encounters:
		var enc_dict: Dictionary = enc as Dictionary
		# Boss encounter — register all parts
		var boss_id: String = str(enc_dict.get("boss_id", ""))
		if boss_id != "":
			var boss: BossData = BossDataManager.load_by_id(boss_id)
			if boss:
				_register_ship_appearance(boss.core_ship_id, seen, result)
				for seg in boss.segments:
					var sd: Dictionary = seg as Dictionary
					var seg_sid: String = str(sd.get("ship_id", ""))
					if seg_sid != "":
						_register_ship_appearance(seg_sid, seen, result)
			continue
		var sid: String = str(enc_dict.get("ship_id", ""))
		if sid != "":
			_register_ship_appearance(sid, seen, result)
	return result


func _register_ship_appearance(sid: String, seen: Dictionary, result: Array) -> void:
	var ship: ShipData = ShipDataManager.load_by_id(sid)
	if not ship:
		return
	var vid: String = ship.visual_id if ship.visual_id != "" else "sentinel"
	var rmode: String = ship.render_mode if ship.render_mode != "" else "neon"
	var color: Color = WaveManager.ENEMY_COLORS[sid.hash() % WaveManager.ENEMY_COLORS.size()]
	var key: String = "%s|%s|%s" % [vid, rmode, color.to_html()]
	if seen.has(key):
		return
	seen[key] = true
	result.append({"visual_id": vid, "render_mode": rmode, "color": color})


func _start_waves() -> void:
	_wave_manager.shared_renderer = _shared_renderer
	if _level_data:
		_scroll_distance = 0.0
		_wave_manager.setup_level(_level_data, _enemies, _player, _projectiles)
	else:
		var waves: Array = []
		for w in WAVE_CONFIG:
			waves.append(w)
		_wave_manager.setup(waves, _enemies, _player, _projectiles)
		_wave_manager.start()


var _end_of_level_active: bool = false
var _end_of_level_overlay: Control = null
var _end_of_level_typing_lines: Array[String] = []
var _end_of_level_typing_idx: int = 0
var _end_of_level_char_idx: int = 0
var _end_of_level_char_timer: float = 0.0
var _end_of_level_pause_timer: float = 0.0
var _end_of_level_completed_lines: Array[String] = []
var _end_of_level_label: RichTextLabel = null
var _end_of_level_prompt_visible: bool = false
var _end_of_level_time: float = 0.0


func _on_all_waves_cleared() -> void:
	if _events_audition_mode:
		return  # Don't end level in audition mode
	_start_end_of_level()


func _input(event: InputEvent) -> void:
	# Activate mouse control on the player ship after first real mouse movement
	if _player and not _player._mouse_activated and event is InputEventMouseMotion:
		_player._mouse_activated = true
	# Forward mouse button events into the game SubViewport — the container uses
	# MOUSE_FILTER_IGNORE so mouse clicks don't reach the player ship otherwise.
	if event is InputEventMouseButton and _game_viewport:
		_game_viewport.push_input(event)
	if _game_over_overlay and event.is_pressed() and not event.is_echo():
		_return_to_menu()
		return
	if _end_of_level_prompt_visible and event.is_pressed() and not event.is_echo():
		_return_to_menu()
		return
	if _death_sequence_active:
		return  # Block all input during explosion sequence
	if event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_F3:
		_debug_grids_visible = not _debug_grids_visible
		if _deep_debug_grid:
			_deep_debug_grid.visible = _debug_grids_visible
		if _bg_debug_grid:
			_bg_debug_grid.visible = _debug_grids_visible
		return
	if _events_audition_mode and event is InputEventKey and event.pressed and not event.is_echo():
		var key: int = (event as InputEventKey).keycode
		var idx: int = -1
		if key >= KEY_1 and key <= KEY_9:
			idx = key - KEY_1
		if idx >= 0 and idx < _events_audition_ids.size():
			trigger_game_event(_events_audition_ids[idx])
			return
	if event.is_action_pressed("ui_cancel"):
		_return_to_menu()


func _setup_events_audition() -> void:
	## Load all game events and build a key legend overlay.
	var all_events: Array[GameEventData] = GameEventDataManager.load_all()
	_events_audition_ids.clear()
	for ev in all_events:
		_events_audition_ids.append(ev.id)

	# Build legend overlay (top-right)
	_events_audition_legend = VBoxContainer.new()
	_events_audition_legend.position = Vector2(1400, 80)
	_events_audition_legend.z_index = 60
	_events_audition_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_events_audition_legend)

	var header := Label.new()
	header.text = "EVENTS AUDITION"
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_events_audition_legend.add_child(header)

	for i in range(mini(_events_audition_ids.size(), 9)):
		var ev: GameEventData = all_events[i]
		var lbl := Label.new()
		lbl.text = "[%d] %s" % [i + 1, ev.display_name]
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_events_audition_legend.add_child(lbl)

	var esc_lbl := Label.new()
	esc_lbl.text = "[ESC] Return"
	esc_lbl.add_theme_font_size_override("font_size", 14)
	esc_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	esc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_events_audition_legend.add_child(esc_lbl)


func _on_nebula_entered(_area: Area2D, ndata: NebulaData) -> void:
	var nid: String = ndata.id
	var count: int = int(_active_nebula_counts.get(nid, 0))
	count += 1
	_active_nebula_counts[nid] = count
	_active_nebula_data[nid] = ndata
	if count > 1:
		return  # Already active — same nebula type entered again, skip
	# First zone of this type — apply effects
	var was_shifted: bool = _current_key_shift != 0
	_apply_special_effects()
	if not was_shifted and _key_change_presets.has(nid):
		var kc: KeyChangeData = _key_change_presets[nid]
		if kc.enter_sfx_path != "" and kc.semitones != 0:
			_schedule_key_change_sfx(kc.enter_sfx_path, kc.enter_sfx_volume_db, kc.enter_sfx_offset, false)


func _on_nebula_exited(_area: Area2D, ndata: NebulaData) -> void:
	var nid: String = ndata.id
	var count: int = int(_active_nebula_counts.get(nid, 0))
	count = maxi(count - 1, 0)
	if count > 0:
		_active_nebula_counts[nid] = count
		return  # Still inside another zone of this type
	# Last zone of this type exited — remove effects
	_active_nebula_counts.erase(nid)
	_active_nebula_data.erase(nid)
	_apply_special_effects()
	if _pending_key_shift == 0 and _current_key_shift != 0:
		if _key_change_presets.has(nid):
			var kc: KeyChangeData = _key_change_presets[nid]
			if kc.exit_sfx_path != "":
				_schedule_key_change_sfx(kc.exit_sfx_path, kc.exit_sfx_volume_db, kc.exit_sfx_offset, kc.reverse_exit_sfx)


func _apply_nebula_bar_effects(delta: float) -> void:
	## Apply bar drain/fill from all active nebula types each frame.
	## Each nebula type contributes once regardless of how many overlapping zones exist.
	if _active_nebula_data.is_empty() or not _player:
		return
	var combined_rates: Dictionary = {}
	for nid in _active_nebula_data:
		var ndata: NebulaData = _active_nebula_data[nid]
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
	## Apply or remove special effects based on active nebula types.
	## Each type contributes once regardless of overlapping zone count.
	if not _player:
		return
	var active_specials: Array[String] = []
	for nid in _active_nebula_data:
		var ndata: NebulaData = _active_nebula_data[nid]
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
	# Key shift: queue pitch change — applied at next measure boundary
	# Each nebula type contributes once (deduped by ID)
	var total_shift: int = 0
	var max_fade: float = 0.15
	for nid in _active_nebula_data:
		if _key_change_presets.has(nid):
			var kc: KeyChangeData = _key_change_presets[nid]
			total_shift += kc.semitones
			max_fade = maxf(max_fade, kc.fade_duration)
	_pending_key_shift = clampi(total_shift, -12, 12)
	_active_fade_duration = max_fade


func _check_measure_boundary_key_shift() -> void:
	## Apply pending key shift only when playback crosses a measure (4-beat) boundary.
	## Uses the first available core or weapon loop for timing reference.
	if _pending_key_shift == _current_key_shift:
		_prev_loop_pos = -1.0
		return
	if not _player:
		return
	# Find a reference loop: any core or weapon controller with a playing loop
	var ref_loop_id: String = ""
	var ref_bars: int = 0
	for c in _player._core_controllers:
		var ctrl: PowerCoreController = c as PowerCoreController
		if ctrl and ctrl.power_core_data and LoopMixer.has_loop(ctrl._loop_id):
			var pos: float = LoopMixer.get_playback_position(ctrl._loop_id)
			if pos >= 0.0:
				ref_loop_id = ctrl._loop_id
				ref_bars = ctrl.power_core_data.loop_length_bars
				break
	if ref_loop_id == "":
		for c in _player._hardpoint_controllers:
			var ctrl: HardpointController = c as HardpointController
			if ctrl and ctrl.weapon_data and ctrl._loop_id != "" and LoopMixer.has_loop(ctrl._loop_id):
				var pos: float = LoopMixer.get_playback_position(ctrl._loop_id)
				if pos >= 0.0:
					ref_loop_id = ctrl._loop_id
					ref_bars = ctrl.weapon_data.loop_length_bars
					break
	if ref_loop_id == "":
		# No reference loop available — apply immediately as fallback
		_current_key_shift = _pending_key_shift
		LoopMixer.set_pitch_shift(float(_current_key_shift), 0.15)
		return
	var pos_sec: float = LoopMixer.get_playback_position(ref_loop_id)
	var duration: float = LoopMixer.get_stream_duration(ref_loop_id)
	if duration <= 0.0 or pos_sec < 0.0:
		return
	var curr_norm: float = pos_sec / duration
	if _prev_loop_pos < 0.0:
		_prev_loop_pos = curr_norm
		return
	# Measure boundaries are at 0.0, 1/bars, 2/bars, ... (each = 4 beats)
	var measure_size: float = 1.0 / float(maxi(ref_bars, 1))
	var crossed: bool = false
	if curr_norm >= _prev_loop_pos:
		# Normal progression — check if any boundary falls in (prev, curr]
		var prev_measure: int = int(_prev_loop_pos / measure_size)
		var curr_measure: int = int(curr_norm / measure_size)
		crossed = curr_measure > prev_measure
	else:
		# Wrap-around (loop restarted) — always a boundary at 0.0
		crossed = true
	_prev_loop_pos = curr_norm
	if crossed:
		_current_key_shift = _pending_key_shift
		LoopMixer.set_pitch_shift(float(_current_key_shift), _active_fade_duration)


func _schedule_key_change_sfx(sfx_path: String, volume_db: float, offset_sec: float, reverse: bool) -> void:
	## Schedule a key change SFX. If offset > 0, plays with a timer so the peak aligns with
	## the measure boundary. Otherwise plays immediately.
	var stream: AudioStream = load(sfx_path) as AudioStream
	if not stream:
		return
	if reverse and stream is AudioStreamWAV:
		if _reversed_stream_cache.has(sfx_path):
			stream = _reversed_stream_cache[sfx_path]
		else:
			var rev: AudioStreamWAV = KeyChangeData.make_reversed_stream(stream as AudioStreamWAV)
			if rev:
				_reversed_stream_cache[sfx_path] = rev
				stream = rev
	if offset_sec > 0.0:
		# Calculate time to next measure boundary and schedule SFX to fire early
		var delay: float = _get_time_to_next_measure() - offset_sec
		if delay > 0.0:
			var captured_stream: AudioStream = stream
			var captured_vol: float = volume_db
			get_tree().create_timer(delay).timeout.connect(func() -> void:
				AudioManager.play_sample(captured_stream, 1.0, captured_vol)
			)
		else:
			AudioManager.play_sample(stream, 1.0, volume_db)
	else:
		AudioManager.play_sample(stream, 1.0, volume_db)


func _get_time_to_next_measure() -> float:
	## Estimate seconds until the next measure (4-beat) boundary from the first available loop.
	if not _player:
		return 0.0
	for c in _player._core_controllers:
		var ctrl: PowerCoreController = c as PowerCoreController
		if ctrl and ctrl.power_core_data and LoopMixer.has_loop(ctrl._loop_id):
			var pos: float = LoopMixer.get_playback_position(ctrl._loop_id)
			var dur: float = LoopMixer.get_stream_duration(ctrl._loop_id)
			if dur > 0.0 and pos >= 0.0:
				var bars: int = maxi(ctrl.power_core_data.loop_length_bars, 1)
				var measure_sec: float = dur / float(bars)
				var pos_in_measure: float = fmod(pos, measure_sec)
				return measure_sec - pos_in_measure
	for c in _player._hardpoint_controllers:
		var ctrl: HardpointController = c as HardpointController
		if ctrl and ctrl.weapon_data and ctrl._loop_id != "" and LoopMixer.has_loop(ctrl._loop_id):
			var pos: float = LoopMixer.get_playback_position(ctrl._loop_id)
			var dur: float = LoopMixer.get_stream_duration(ctrl._loop_id)
			if dur > 0.0 and pos >= 0.0:
				var bars: int = maxi(ctrl.weapon_data.loop_length_bars, 1)
				var measure_sec: float = dur / float(bars)
				var pos_in_measure: float = fmod(pos, measure_sec)
				return measure_sec - pos_in_measure
	return 0.0


func _on_player_died() -> void:
	if _death_sequence_active or _power_death_active:
		return  # Prevent double-trigger
	_stop_all_alarms()
	_death_sequence_active = true
	_death_timer = 0.0
	_death_explosion_accum = 0.0
	_player.disable_for_death()
	if _wave_manager:
		_wave_manager.stop()
	SfxPlayer.play_random_explosion()


func _process_death_sequence(delta: float) -> void:
	if _game_over_overlay:
		return
	_death_timer += delta
	var player_pos: Vector2 = _player.global_position if _player else _death_player_pos
	# Spawn staggered explosions — interval decreases for crescendo effect
	var progress: float = clampf(_death_timer / DEATH_EXPLOSION_DURATION, 0.0, 1.0)
	var spawn_interval: float = lerpf(0.4, 0.12, progress)
	_death_explosion_accum += delta
	while _death_explosion_accum >= spawn_interval:
		_death_explosion_accum -= spawn_interval
		var offset: Vector2 = Vector2(randf_range(-40.0, 40.0), randf_range(-40.0, 40.0))
		var explosion: ExplosionEffect = ExplosionEffect.new()
		explosion.explosion_color = Color(1.0, lerpf(0.6, 0.3, progress), lerpf(0.2, 0.1, progress))
		explosion.explosion_size = lerpf(0.5, 2.0, progress)
		explosion.global_position = player_pos + offset
		_game_viewport.add_child(explosion)
		SfxPlayer.play_random_explosion()
	# Flicker the ship during explosions
	if _player and _player.visible:
		_player.modulate.a = 0.3 + randf() * 0.7
	# After duration: final big explosion, remove ship, show game over
	if _death_timer >= DEATH_EXPLOSION_DURATION:
		var final_explosion: ExplosionEffect = ExplosionEffect.new()
		final_explosion.explosion_color = Color(1.0, 0.4, 0.1)
		final_explosion.explosion_size = 3.5
		final_explosion.enable_screen_shake = true
		final_explosion.global_position = player_pos
		_game_viewport.add_child(final_explosion)
		SfxPlayer.play_random_explosion()
		if _player:
			_player.visible = false
		_show_game_over()


func _show_game_over() -> void:
	_game_over_overlay = Control.new()
	_game_over_overlay.name = "GameOverOverlay"
	_game_over_overlay.size = Vector2(1920, 1080)
	_game_over_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game_over_overlay.z_index = 60  # Above HUD
	add_child(_game_over_overlay)

	# Semi-transparent dark background
	var bg := ColorRect.new()
	bg.size = Vector2(1920, 1080)
	bg.color = Color(0.0, 0.0, 0.0, 0.5)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game_over_overlay.add_child(bg)

	# Holographic warning box — same style as in-game warnings, larger
	var box := _GameOverBox.new()
	var box_w: float = 460.0
	var box_h: float = 100.0
	box.box_size = Vector2(box_w, box_h)
	box.position = Vector2((1920 - box_w) * 0.5, 420)
	box.size = Vector2(box_w, box_h)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game_over_overlay.add_child(box)

	# "press any key to return to hangar" below the box
	var subtitle := Label.new()
	subtitle.text = "press any key to return to hangar"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(0, 550)
	subtitle.size = Vector2(1920, 40)
	var sub_col := Color(0.5, 0.75, 0.95)
	subtitle.add_theme_color_override("font_color", sub_col)
	subtitle.add_theme_font_size_override("font_size", 22)
	var body_font: Font = ThemeManager.get_font("font_body")
	if body_font:
		subtitle.add_theme_font_override("font", body_font)
	subtitle.modulate = Color(1.5, 1.5, 1.5, 1.0)  # Mild HDR
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game_over_overlay.add_child(subtitle)


# ── Warning rotator conditions ────────────────────────────────────────

# Warning colors — loaded from audition save file if available, otherwise defaults
var _warning_colors: Dictionary = {}  # id -> {color, hdr}
const WARNING_DEFAULTS: Dictionary = {
	"heat": {"color": Color(1.0, 0.4, 0.1), "hdr": 2.8},
	"fire": {"color": Color(1.0, 0.2, 0.0), "hdr": 3.0},
	"low_power": {"color": Color(0.7, 0.3, 1.0), "hdr": 2.8},
	"overdraw": {"color": Color(1.0, 0.15, 0.1), "hdr": 3.2},
	"shields_low": {"color": Color(1.0, 0.4, 0.1), "hdr": 2.8},
	"hull_damaged": {"color": Color(1.0, 0.4, 0.1), "hdr": 2.5},
	"hull_critical": {"color": Color(1.0, 0.15, 0.1), "hdr": 3.2},
}
const WARNING_LABELS: Dictionary = {
	"heat": "HEAT",
	"fire": "FIRE",
	"low_power": "LOW POWER",
	"overdraw": "OVERDRAW",
	"shields_low": "SHIELDS LOW",
	"hull_damaged": "HULL DAMAGED",
	"hull_critical": "HULL CRITICAL",
}

func _load_warning_colors() -> void:
	_warning_colors = WARNING_DEFAULTS.duplicate(true)
	var path := "user://settings/warning_auditions.json"
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		return
	var data: Dictionary = json.data
	for warning_id in data:
		if WARNING_DEFAULTS.has(warning_id):
			var saved: Dictionary = data[warning_id]
			_warning_colors[warning_id] = {
				"color": Color(float(saved.get("r", 1.0)), float(saved.get("g", 0.3)), float(saved.get("b", 0.1))),
				"hdr": float(saved.get("hdr", WARNING_DEFAULTS[warning_id]["hdr"])),
			}


func _update_warning_rotator(delta: float) -> void:
	if _hull_damaged_timer > 0.0:
		_hull_damaged_timer -= delta

	var warnings: Array = []
	var p: Node2D = _player

	# Heat: thermal > 90%
	var thermal_ratio: float = p.thermal / maxf(p.thermal_max, 1.0)
	if thermal_ratio > 0.9:
		# Fire: thermal is at max (overflow damaging hull)
		if p.thermal >= p.thermal_max - 0.1:
			warnings.append(_make_warning("fire"))
		else:
			warnings.append(_make_warning("heat"))

	# Low Power: electric < 10%
	var electric_ratio: float = p.electric / maxf(p.electric_max, 1.0)
	if electric_ratio < 0.1 and p.electric_max > 0.0:
		# Overdraw: pulling from shields/engines
		if p._electric_overdraw or (p._electric_crisis_active and p.electric <= 0.1):
			warnings.append(_make_warning("overdraw"))
		else:
			warnings.append(_make_warning("low_power"))

	# Shields Low: < 10%
	var shield_ratio: float = p.shield / maxf(p.shield_max, 1.0)
	if shield_ratio < 0.1 and p.shield_max > 0.0 and p.shield < p.shield_max:
		warnings.append(_make_warning("shields_low"))

	# Hull Critical: < 15% (takes priority over Hull Damaged)
	var hull_ratio: float = p.hull / maxf(p.hull_max, 1.0)
	if hull_ratio < 0.15 and p.hull_max > 0.0:
		warnings.append(_make_warning("hull_critical"))
	elif _hull_damaged_timer > 0.0:
		warnings.append(_make_warning("hull_damaged"))

	_hud.update_warnings_rotator(warnings)

	# Fire effect on HUD panels — drive heat intensity from thermal state
	var fire_heat: float = 0.0
	if thermal_ratio > 0.9:
		if p.thermal >= p.thermal_max - 0.1:
			# FIRE: ramp from 0.3 to 1.0 based on how long we've been at max
			# Immediate entry at 0.3, ramps via the HUD's own smoothing
			fire_heat = 0.7 + thermal_ratio * 0.3
		else:
			# HEAT: subtle warmth, 0.0 at 90% → 0.3 at 100%
			fire_heat = (thermal_ratio - 0.9) / 0.1 * 0.3
	_hud.set_fire_intensity(fire_heat)

	# Alarm audio — start/stop looping sounds based on active warnings
	var current_ids: Array[String] = []
	for w in warnings:
		current_ids.append(str(w["id"]))

	# Stop alarms that are no longer active
	for old_id in _active_alarm_ids:
		if old_id not in current_ids:
			_stop_alarm(old_id)

	# Start alarms that are newly active
	for new_id in current_ids:
		if new_id not in _active_alarm_ids:
			_start_alarm(new_id)

	_active_alarm_ids = current_ids


func _start_alarm(warning_id: String) -> void:
	var alarm_event_id: String = "alarm_" + warning_id
	if _alarm_players.has(warning_id):
		return  # Already playing
	var cfg: SfxConfig = SfxConfigManager.load_config()
	var ev: Dictionary = cfg.get_event(alarm_event_id)
	var file_path: String = str(ev.get("file_path", ""))
	print("[ALARM] Starting '%s' → event='%s' file='%s'" % [warning_id, alarm_event_id, file_path])
	if file_path == "":
		print("[ALARM] No file assigned for '%s' — skipping" % alarm_event_id)
		return
	var stream: AudioStream = load(file_path) as AudioStream
	if not stream:
		print("[ALARM] Failed to load stream: %s" % file_path)
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = "SFX"
	player.volume_db = float(ev.get("volume_db", 0.0))
	# Re-trigger on finish so it loops continuously while the condition is active
	player.finished.connect(func():
		if _alarm_players.has(warning_id) and is_instance_valid(player):
			player.play()
	)
	print("[ALARM] Playing '%s' at %.1f dB on bus SFX" % [alarm_event_id, player.volume_db])
	add_child(player)
	player.play()
	_alarm_players[warning_id] = player


func _stop_alarm(warning_id: String) -> void:
	if not _alarm_players.has(warning_id):
		return
	var player: AudioStreamPlayer = _alarm_players[warning_id]
	if player and is_instance_valid(player):
		player.stop()
		player.queue_free()
	_alarm_players.erase(warning_id)


func _stop_all_alarms() -> void:
	for wid in _alarm_players:
		var player: AudioStreamPlayer = _alarm_players[wid]
		if player and is_instance_valid(player):
			player.stop()
			player.queue_free()
	_alarm_players.clear()
	_active_alarm_ids.clear()


func _make_warning(warning_id: String) -> Dictionary:
	var entry: Dictionary = _warning_colors.get(warning_id, WARNING_DEFAULTS.get(warning_id, {}))
	return {
		"id": warning_id,
		"label": WARNING_LABELS.get(warning_id, warning_id.to_upper()),
		"color": entry.get("color", Color.RED),
		"hdr": entry.get("hdr", 2.8),
	}


# ── Screen shake ─────────────────────────────────────────────────────

func trigger_screen_shake(amplitude: float, duration: float) -> void:
	if not _game_viewport_container:
		return
	if _screen_shake_remaining <= 0.0:
		_screen_shake_original_pos = _game_viewport_container.position
	_screen_shake_amplitude = maxf(_screen_shake_amplitude, amplitude)
	_screen_shake_remaining = maxf(_screen_shake_remaining, duration)


func _process_screen_shake(delta: float) -> void:
	if _screen_shake_remaining <= 0.0:
		return
	_screen_shake_remaining -= delta
	if _screen_shake_remaining <= 0.0:
		_game_viewport_container.position = _screen_shake_original_pos
		_screen_shake_amplitude = 0.0
		return
	var intensity: float = minf(_screen_shake_remaining / 0.15, 1.0)
	var t: float = float(Time.get_ticks_msec()) / 1000.0
	var ox: float = sin(t * 55.0) * _screen_shake_amplitude * intensity
	var oy: float = cos(t * 40.0) * _screen_shake_amplitude * intensity * 0.7
	_game_viewport_container.position = _screen_shake_original_pos + Vector2(ox, oy)


# ── Game events system ───────────────────────────────────────────────

func _setup_game_event_overlays() -> void:
	## Create overlay nodes for screen effects. Added as siblings to game viewport
	## so they render on top of game but below HUD.
	# Static/interference overlay
	_static_overlay = ColorRect.new()
	_static_overlay.name = "StaticOverlay"
	_static_overlay.position = Vector2.ZERO
	_static_overlay.size = Vector2(1920, 1080)
	_static_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_static_overlay.z_index = 40  # Above game, below HUD (50)
	_static_overlay.visible = false
	var static_shader: Shader = load("res://assets/shaders/screen_static.gdshader")
	_static_shader_mat = ShaderMaterial.new()
	_static_shader_mat.shader = static_shader
	_static_shader_mat.set_shader_parameter("intensity", 0.0)
	_static_overlay.material = _static_shader_mat
	add_child(_static_overlay)

	# Lightning flash overlay
	_lightning_overlay = ColorRect.new()
	_lightning_overlay.name = "LightningOverlay"
	_lightning_overlay.position = Vector2.ZERO
	_lightning_overlay.size = Vector2(1920, 1080)
	_lightning_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lightning_overlay.z_index = 41
	_lightning_overlay.visible = false
	_lightning_overlay.color = Color(1.0, 1.0, 1.0, 0.0)
	add_child(_lightning_overlay)


func trigger_game_event(event_id: String) -> void:
	## Fire a game event by ID. Loads and caches the event data, then processes each effect.
	var event_data: GameEventData = null
	if _game_event_cache.has(event_id):
		event_data = _game_event_cache[event_id] as GameEventData
	else:
		event_data = GameEventDataManager.load_by_id(event_id)
		if event_data:
			_game_event_cache[event_id] = event_data
	if not event_data:
		push_warning("Game: unknown game event '%s'" % event_id)
		return
	for fx in event_data.effects:
		var fx_type: String = str(fx.get("type", ""))
		match fx_type:
			"screen_shake":
				var amplitude: float = float(fx.get("amplitude", 5.0))
				var duration: float = float(fx.get("duration", 0.5))
				trigger_screen_shake(amplitude, duration)
			"screen_static":
				_trigger_screen_static(float(fx.get("intensity", 0.5)), float(fx.get("duration", 0.5)))
			"lightning_flash":
				var col_arr: Array = fx.get("color", [1.0, 1.0, 1.0, 1.0]) as Array
				var col := Color(float(col_arr[0]), float(col_arr[1]), float(col_arr[2]), float(col_arr[3]))
				_trigger_lightning_flash(col, float(fx.get("intensity", 2.0)), int(fx.get("count", 1)), float(fx.get("interval", 0.15)))
			"screen_dim":
				_trigger_screen_dim(float(fx.get("brightness", 0.2)), float(fx.get("duration", 3.0)), float(fx.get("fade_in", 0.5)), float(fx.get("fade_out", 0.8)))
			"sfx":
				var sfx_id: String = str(fx.get("sfx_event_id", ""))
				var delay: float = float(fx.get("delay", 0.0))
				if delay > 0.0:
					get_tree().create_timer(delay).timeout.connect(func(): SfxPlayer.play(sfx_id))
				else:
					SfxPlayer.play(sfx_id)
			"hud_flicker":
				_trigger_hud_flicker(float(fx.get("intensity", 0.5)), float(fx.get("duration", 0.3)))


func _trigger_screen_static(intensity: float, duration: float) -> void:
	if not _static_overlay or not _static_shader_mat:
		return
	_static_overlay.visible = true
	_static_shader_mat.set_shader_parameter("intensity", intensity)
	var tween: Tween = create_tween()
	tween.tween_method(func(val: float): _static_shader_mat.set_shader_parameter("intensity", val), intensity, 0.0, duration)
	tween.tween_callback(func(): _static_overlay.visible = false)


func _trigger_lightning_flash(color: Color, intensity: float, count: int, interval: float) -> void:
	if not _lightning_overlay:
		return
	_active_lightning_count = count
	_active_lightning_timer = 0.0
	_active_lightning_interval = interval
	_active_lightning_color = color
	_active_lightning_intensity = intensity
	_fire_single_lightning()


func _fire_single_lightning() -> void:
	if not _lightning_overlay:
		return
	_lightning_overlay.visible = true
	var hdr_color := Color(_active_lightning_color.r * _active_lightning_intensity,
		_active_lightning_color.g * _active_lightning_intensity,
		_active_lightning_color.b * _active_lightning_intensity, 0.9)
	_lightning_overlay.color = hdr_color
	var tween: Tween = create_tween()
	tween.tween_property(_lightning_overlay, "color:a", 0.0, 0.12)
	tween.tween_callback(func(): _lightning_overlay.visible = false)
	_active_lightning_count -= 1
	if _active_lightning_count > 0:
		_active_lightning_timer = _active_lightning_interval


func _trigger_screen_dim(brightness: float, duration: float, fade_in: float, fade_out: float) -> void:
	## Dims the game viewport container (not HUD). HUD LEDs stay bright through darkness.
	if not _game_viewport_container:
		return
	var hold_time: float = maxf(duration - fade_in - fade_out, 0.0)
	var dim_color := Color(brightness, brightness, brightness, 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(_game_viewport_container, "modulate", dim_color, fade_in)
	if hold_time > 0.0:
		tween.tween_interval(hold_time)
	tween.tween_property(_game_viewport_container, "modulate", Color.WHITE, fade_out)


func _trigger_hud_flicker(intensity: float, duration: float) -> void:
	if not _hud:
		return
	var steps: int = int(duration / 0.05)
	var tween: Tween = create_tween()
	for i in range(steps):
		var target_a: float = 1.0 - intensity * randf()
		tween.tween_property(_hud, "modulate:a", target_a, 0.05)
	tween.tween_property(_hud, "modulate:a", 1.0, 0.05)


func _process_nebula_events(delta: float) -> void:
	## Tick nebula event timers. When countdown reaches zero, fire a random event.
	for nid in _active_nebula_data:
		var ndata: NebulaData = _active_nebula_data[nid] as NebulaData
		if ndata.event_ids.is_empty():
			continue
		if not _nebula_event_timers.has(nid):
			_nebula_event_timers[nid] = randf_range(ndata.event_interval_min, ndata.event_interval_max)
		_nebula_event_timers[nid] = float(_nebula_event_timers[nid]) - delta
		if float(_nebula_event_timers[nid]) <= 0.0:
			var event_id: String = ndata.event_ids[randi() % ndata.event_ids.size()]
			trigger_game_event(event_id)
			_nebula_event_timers[nid] = randf_range(ndata.event_interval_min, ndata.event_interval_max)


func _process_lightning_chain(delta: float) -> void:
	## Process multi-flash lightning chains (subsequent flashes after the first).
	if _active_lightning_count <= 0:
		return
	_active_lightning_timer -= delta
	if _active_lightning_timer <= 0.0:
		_fire_single_lightning()


# ── Death during power loss ──────────────────────────────────────────

func _on_power_loss_started() -> void:
	# Kill all warning alarms and visual warnings — ship is going dark
	_stop_all_alarms()
	if _hud:
		_hud.update_warnings_rotator([])
		_hud.set_fire_intensity(0.0)


func _on_power_loss_ended() -> void:
	pass  # Warnings resume naturally via _update_warning_rotator


func _on_player_died_during_power_loss() -> void:
	if _death_sequence_active or _power_death_active:
		return
	_stop_all_alarms()
	_power_death_active = true
	_power_death_timer = 0.0
	_power_death_explosion_accum = 0.0
	if _player:
		_death_player_pos = _player.global_position
		_player.disable_for_death()
	if _wave_manager:
		_wave_manager.stop()
	# Big initial shake + explosion
	trigger_screen_shake(8.0, 0.5)
	SfxPlayer.play_random_explosion()


func _process_power_loss_death(delta: float) -> void:
	_power_death_timer += delta
	var progress: float = clampf(_power_death_timer / POWER_DEATH_DURATION, 0.0, 1.0)

	# Phase 1 (0-1s): Escalating impacts, text corruption starts
	if _power_death_timer < 1.0:
		var spawn_interval: float = lerpf(0.4, 0.2, _power_death_timer)
		_power_death_explosion_accum += delta
		while _power_death_explosion_accum >= spawn_interval:
			_power_death_explosion_accum -= spawn_interval
			var offset := Vector2(randf_range(-50.0, 50.0), randf_range(-50.0, 50.0))
			var explosion := ExplosionEffect.new()
			explosion.explosion_color = Color(1.0, 0.5, 0.2)
			explosion.explosion_size = lerpf(0.4, 1.2, _power_death_timer)
			explosion.global_position = _death_player_pos + offset
			_game_viewport.add_child(explosion)
			SfxPlayer.play_random_explosion()
			trigger_screen_shake(lerpf(3.0, 6.0, _power_death_timer), 0.15)
		if _player:
			_player.corrupt_reboot_text(lerpf(0.05, 0.3, _power_death_timer))

	# Phase 2 (1-2s): Heavy sustained shake, full text scramble, rapid flicker
	elif _power_death_timer < 2.0:
		var phase2_t: float = (_power_death_timer - 1.0)
		trigger_screen_shake(lerpf(8.0, 12.0, phase2_t), 0.3)
		# Spawn explosions faster
		_power_death_explosion_accum += delta
		while _power_death_explosion_accum >= 0.12:
			_power_death_explosion_accum -= 0.12
			var offset := Vector2(randf_range(-60.0, 60.0), randf_range(-60.0, 60.0))
			var explosion := ExplosionEffect.new()
			explosion.explosion_color = Color(1.0, lerpf(0.4, 0.2, phase2_t), 0.1)
			explosion.explosion_size = lerpf(1.0, 2.5, phase2_t)
			explosion.global_position = _death_player_pos + offset
			_game_viewport.add_child(explosion)
			SfxPlayer.play_random_explosion()
		if _player:
			_player.corrupt_reboot_text(lerpf(0.4, 1.0, phase2_t))
			_player.modulate.a = 0.2 + randf() * 0.6

	# Phase 3 (2-2.5s): Bright flash and exit
	else:
		var phase3_t: float = (_power_death_timer - 2.0) / 0.5
		if _player and _player.visible:
			_player.visible = false
		# Flash: add a bright overlay that ramps up then triggers scene change
		if phase3_t < 0.6:
			# Flash building
			trigger_screen_shake(12.0, 0.1)
		if _power_death_timer >= POWER_DEATH_DURATION:
			# Clean up and show game over screen
			if _player:
				_player.cleanup_power_loss()
			_power_death_active = false
			_show_game_over()


# ── Boss transition sequence ──────────────────────────────────────────

func _on_boss_transition(ev: Dictionary) -> void:
	if _boss_transition_active or _death_sequence_active or _power_death_active:
		return
	_boss_transition_active = true
	_boss_transition_timer = 0.0
	_boss_transition_event = ev
	_bt_degrade_active = false
	_bt_remodulated = false
	_bt_typing_active = false
	_bt_typing_finished = false
	_bt_typing_fast = false
	_bt_typing_line_idx = 0
	_bt_typing_char_idx = 0
	_bt_typing_char_timer = 0.0
	_bt_typing_pause_timer = 0.0
	_bt_typing_completed_lines.clear()
	_bt_debug_y_offset = 0.0

	# Pre-register boss weapon loops with audio lead times
	var boss_id: String = str(ev.get("boss_id", ""))
	if boss_id != "":
		var boss: BossData = BossDataManager.load_by_id(boss_id)
		if boss:
			_preregister_boss_lead_loops(boss)


func _preregister_boss_lead_loops(boss: BossData) -> void:
	## Register and start (muted) all boss weapon loops that have audio_lead_sec > 0.
	## Schedule unmutes at BOSS_MUSIC_BLEED time for ominous bleed-in.
	var transition_end: float = BossTransitionSequence.get_transition_end_time()
	var all_overrides: Array = []
	for ovr in boss.core_weapon_overrides:
		all_overrides.append(ovr)
	for seg in boss.segments:
		var sd: Dictionary = seg as Dictionary
		for ovr in sd.get("weapon_overrides", []):
			all_overrides.append(ovr)

	print("[BT] _preregister_boss_lead_loops: %d overrides found" % all_overrides.size())
	for ovr in all_overrides:
		var d: Dictionary = ovr as Dictionary
		var lead: float = float(d.get("audio_lead_sec", 0.0))
		var wid: String = str(d.get("weapon_id", ""))
		print("[BT]   override: weapon=%s  audio_lead_sec=%.1f" % [wid, lead])
		if lead <= 0.0:
			continue
		var weapon_id: String = wid
		if weapon_id == "":
			continue
		var weapon: WeaponData = WeaponDataManager.load_by_id(weapon_id)
		if not weapon or weapon.loop_file_path == "":
			print("[BT]   SKIP — no weapon or no loop_file_path")
			continue
		var hp_idx: int = int(d.get("hardpoint_index", 0))
		var loop_id: String = weapon_id + "_hp_" + str(hp_idx)
		if LoopMixer.has_loop(loop_id):
			print("[BT]   SKIP — loop already exists: %s" % loop_id)
			continue
		print("[BT]   ADDING loop: %s  path=%s  unmute_at=%.1fs" % [loop_id, weapon.loop_file_path, maxf(transition_end - lead, BossTransitionSequence.BOSS_MUSIC_BLEED)])
		LoopMixer.add_loop(loop_id, weapon.loop_file_path, "Enemies", 0.0, true)
		LoopMixer.start_loop(loop_id)
		_boss_transition_lead_loops.append(loop_id)
		# Schedule unmute relative to transition end
		var unmute_at: float = maxf(transition_end - lead, BossTransitionSequence.BOSS_MUSIC_BLEED)
		get_tree().create_timer(unmute_at).timeout.connect(func() -> void:
			print("[BT]   UNMUTE timer fired for: %s  has_loop=%s" % [loop_id, LoopMixer.has_loop(loop_id)])
			if LoopMixer.has_loop(loop_id):
				LoopMixer.unmute(loop_id, 2000)
		)


func _process_boss_transition(delta: float) -> void:
	var prev_t: float = _boss_transition_timer
	_boss_transition_timer += delta
	var t: float = _boss_transition_timer

	# Helper: did we just cross a threshold?
	var crossed := func(threshold: float) -> bool:
		return prev_t < threshold and t >= threshold

	# ── Phase 1: DISRUPTION ──

	# WAVE_SWEEP — Energy wave sweeps screen
	if crossed.call(BossTransitionSequence.WAVE_SWEEP):
		_bt_debug("WAVE_SWEEP", t)
		SfxPlayer.play("boss_wave_sweep")
		_spawn_boss_wave_visual()

	# WAVE_HIT — Wave passes player, drift begins
	if crossed.call(BossTransitionSequence.WAVE_HIT):
		_bt_debug("WAVE_HIT", t)
		SfxPlayer.play("boss_wave_hit")
		if _player:
			_player.start_boss_transition_drift()
		trigger_screen_shake(4.0, 0.6)

	# MUSIC_DEGRADE_START — Music starts degrading
	if crossed.call(BossTransitionSequence.MUSIC_DEGRADE_START):
		_bt_debug("MUSIC_DEGRADE_START", t)
		SfxPlayer.play("boss_music_degrade")
		_bt_degrade_active = true

	# Progressive music degradation (runs every frame during degrade window)
	if _bt_degrade_active and t < BossTransitionSequence.MUSIC_DEGRADE_END:
		var degrade_t: float = (t - BossTransitionSequence.MUSIC_DEGRADE_START) / (BossTransitionSequence.MUSIC_DEGRADE_END - BossTransitionSequence.MUSIC_DEGRADE_START)
		degrade_t = clampf(degrade_t, 0.0, 1.0)
		var vol_offset: float = lerpf(0.0, -60.0, degrade_t)
		LoopMixer.set_all_volume_offset(vol_offset)
		var wobble: float = sin(t * 8.0 + sin(t * 3.7) * 2.0) * degrade_t * 0.15
		LoopMixer.set_all_pitch_scale(1.0 + wobble)

	# MUSIC_DEGRADE_END — Full silence achieved
	if crossed.call(BossTransitionSequence.MUSIC_DEGRADE_END):
		_bt_debug("MUSIC_DEGRADE_END (silence)", t)
		SfxPlayer.play("boss_silence")
		_bt_degrade_active = false
		LoopMixer.mute_all(0)
		LoopMixer.set_all_volume_offset(0.0)
		LoopMixer.set_all_pitch_scale(1.0)

	# BOSS_MUSIC_BLEED — Boss music fades in ominously
	if crossed.call(BossTransitionSequence.BOSS_MUSIC_BLEED):
		_bt_debug("BOSS_MUSIC_BLEED", t)
		SfxPlayer.play("boss_music_bleed")

	# WARNING_APPEAR — Warning box + boss name
	if crossed.call(BossTransitionSequence.WARNING_APPEAR):
		_bt_debug("WARNING_APPEAR", t)
		SfxPlayer.play("boss_warning")
		_show_boss_transition_warning()

	# TYPING_START — Diagnostic typing begins
	if crossed.call(BossTransitionSequence.TYPING_START):
		_bt_debug("TYPING_START", t)
		_bt_typing_active = true
		_bt_typing_lines.clear()
		for line in BossTransitionSequence.DIAGNOSTIC_LINES:
			_bt_typing_lines.append(line)
		_setup_bt_typing_sound()

	# Process typing each frame
	if _bt_typing_active and not _bt_typing_finished:
		_process_bt_typing(delta)

	# REMODULATE — triggered by typing reaching the "Carrier locked" line
	if not _bt_remodulated and _bt_typing_active:
		for completed_line in _bt_typing_completed_lines:
			if completed_line.begins_with("Carrier locked"):
				_bt_remodulated = true
				_bt_debug("REMODULATE", t)
				SfxPlayer.play("boss_remodulate")
				var key_shift: int = int(_boss_transition_event.get("key_shift_semitones", -2))
				var bpm_shift: float = float(_boss_transition_event.get("bpm_shift", 10.0))
				if key_shift != 0:
					LoopMixer.set_pitch_shift(float(key_shift), 1.5)
				if bpm_shift != 0.0 and _level_data:
					var ratio: float = (_level_data.bpm + bpm_shift) / maxf(_level_data.bpm, 1.0)
					LoopMixer.set_all_pitch_scale(ratio)
				# Don't unmute — player must manually reactivate weapons after control restores
				break

	# CONTROL_RESTORED / TRANSITION_END — after typing finishes + delays
	if _bt_typing_finished:
		_bt_typing_char_timer += delta
		var elapsed: float = _bt_typing_char_timer

		if elapsed >= BossTransitionSequence.CONTROL_RESTORE_DELAY:
			var prev_elapsed: float = elapsed - delta
			if prev_elapsed < BossTransitionSequence.CONTROL_RESTORE_DELAY:
				_bt_debug("CONTROL_RESTORED", t)
				SfxPlayer.play("boss_control_restored")
				if _player:
					_player.end_boss_transition_drift()

		if elapsed >= BossTransitionSequence.TRANSITION_END_DELAY:
			_bt_debug("TRANSITION_END", t)
			SfxPlayer.play("boss_transition_end")
			_boss_transition_active = false
			_cleanup_boss_transition_overlay()
			_spawn_boss_health_bar()


func _bt_debug(milestone: String, time: float) -> void:
	## Show a debug label on screen for boss transition milestones.
	## TODO: Remove once timing is finalized.
	var label := Label.new()
	label.text = "[%.2fs] %s" % [time, milestone]
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0))
	label.position = Vector2(10, 10 + _bt_debug_y_offset)
	label.z_index = 100
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	_bt_debug_y_offset += 18
	# Fade out after 4 seconds
	var tw := create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(label, "modulate:a", 0.0, 1.0)
	tw.tween_callback(label.queue_free)


func _spawn_boss_health_bar() -> void:
	## Create boss health bar after transition completes.
	if _boss_health_bar:
		return
	var boss_id: String = str(_boss_transition_event.get("boss_id", ""))
	var boss_name_str: String = "UNKNOWN"
	var total_health: float = 0.0
	if boss_id != "":
		var boss: BossData = BossDataManager.load_by_id(boss_id)
		if boss:
			boss_name_str = boss.display_name if boss.display_name != "" else boss_id
	# Sum health from all boss-tagged enemies currently alive
	_boss_enemies.clear()
	for child in _enemies.get_children():
		if child.has_meta("boss_part"):
			_boss_enemies.append(child)
			total_health += float(child.health) + float(child.shield)
	if total_health <= 0.0:
		total_health = 100.0
	_boss_health_bar = BossHealthBar.new()
	_boss_health_bar.name = "BossHealthBar"
	_boss_health_bar.max_health = total_health
	_boss_health_bar.current_health = total_health
	_boss_health_bar.size = Vector2(1920, 80)
	_boss_health_bar.z_index = 52  # Above HUD
	add_child(_boss_health_bar)


func _update_boss_health_bar() -> void:
	if not _boss_health_bar:
		return
	var total: float = 0.0
	var alive: bool = false
	for enemy in _boss_enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			total += float(enemy.health) + float(enemy.shield)
			alive = true
	if alive:
		var prev: float = _boss_health_bar.current_health
		_boss_health_bar.current_health = total
		if total < prev:
			_boss_health_bar.take_damage(total)
	else:
		# Boss defeated — animate out
		_boss_health_bar.current_health = 0.0
		var tw: Tween = create_tween()
		tw.tween_property(_boss_health_bar, "modulate:a", 0.0, 1.0)
		tw.tween_callback(func():
			if _boss_health_bar:
				_boss_health_bar.queue_free()
				_boss_health_bar = null
		)


func _spawn_boss_wave_visual() -> void:
	## Full-screen disruption wave sweeping from top to bottom.
	var wave := ColorRect.new()
	wave.size = Vector2(1920, 60)
	wave.position = Vector2(0, -60)
	wave.color = Color(0.7, 0.2, 1.0, 0.85)  # Purple-violet for boss disruption
	wave.z_index = 50
	wave.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game_viewport.add_child(wave)
	var tween := create_tween()
	tween.tween_property(wave, "position:y", 1080.0, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(wave, "modulate:a", 0.0, 0.5).set_delay(0.25)
	tween.tween_callback(wave.queue_free)


func _show_boss_transition_warning() -> void:
	## Holographic warning box with boss name + diagnostic typing area below.
	_boss_transition_overlay = Control.new()
	_boss_transition_overlay.name = "BossTransitionOverlay"
	_boss_transition_overlay.size = Vector2(1920, 1080)
	_boss_transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_transition_overlay.z_index = 55
	add_child(_boss_transition_overlay)

	# Warning box
	var boss_id: String = str(_boss_transition_event.get("boss_id", ""))
	var boss_name: String = "UNKNOWN"
	if boss_id != "":
		var boss: BossData = BossDataManager.load_by_id(boss_id)
		if boss and boss.display_name != "":
			boss_name = boss.display_name.to_upper()

	var box := _GameOverBox.new()
	var box_w: float = 500.0
	var box_h: float = 80.0
	box.box_size = Vector2(box_w, box_h)
	box.position = Vector2((1920 - box_w) * 0.5, 200)
	box.size = Vector2(box_w, box_h)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box._override_text = "WARNING: " + boss_name
	_boss_transition_overlay.add_child(box)
	_boss_transition_warning_box = box

	# Diagnostic typing label — reboot-style RichTextLabel
	_bt_typing_label = RichTextLabel.new()
	_bt_typing_label.bbcode_enabled = true
	_bt_typing_label.scroll_active = false
	_bt_typing_label.position = Vector2(560, 310)
	_bt_typing_label.size = Vector2(800, 500)
	_bt_typing_label.add_theme_color_override("default_color", Color(0.3, 1.0, 0.4))
	_bt_typing_label.add_theme_font_size_override("normal_font_size", 16)
	var body_font: Font = ThemeManager.get_font("font_body")
	if body_font:
		_bt_typing_label.add_theme_font_override("normal_font", body_font)
	_bt_typing_label.modulate = Color(1.8, 1.8, 1.8, 1.0)  # HDR boost for bloom
	_bt_typing_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Apply CRT scanline shader if available
	var scanline_shader: Shader = load("res://assets/shaders/crt_scanline_text.gdshader") as Shader
	if scanline_shader:
		var mat := ShaderMaterial.new()
		mat.shader = scanline_shader
		_bt_typing_label.material = mat
	_boss_transition_overlay.add_child(_bt_typing_label)


func _setup_bt_typing_sound() -> void:
	## Set up a looping typing thunk sound (like reboot sequence).
	if _bt_typing_player and is_instance_valid(_bt_typing_player):
		_bt_typing_player.queue_free()
		_bt_typing_player = null

	var config: SfxConfig = SfxConfigManager.load_config()
	var thunk_ev: Dictionary = config.get_event("boss_typing_thunk")
	var thunk_path: String = str(thunk_ev.get("file_path", ""))
	if thunk_path == "":
		return

	var stream: AudioStream = load(thunk_path) as AudioStream
	if not stream:
		return

	# Enable looping
	if stream is AudioStreamWAV:
		var wav: AudioStreamWAV = stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.mix_rate * (float(wav.data.size()) / (wav.mix_rate * (2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if wav.stereo else 1))))

	_bt_typing_player = AudioStreamPlayer.new()
	_bt_typing_player.stream = stream
	_bt_typing_player.bus = "UI"
	_bt_typing_player.volume_db = float(thunk_ev.get("volume_db", -10.0))
	add_child(_bt_typing_player)


func _process_bt_typing(delta: float) -> void:
	## Character-by-character typing, line by line — reboot style.
	if _bt_typing_line_idx >= _bt_typing_lines.size():
		_bt_typing_finished = true
		_bt_typing_char_timer = 0.0  # Repurposed as post-typing elapsed counter
		_stop_bt_typing_sound()
		return

	# Inter-line pause
	if _bt_typing_pause_timer > 0.0:
		_bt_typing_pause_timer -= delta
		_stop_bt_typing_sound()
		return

	var raw_line: String = _bt_typing_lines[_bt_typing_line_idx]

	# Check for fast phase transition
	if raw_line.begins_with(">") and not _bt_typing_fast:
		_bt_typing_fast = true

	var display_line: String = raw_line.lstrip(">")

	# Empty line = paragraph pause, advance immediately
	if display_line == "":
		_bt_typing_completed_lines.append("")
		_bt_typing_line_idx += 1
		_bt_typing_char_idx = 0
		_bt_typing_pause_timer = BossTransitionSequence.TYPEOUT_PARAGRAPH_PAUSE
		_update_bt_typing_display()
		return

	# Type characters
	var char_speed: float = BossTransitionSequence.TYPEOUT_CHAR_FAST if _bt_typing_fast else BossTransitionSequence.TYPEOUT_CHAR_SPEED
	_bt_typing_char_timer += delta

	var typed_any: bool = false
	while _bt_typing_char_timer >= char_speed and _bt_typing_char_idx < display_line.length():
		_bt_typing_char_timer -= char_speed
		_bt_typing_char_idx += 1
		typed_any = true

	if typed_any:
		_start_bt_typing_sound()
		_update_bt_typing_display()

	# Line complete
	if _bt_typing_char_idx >= display_line.length():
		_stop_bt_typing_sound()
		_bt_typing_completed_lines.append(display_line)

		# Fire SFX cues for special lines
		if display_line == "Weapons: ONLINE":
			SfxPlayer.play("boss_weapons_online")
		elif display_line == "REMODULATION COMPLETE":
			SfxPlayer.play("boss_control_restored")

		_bt_typing_line_idx += 1
		_bt_typing_char_idx = 0
		_bt_typing_char_timer = 0.0

		# Determine pause duration
		var is_header: bool = display_line == display_line.to_upper() and display_line.length() > 2
		_bt_typing_pause_timer = BossTransitionSequence.TYPEOUT_HEADER_PAUSE if is_header else BossTransitionSequence.TYPEOUT_LINE_PAUSE
		_update_bt_typing_display()


func _update_bt_typing_display() -> void:
	## Render completed lines + current typing line with cursor, bottom-anchored.
	if not _bt_typing_label or not is_instance_valid(_bt_typing_label):
		return

	var lines: Array[String] = []
	for completed in _bt_typing_completed_lines:
		lines.append(completed)

	# Current line being typed (with cursor)
	if _bt_typing_line_idx < _bt_typing_lines.size():
		var raw: String = _bt_typing_lines[_bt_typing_line_idx]
		var display: String = raw.lstrip(">")
		if display != "":
			var partial: String = display.substr(0, _bt_typing_char_idx)
			lines.append(partial + "[color=#228833]█[/color]")

	# Keep max visible lines (scroll up)
	var max_lines: int = 14
	while lines.size() > max_lines:
		lines.remove_at(0)

	_bt_typing_label.text = "\n".join(lines)


func _start_bt_typing_sound() -> void:
	if _bt_typing_player and is_instance_valid(_bt_typing_player) and not _bt_typing_player.playing:
		_bt_typing_player.play()


func _stop_bt_typing_sound() -> void:
	if _bt_typing_player and is_instance_valid(_bt_typing_player) and _bt_typing_player.playing:
		_bt_typing_player.stop()


func _cleanup_boss_transition_overlay() -> void:
	# Stop typing sound
	_stop_bt_typing_sound()
	if _bt_typing_player and is_instance_valid(_bt_typing_player):
		_bt_typing_player.queue_free()
		_bt_typing_player = null

	# Fade out overlay
	if _boss_transition_overlay and is_instance_valid(_boss_transition_overlay):
		var tween := create_tween()
		tween.tween_property(_boss_transition_overlay, "modulate:a", 0.0, 1.0)
		tween.tween_callback(func() -> void:
			if _boss_transition_overlay and is_instance_valid(_boss_transition_overlay):
				_boss_transition_overlay.queue_free()
				_boss_transition_overlay = null
		)
	_boss_transition_warning_box = null
	_bt_typing_label = null


func _return_to_menu() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_stop_all_alarms()
	LoopMixer.remove_all_loops()
	if _wave_manager:
		_wave_manager.stop()
	if _player:
		_player.stop_all()
	var dest: String = GameState.return_scene
	GameState.return_scene = ""
	if dest != "":
		SceneLoader.load_scene(dest)
	else:
		SceneLoader.load_scene("res://scenes/ui/main_menu.tscn")



func _setup_parallax() -> void:
	# Deep background image — behind everything, static (no scroll)
	if _level_data and _level_data.deep_background != "":
		var tex: Texture2D = load(_level_data.deep_background) as Texture2D
		if tex:
			var deep_bg := TextureRect.new()
			deep_bg.texture = tex
			deep_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			deep_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			deep_bg.size = Vector2(1920, 1080)
			deep_bg.z_index = -11
			_game_viewport.add_child(deep_bg)

	var grid_bg := ColorRect.new()
	grid_bg.size = Vector2(1920, 1080)
	grid_bg.z_index = -10
	# Use level-specific background shader if specified, otherwise default grid
	var bg_applied := false
	if _level_data and _level_data.background_shader != "":
		var shader: Shader = load(_level_data.background_shader) as Shader
		if shader:
			var mat := ShaderMaterial.new()
			mat.shader = shader
			mat.set_shader_parameter("manual_scroll", true)
			grid_bg.material = mat
			_bg_shader_mat = mat
			bg_applied = true
	if not bg_applied:
		ThemeManager.apply_grid_background(grid_bg)
	_game_viewport.add_child(grid_bg)

	_parallax_bg = ParallaxBackground.new()
	_parallax_bg.name = "ParallaxBG"
	_game_viewport.add_child(_parallax_bg)
	# Parallax speck layers — 3 depths between deep BG and doodads.
	# motion_scale is relative to scroll_speed (ParallaxBackground.scroll_offset).
	# Far = slow/tiny/dim/many, Near = fast/bigger/brighter/fewer.
	_add_speck_layer(0.25, 100, Color(0.1, 0.35, 0.45, 0.35), 0.6, 1.4, 10, -9)  # Far — synth cyan
	_add_speck_layer(0.50,  60, Color(0.15, 0.6, 0.75, 0.5), 0.8, 1.6, 20, -9)  # Mid — synth cyan
	_add_speck_layer(0.75,  30, Color(0.3, 0.85, 1.0, 0.65), 0.8, 1.8, 30, -8)  # Near — synth cyan, shrunk
	# Background layer (speed = scroll_speed) — doodad decorations
	_setup_doodads()
	# Nebula layer — same scroll_speed as encounters/doodads (handled separately)


func _setup_doodads() -> void:
	if not _level_data:
		return
	if _level_data.doodads.size() == 0:
		return
	_doodad_container = Node2D.new()
	_doodad_container.name = "Doodads"
	_doodad_container.z_index = -7  # Between bg shader (-10) and nebulas (-5)
	_game_viewport.add_child(_doodad_container)
	# Convert doodad x/y to game-space positions (same coord system as nebulas)
	var game_doodads: Array = []
	for dd in _level_data.doodads:
		game_doodads.append({
			"type": str(dd.get("type", "water_tower")),
			"x": 960.0 + float(dd.get("x", 0.0)),
			"y": -float(dd.get("y", 0.0)) + 540.0,
			"scale": float(dd.get("scale", 1.0)),
			"rotation_deg": float(dd.get("rotation_deg", 0.0)),
		})
	var renderer := DoodadRenderer.new()
	renderer.setup(game_doodads)
	_doodad_container.add_child(renderer)


func _add_speck_layer(motion_scale: float, speck_count: int, color: Color,
		size_min: float, size_max: float, seed_val: int, z: int) -> void:
	var layer := ParallaxLayer.new()
	layer.motion_scale = Vector2(0, motion_scale)
	layer.motion_mirroring = Vector2(0, 1200)
	layer.z_index = z
	_parallax_bg.add_child(layer)

	var specks := _SpeckField.new()
	specks.speck_count = speck_count
	specks.speck_color = color
	specks.speck_size_min = size_min
	specks.speck_size_max = size_max
	specks.speck_seed = seed_val
	specks.size = Vector2(1920, 1200)
	layer.add_child(specks)


class _DebugGrid extends Node2D:
	var grid_color: Color = Color.GREEN
	var label_text: String = "Layer"
	var speed_value: float = 0.0
	var line_spacing: float = 200.0

	func _draw() -> void:
		# Draw enough lines to cover viewport (1080) plus one extra above
		var count: int = int(1200.0 / line_spacing) + 2
		for i in range(-1, count):
			var y: float = float(i) * line_spacing
			draw_line(Vector2(0, y), Vector2(1920, y), grid_color, 2.0)
		var font: Font = ThemeDB.fallback_font
		var display: String = label_text + " (" + str(int(speed_value)) + " px/s)"
		draw_string(font, Vector2(10, 20), display, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, grid_color)


func _setup_debug_grids() -> void:
	# Deep background grid — static, never moves (purple)
	_deep_debug_grid = _DebugGrid.new()
	_deep_debug_grid.grid_color = Color(0.6, 0.3, 0.9, 0.4)
	_deep_debug_grid.label_text = "DEEP BG"
	_deep_debug_grid.speed_value = 0.0
	_deep_debug_grid.z_index = -9
	_deep_debug_grid.visible = false
	_game_viewport.add_child(_deep_debug_grid)

	# Background grid — scrolls at scroll_speed, manually positioned (green)
	_bg_debug_grid = _DebugGrid.new()
	_bg_debug_grid.grid_color = Color(0.3, 0.9, 0.3, 0.4)
	_bg_debug_grid.label_text = "BACKGROUND"
	_bg_debug_grid.speed_value = _scroll_speed
	_bg_debug_grid.z_index = -8
	_bg_debug_grid.visible = false
	_game_viewport.add_child(_bg_debug_grid)



func _setup_nebulas() -> void:
	if not _level_data:
		return
	if _level_data.nebula_placements.size() == 0:
		return

	_nebula_container = Node2D.new()
	_nebula_container.name = "Nebulas"
	_nebula_container.z_index = -5  # Behind gameplay, above stars
	_game_viewport.add_child(_nebula_container)

	for placement in _level_data.nebula_placements:
		var nebula_id: String = str(placement.get("nebula_id", ""))
		var trigger_y: float = float(placement.get("trigger_y", 0.0))
		var x_offset: float = float(placement.get("x_offset", 0.0))
		var radius: float = float(placement.get("radius", 300.0))

		var placement_seed: float = float(placement.get("seed_offset", 0.0))

		var ndata: NebulaData = NebulaDataManager.load_by_id(nebula_id)
		if not ndata:
			continue

		# Cache key change preset if assigned
		if ndata.key_change_id != "":
			var kc: KeyChangeData = KeyChangeDataManager.load_by_id(ndata.key_change_id)
			if kc:
				_key_change_presets[ndata.id] = kc

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
		mat.set_shader_parameter("seed_offset", float(params.get("seed_offset", defaults["seed_offset"])) + placement_seed)
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

		# Top veil layer — dedicated veil shader with edge contrast, renders above ships
		var top_opacity: float = float(params.get("top_opacity", defaults["top_opacity"]))
		if top_opacity > 0.0:
			var veil_shader: Shader = load("res://assets/shaders/nebula_veil.gdshader") as Shader
			var top_mat := ShaderMaterial.new()
			if veil_shader:
				top_mat.shader = veil_shader
			else:
				top_mat.shader = mat.shader
			var color_arr2: Array = params.get("nebula_color", defaults["nebula_color"]) as Array
			if color_arr2.size() >= 4:
				top_mat.set_shader_parameter("nebula_color", Color(float(color_arr2[0]), float(color_arr2[1]), float(color_arr2[2]), float(color_arr2[3])))
			top_mat.set_shader_parameter("brightness", float(params.get("brightness", defaults["brightness"])))
			top_mat.set_shader_parameter("animation_speed", float(params.get("animation_speed", defaults["animation_speed"])))
			top_mat.set_shader_parameter("density", float(params.get("density", defaults["density"])))
			top_mat.set_shader_parameter("seed_offset", float(params.get("seed_offset", defaults["seed_offset"])) + placement_seed)
			top_mat.set_shader_parameter("radial_spread", float(params.get("radial_spread", defaults["radial_spread"])))
			top_mat.set_shader_parameter("veil_contrast", float(params.get("veil_contrast", defaults.get("veil_contrast", 0.5))))
			var top_sprite := Sprite2D.new()
			top_sprite.texture = sprite.texture
			top_sprite.material = top_mat
			top_sprite.scale = sprite.scale
			top_sprite.position = sprite.position
			top_sprite.z_index = 10  # Relative to container at -5, so effective z = +5
			top_sprite.modulate.a = top_opacity
			_nebula_container.add_child(top_sprite)

		# Wash layer — flat tint with radial falloff, between ship and tufts
		var wash_opacity: float = float(params.get("wash_opacity", defaults.get("wash_opacity", 0.0)))
		if wash_opacity > 0.0:
			var wash_shader: Shader = load("res://assets/shaders/nebula_wash.gdshader") as Shader
			if wash_shader:
				var wash_mat := ShaderMaterial.new()
				wash_mat.shader = wash_shader
				var wash_color_arr: Array = params.get("nebula_color", defaults["nebula_color"]) as Array
				if wash_color_arr.size() >= 4:
					wash_mat.set_shader_parameter("nebula_color", Color(float(wash_color_arr[0]), float(wash_color_arr[1]), float(wash_color_arr[2]), 1.0))
				wash_mat.set_shader_parameter("radial_spread", float(params.get("radial_spread", defaults["radial_spread"])))
				var wash_sprite := Sprite2D.new()
				wash_sprite.texture = sprite.texture
				wash_sprite.material = wash_mat
				wash_sprite.scale = sprite.scale
				wash_sprite.position = sprite.position
				wash_sprite.z_index = 8  # Between ship layer and tufts layer
				wash_sprite.modulate.a = wash_opacity
				_nebula_container.add_child(wash_sprite)

		# Storm overlay layer — composited lightning on any nebula style
		var storm_on: bool = bool(params.get("storm_enabled", defaults.get("storm_enabled", false)))
		if storm_on:
			var storm_shader: Shader = load("res://assets/shaders/nebula_storm_overlay.gdshader") as Shader
			if storm_shader:
				var storm_mat := ShaderMaterial.new()
				storm_mat.shader = storm_shader
				var storm_color_arr: Array = params.get("nebula_color", defaults["nebula_color"]) as Array
				if storm_color_arr.size() >= 4:
					storm_mat.set_shader_parameter("nebula_color", Color(float(storm_color_arr[0]), float(storm_color_arr[1]), float(storm_color_arr[2]), float(storm_color_arr[3])))
				storm_mat.set_shader_parameter("animation_speed", float(params.get("animation_speed", defaults["animation_speed"])))
				storm_mat.set_shader_parameter("seed_offset", float(params.get("seed_offset", defaults["seed_offset"])) + placement_seed)
				storm_mat.set_shader_parameter("radial_spread", float(params.get("radial_spread", defaults["radial_spread"])))
				storm_mat.set_shader_parameter("brightness", float(params.get("brightness", defaults["brightness"])))
				storm_mat.set_shader_parameter("storm_frequency", float(params.get("storm_frequency", defaults.get("storm_frequency", 0.4))))
				storm_mat.set_shader_parameter("storm_strike_size", float(params.get("storm_strike_size", defaults.get("storm_strike_size", 0.12))))
				storm_mat.set_shader_parameter("storm_duration", float(params.get("storm_duration", defaults.get("storm_duration", 0.2))))
				storm_mat.set_shader_parameter("storm_glow_diameter", float(params.get("storm_glow_diameter", defaults.get("storm_glow_diameter", 0.3))))
				var storm_sprite := Sprite2D.new()
				storm_sprite.texture = sprite.texture
				storm_sprite.material = storm_mat
				storm_sprite.scale = sprite.scale
				storm_sprite.position = sprite.position
				storm_sprite.z_index = 9  # Between wash (8) and veil (10)
				_nebula_container.add_child(storm_sprite)

		# Debug hitbox outline — shrink to where nebula is ~50% visible
		var spread: float = float(params.get("radial_spread", defaults["radial_spread"]))
		var effective_radius: float = radius * (1.0 - spread / 2.0)
		var debug_ring := _NebulaDebugRing.new()
		debug_ring.radius = effective_radius
		debug_ring.position = sprite.position
		debug_ring.z_index = 15
		_nebula_container.add_child(debug_ring)

		# Collision area for status effects (if nebula has any effects defined)
		if ndata.bar_effects.size() > 0 or ndata.special_effects.size() > 0 or ndata.key_change_id != "":
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


class _SpeckField extends Control:
	## Twinkling star specks with per-speck phase offsets for gentle shimmer.
	var speck_count: int = 60
	var speck_color: Color = Color(0.5, 0.5, 0.8, 0.6)
	var speck_size_min: float = 1.0
	var speck_size_max: float = 2.5
	var speck_seed: int = 1
	var _positions: PackedVector2Array = PackedVector2Array()
	var _sizes: PackedFloat32Array = PackedFloat32Array()
	var _phases: PackedFloat32Array = PackedFloat32Array()  # Twinkle phase offset
	var _speeds: PackedFloat32Array = PackedFloat32Array()  # Twinkle speed
	var _time: float = 0.0

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = speck_seed
		for i in speck_count:
			_positions.append(Vector2(rng.randf() * 1920.0, rng.randf() * 1200.0))
			_sizes.append(rng.randf_range(speck_size_min, speck_size_max))
			_phases.append(rng.randf() * TAU)
			_speeds.append(rng.randf_range(0.8, 2.5))

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		for i in _positions.size():
			# Twinkle: alpha oscillates gently, never fully disappears
			var twinkle: float = 0.6 + 0.4 * sin(_time * _speeds[i] + _phases[i])
			var col := Color(speck_color.r, speck_color.g, speck_color.b, speck_color.a * twinkle)
			var r: float = _sizes[i] * (0.85 + 0.15 * twinkle)
			draw_circle(_positions[i], r, col)


class _GameOverBox extends Control:
	## Holographic "GAME OVER" box — same style as warning badges, larger, always on.
	var box_size: Vector2 = Vector2(460, 100)
	var _override_text: String = ""  # If set, display this instead of "GAME OVER"
	var _time: float = 0.0

	const COL := Color(1.0, 0.15, 0.1)
	const HDR: float = 3.0
	const BORDER_W: float = 2.5
	const GLOW_LAYERS: int = 5
	const GLOW_SPREAD: float = 3.5
	const SCANLINE_SPACING: float = 3.0
	const SCANLINE_ALPHA: float = 0.35
	const SCANLINE_SCROLL: float = 45.0
	const FLICKER_SPEED: float = 5.0
	const FLICKER_AMOUNT: float = 0.15

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var flicker: float = 1.0 - FLICKER_AMOUNT * (0.5 + 0.5 * sin(_time * FLICKER_SPEED + sin(_time * 2.3) * 3.0))
		var w: float = box_size.x
		var h: float = box_size.y

		# Glow layers
		for gi in range(GLOW_LAYERS, 0, -1):
			var t: float = float(gi) / float(GLOW_LAYERS)
			var expand: float = t * GLOW_SPREAD * float(GLOW_LAYERS)
			var glow_alpha: float = (1.0 - t) * 0.15 * flicker
			var glow_col := Color(COL.r * HDR, COL.g * HDR, COL.b * HDR, glow_alpha)
			draw_rect(Rect2(Vector2(-expand, -expand), Vector2(w + expand * 2.0, h + expand * 2.0)),
				glow_col, false, BORDER_W + expand * 0.5)

		# Main border
		draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)),
			Color(COL.r * HDR, COL.g * HDR, COL.b * HDR, 0.9 * flicker), false, BORDER_W)

		# Corner marks
		var cm_len: float = 16.0
		var cm_col := Color(COL.r * HDR, COL.g * HDR, COL.b * HDR, 0.7 * flicker)
		var cm_off: float = -5.0
		draw_line(Vector2(cm_off, cm_off), Vector2(cm_off + cm_len, cm_off), cm_col, 2.0)
		draw_line(Vector2(cm_off, cm_off), Vector2(cm_off, cm_off + cm_len), cm_col, 2.0)
		draw_line(Vector2(w - cm_off, cm_off), Vector2(w - cm_off - cm_len, cm_off), cm_col, 2.0)
		draw_line(Vector2(w - cm_off, cm_off), Vector2(w - cm_off, cm_off + cm_len), cm_col, 2.0)
		draw_line(Vector2(cm_off, h - cm_off), Vector2(cm_off + cm_len, h - cm_off), cm_col, 2.0)
		draw_line(Vector2(cm_off, h - cm_off), Vector2(cm_off, h - cm_off - cm_len), cm_col, 2.0)
		draw_line(Vector2(w - cm_off, h - cm_off), Vector2(w - cm_off - cm_len, h - cm_off), cm_col, 2.0)
		draw_line(Vector2(w - cm_off, h - cm_off), Vector2(w - cm_off, h - cm_off - cm_len), cm_col, 2.0)

		# Scanlines
		var scan_col := Color(COL.r * HDR * 0.5, COL.g * HDR * 0.5, COL.b * HDR * 0.5, SCANLINE_ALPHA * flicker)
		var scroll_offset: float = fmod(_time * SCANLINE_SCROLL, SCANLINE_SPACING)
		var y: float = scroll_offset
		while y < h:
			draw_line(Vector2(BORDER_W, y), Vector2(w - BORDER_W, y), scan_col, 1.0)
			y += SCANLINE_SPACING

		# "GAME OVER" text
		var font: Font = ThemeManager.get_font("font_header")
		if not font:
			font = ThemeDB.fallback_font
		var font_size: int = 52
		var text: String = _override_text if _override_text != "" else "GAME OVER"
		var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_x: float = (w - text_size.x) * 0.5
		var text_y: float = (h + text_size.y * 0.6) * 0.5
		var text_col := Color(COL.r * HDR, COL.g * HDR, COL.b * HDR, 0.95 * flicker)
		draw_string(font, Vector2(text_x, text_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_col)


# ── End of level ─────────────────────────────────────────────────────

func _start_end_of_level() -> void:
	if _end_of_level_active:
		return
	_end_of_level_active = true
	_end_of_level_time = 0.0

	# Build stats lines
	var destroyed: int = int(GameState.level_stats.get("enemies_destroyed", 0))
	var total: int = int(GameState.level_stats.get("enemies_total", 0))
	var pct: int = 0
	if total > 0:
		pct = int(float(destroyed) / float(total) * 100.0)
	var heat: int = int(GameState.level_stats.get("heat_generated", 0.0))
	var score: int = int(GameState.level_stats.get("score", 0))
	var grade: String = GameState.calculate_grade()

	_end_of_level_typing_lines = [
		"> MISSION COMPLETE",
		"",
		"> ENEMIES DESTROYED: %d/%d (%d%%)" % [destroyed, total, pct],
		"> HEAT GENERATED: %s" % str(heat),
		"> SCORE: %s" % str(score),
		"",
		"> RATING: %s" % grade,
	]
	_end_of_level_typing_idx = 0
	_end_of_level_char_idx = 0
	_end_of_level_char_timer = 0.0
	_end_of_level_pause_timer = 0.3  # Initial pause before typing starts
	_end_of_level_completed_lines.clear()
	_end_of_level_prompt_visible = false

	# Disable player weapons
	if _player:
		_player.set_meta("level_complete", true)

	# Create overlay
	_end_of_level_overlay = Control.new()
	_end_of_level_overlay.name = "EndOfLevelOverlay"
	_end_of_level_overlay.size = Vector2(1920, 1080)
	_end_of_level_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_of_level_overlay.z_index = 55
	add_child(_end_of_level_overlay)

	# Semi-transparent background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_of_level_overlay.add_child(bg)
	var bg_tw: Tween = create_tween()
	bg_tw.tween_property(bg, "color:a", 0.6, 1.5)

	# Typing label — left-aligned, same CRT style as power loss
	_end_of_level_label = RichTextLabel.new()
	_end_of_level_label.bbcode_enabled = true
	_end_of_level_label.scroll_active = false
	_end_of_level_label.fit_content = true
	_end_of_level_label.position = Vector2(200, 300)
	_end_of_level_label.size = Vector2(800, 400)
	_end_of_level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font: Font = ThemeManager.get_font("font_mono")
	if font:
		_end_of_level_label.add_theme_font_override("normal_font", font)
	_end_of_level_label.add_theme_font_size_override("normal_font_size", 22)
	_end_of_level_label.add_theme_color_override("default_color", Color(0.3, 1.0, 0.4))
	_end_of_level_overlay.add_child(_end_of_level_label)

	# Save grade
	if _level_data:
		GameState.completed_levels[_level_data.id] = grade
		GameState.save_game()


func _process_end_of_level(delta: float) -> void:
	_end_of_level_time += delta

	# Pause between lines
	if _end_of_level_pause_timer > 0.0:
		_end_of_level_pause_timer -= delta
		return

	if _end_of_level_typing_idx >= _end_of_level_typing_lines.size():
		# Typing done — show prompt
		if not _end_of_level_prompt_visible:
			_end_of_level_prompt_visible = true
			_update_end_of_level_text()
		return

	var line: String = _end_of_level_typing_lines[_end_of_level_typing_idx]

	# Empty lines — instant
	if line == "":
		_end_of_level_completed_lines.append("")
		_end_of_level_typing_idx += 1
		_end_of_level_pause_timer = 0.1
		_update_end_of_level_text()
		return

	# Type characters
	var char_speed: float = 0.025
	if line.begins_with("> RATING"):
		char_speed = 0.06  # Dramatic pause for grade
	_end_of_level_char_timer += delta
	while _end_of_level_char_timer >= char_speed and _end_of_level_char_idx < line.length():
		_end_of_level_char_timer -= char_speed
		_end_of_level_char_idx += 1
		SfxPlayer.play_ui("reboot_char_thunk")

	_update_end_of_level_text()

	if _end_of_level_char_idx >= line.length():
		_end_of_level_completed_lines.append(line)
		_end_of_level_typing_idx += 1
		_end_of_level_char_idx = 0
		_end_of_level_char_timer = 0.0
		_end_of_level_pause_timer = 0.2
		SfxPlayer.play_ui("reboot_line_beep")


func _update_end_of_level_text() -> void:
	if not _end_of_level_label:
		return
	var text: String = ""
	for completed_line in _end_of_level_completed_lines:
		text += completed_line + "\n"
	# Current line being typed
	if _end_of_level_typing_idx < _end_of_level_typing_lines.size():
		var current: String = _end_of_level_typing_lines[_end_of_level_typing_idx]
		text += current.substr(0, _end_of_level_char_idx)
	if _end_of_level_prompt_visible:
		text += "\n\n[color=#8888aa]PRESS ANY KEY TO CONTINUE[/color]"
	_end_of_level_label.text = "[color=#4dff66]" + text + "[/color]"


class _IntroTitleBox extends Control:
	## Holographic level intro title — shows level number then level name.
	## Cut in instantly, fade out before each transition.
	var box_size: Vector2 = Vector2(400, 80)
	var level_number_text: String = "LEVEL 01"
	var level_name_text: String = "Welcome Void"
	var measure_duration: float = 2.18
	var fade_lead_time: float = 0.5
	var intro_time: float = 0.0  # Set by game.gd each frame
	var _time: float = 0.0

	const COL := Color(0.3, 0.6, 1.0)  # Blue
	const HDR: float = 2.7
	const BORDER_W: float = 2.0
	const GLOW_LAYERS: int = 4
	const GLOW_SPREAD: float = 3.0
	const SCANLINE_SPACING: float = 3.0
	const SCANLINE_ALPHA: float = 0.3
	const SCANLINE_SCROLL: float = 45.0
	const FLICKER_SPEED: float = 5.0
	const FLICKER_AMOUNT: float = 0.12

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		# Determine which text to show and its alpha
		var text: String = ""
		var font_size: int = 42
		var alpha: float = 0.0

		var hit2_time: float = measure_duration * 2.0
		var end_time: float = measure_duration * 4.0

		var visible_time: float = 0.5  # Title visible at full brightness for 0.5s
		var fade_margin: float = 0.5  # Fully faded this long before next phase
		# Fade duration: reach 0 with margin to spare before the next title cuts in
		var fade1_dur: float = hit2_time - visible_time - fade_margin

		if intro_time < 0.0:
			# Pre-delay — nothing visible yet
			return
		elif intro_time < hit2_time:
			# Phase 0: level number — cut in, start fading at 0.5s, gone before hit 2
			text = level_number_text
			font_size = 42
			if intro_time < visible_time:
				alpha = 1.0
			else:
				alpha = 1.0 - clampf((intro_time - visible_time) / fade1_dur, 0.0, 1.0)
		elif intro_time < end_time:
			# Phase 1: level name — cut in at hit 2, start fading at hit2 + 0.5s
			text = level_name_text
			font_size = 32
			var phase1_time: float = intro_time - hit2_time
			var phase1_dur: float = measure_duration * 2.0
			var fade2_dur: float = phase1_dur - visible_time - fade_margin
			if phase1_time < visible_time:
				alpha = 1.0
			else:
				alpha = 1.0 - clampf((phase1_time - visible_time) / fade2_dur, 0.0, 1.0)

		if text == "" or alpha <= 0.01:
			return

		var flicker: float = 1.0 - FLICKER_AMOUNT * (0.5 + 0.5 * sin(_time * FLICKER_SPEED + sin(_time * 2.3) * 3.0))
		var w: float = box_size.x
		var h: float = box_size.y
		var eff_alpha: float = alpha * flicker

		# Glow layers
		for gi in range(GLOW_LAYERS, 0, -1):
			var t: float = float(gi) / float(GLOW_LAYERS)
			var expand: float = t * GLOW_SPREAD * float(GLOW_LAYERS)
			var glow_alpha: float = (1.0 - t) * 0.15 * eff_alpha
			var glow_col := Color(COL.r * HDR, COL.g * HDR, COL.b * HDR, glow_alpha)
			draw_rect(Rect2(Vector2(-expand, -expand), Vector2(w + expand * 2.0, h + expand * 2.0)),
				glow_col, false, BORDER_W + expand * 0.5)

		# Main border
		draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)),
			Color(COL.r * HDR, COL.g * HDR, COL.b * HDR, 0.9 * eff_alpha), false, BORDER_W)

		# Corner marks
		var cm_len: float = 12.0
		var cm_col := Color(COL.r * HDR, COL.g * HDR, COL.b * HDR, 0.7 * eff_alpha)
		var cm_off: float = -4.0
		draw_line(Vector2(cm_off, cm_off), Vector2(cm_off + cm_len, cm_off), cm_col, 1.5)
		draw_line(Vector2(cm_off, cm_off), Vector2(cm_off, cm_off + cm_len), cm_col, 1.5)
		draw_line(Vector2(w - cm_off, cm_off), Vector2(w - cm_off - cm_len, cm_off), cm_col, 1.5)
		draw_line(Vector2(w - cm_off, cm_off), Vector2(w - cm_off, cm_off + cm_len), cm_col, 1.5)
		draw_line(Vector2(cm_off, h - cm_off), Vector2(cm_off + cm_len, h - cm_off), cm_col, 1.5)
		draw_line(Vector2(cm_off, h - cm_off), Vector2(cm_off, h - cm_off - cm_len), cm_col, 1.5)
		draw_line(Vector2(w - cm_off, h - cm_off), Vector2(w - cm_off - cm_len, h - cm_off), cm_col, 1.5)
		draw_line(Vector2(w - cm_off, h - cm_off), Vector2(w - cm_off, h - cm_off - cm_len), cm_col, 1.5)

		# Scanlines
		var scan_col := Color(COL.r * HDR * 0.5, COL.g * HDR * 0.5, COL.b * HDR * 0.5, SCANLINE_ALPHA * eff_alpha)
		var scroll_offset: float = fmod(_time * SCANLINE_SCROLL, SCANLINE_SPACING)
		var y: float = scroll_offset
		while y < h:
			draw_line(Vector2(BORDER_W, y), Vector2(w - BORDER_W, y), scan_col, 1.0)
			y += SCANLINE_SPACING

		# Text — centered
		var font: Font = ThemeManager.get_font("font_header")
		if not font:
			font = ThemeDB.fallback_font
		var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_x: float = (w - text_size.x) * 0.5
		var text_y: float = (h + text_size.y * 0.6) * 0.5
		var text_col := Color(COL.r * HDR, COL.g * HDR, COL.b * HDR, 0.95 * eff_alpha)
		draw_string(font, Vector2(text_x, text_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_col)


# ── Mouse Navigation Indicator ────────────────────────────────────────

class _MouseNavIndicator extends Node2D:
	## Tiny hollow diamond at the mouse position — subtle navigation hint.
	const SIZE: float = 4.0
	const LINE_W: float = 1.0
	const COL := Color(0.5, 0.7, 1.0)
	const HDR: float = 1.0
	var _time: float = 0.0

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var pulse: float = 0.9 + 0.1 * sin(_time * 2.5)
		var col := Color(COL.r * HDR, COL.g * HDR, COL.b * HDR, 0.35 * pulse)
		var s: float = SIZE
		var pts: PackedVector2Array = PackedVector2Array([
			Vector2(0, -s), Vector2(s, 0), Vector2(0, s), Vector2(-s, 0), Vector2(0, -s)
		])
		draw_polyline(pts, col, LINE_W, true)
