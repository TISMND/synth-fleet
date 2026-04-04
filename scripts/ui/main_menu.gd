extends Control
## Main menu with navigation to Play sub-menu, Options, Quit, and Dev Studio sub-menu.
## Menu music: all layers start muted, each unmutes on-beat at its configured start_bar.
## Music persists across menu screens — fades out only when entering gameplay.
##
## Background is split into two rendering layers to prevent HDR bloom blowout:
##   1. Planet SubViewport — sky, planet, rings, stars, nebula, warps (own bloom)
##   2. Grid overlay — grid lines, horizon glow, motion lights (root viewport bloom)
## Each layer's bloom is resolved independently so complementary HDR colors
## (pink grid + blue rings) never sum to white in the post-process pass.

var _vhs_overlay: ColorRect
var _menu_loop_ids: Array[String] = []
var _menu_fade_ms: int = 2000

const SW_SETTINGS_PATH: String = "user://settings/synthwave_bg.json"

# Planet/ring params live in the planet shader; grid params in the grid shader.
# These params are shared between both shaders and must be synced.
const _SHARED_PARAMS: Array[String] = [
	"horizon", "planet_x", "atmo_color",
]

# Params that belong to the planet shader (SubViewport).
const _PLANET_PARAMS: Array[String] = [
	"planet_x", "planet_radius", "planet_color_top", "planet_color_bot", "planet_hdr",
	"slice_enabled", "slice_start", "slice_band_h", "slice_gap_base", "slice_gap_grow",
	"ring_inner", "ring_outer", "ring_tilt", "ring_angle", "ring_color", "ring_hdr",
	"ring_band_width", "ring_gap_base", "ring_gap_grow", "ring_glow_size",
	"planet_tilted", "atmo_glow", "atmo_color",
	"sky_top", "sky_mid", "sky_low", "horizon",
	"accent_color", "nebula_intensity", "nebula_scale", "nebula_drift",
	"star_density", "star_size", "star_glow_size", "star_brightness", "star_twinkle", "star_color",
	"warp_streak_intensity", "warp_streak_speed", "warp_streak_count",
	"warp_inner_radius", "warp_fade_width", "warp_max_length", "warp_streak_width",
]


func _ready() -> void:
	_setup_synthwave_bg()
	_setup_vhs_overlay()
	_setup_title_shader()
	ThemeManager.theme_changed.connect(_on_theme_changed)

	$VBoxContainer/PlayButton.pressed.connect(_on_play)
	$VBoxContainer/OptionsButton.pressed.connect(_on_options)
	$VBoxContainer/FeatureRequestsButton.pressed.connect(_on_feature_requests)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit)
	if OS.is_debug_build():
		$VBoxContainer/DevStudioButton.pressed.connect(_on_dev_studio)
	else:
		$VBoxContainer/DevStudioButton.hide()

	_apply_styles()
	_start_menu_music()


func _start_menu_music() -> void:
	# If loops are already playing (e.g. returning from options), nothing to do —
	# GameState._process handles progression across all menu screens
	if GameState.has_meta("menu_loop_ids"):
		var existing: Array = GameState.get_meta("menu_loop_ids") as Array
		if existing.size() > 0 and LoopMixer.has_loop(str(existing[0])):
			return

	var config: Dictionary = MenuMusicConfigManager.load_config()
	_menu_fade_ms = int(config.get("fade_out_duration_ms", 2000))
	var bpm: float = float(config.get("bpm", 120.0))
	var bar_duration: float = 60.0 / maxf(bpm, 1.0) * 4.0
	var layers: Array = config.get("layers", []) as Array
	var layer_start_bars: Dictionary = {}
	var layer_unmuted: Dictionary = {}
	_menu_loop_ids.clear()

	for layer in layers:
		var d: Dictionary = layer as Dictionary
		var layer_id: String = str(d.get("id", ""))
		var file_path: String = str(d.get("file_path", ""))
		var vol: float = float(d.get("volume_db", 0.0))
		var start_bar: int = int(d.get("start_bar", 0))
		if layer_id == "" or file_path == "":
			continue
		if not FileAccess.file_exists(file_path) and not ResourceLoader.exists(file_path):
			push_warning("MenuMusic: missing audio file '%s'" % file_path)
			continue
		LoopMixer.add_loop(layer_id, file_path, "Master", vol, true)
		_menu_loop_ids.append(layer_id)
		layer_start_bars[layer_id] = start_bar
		layer_unmuted[layer_id] = false
	if _menu_loop_ids.size() > 0:
		LoopMixer.start_all()
		GameState.set_meta("menu_music_start_ticks", Time.get_ticks_msec())
		GameState.start_menu_music_progression(layer_start_bars, bar_duration, layer_unmuted)
	# Store on GameState so any screen can find and fade them
	GameState.set_meta("menu_loop_ids", _menu_loop_ids.duplicate())
	GameState.set_meta("menu_fade_ms", _menu_fade_ms)


func _on_play() -> void:
	# Music keeps playing through menu screens — fades when game actually launches
	get_tree().change_scene_to_file("res://scenes/ui/mission_prep_menu.tscn")


func _on_options() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/options_screen.tscn")


func _on_feature_requests() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/feature_requests_screen.tscn")


func _on_quit() -> void:
	get_tree().quit()


func _on_dev_studio() -> void:
	# Fade menu music when entering dev studio, but navigate immediately
	GameState.fade_out_menu_music()
	get_tree().change_scene_to_file("res://scenes/ui/dev_studio_menu.tscn")


func _setup_title_shader() -> void:
	var title_label: Label = $TitleLabel
	var shader: Shader = load("res://assets/shaders/title_chrome_3d.gdshader")
	if not shader:
		return
	var mat := ShaderMaterial.new()
	mat.shader = shader
	# Ethnocentric — Specular Slit (no gleam)
	mat.set_shader_parameter("chrome_color_top", Color(0.01, 0.03, 0.1))
	mat.set_shader_parameter("chrome_color_highlight1", Color(0.5, 0.75, 1.0))
	mat.set_shader_parameter("chrome_color_mid", Color(0.03, 0.06, 0.15))
	mat.set_shader_parameter("chrome_color_highlight2", Color(0.35, 0.55, 0.85))
	mat.set_shader_parameter("chrome_color_bottom", Color(0.01, 0.02, 0.06))
	mat.set_shader_parameter("band1_pos", 0.2)
	mat.set_shader_parameter("band2_pos", 0.45)
	mat.set_shader_parameter("band3_pos", 0.55)
	mat.set_shader_parameter("band4_pos", 0.8)
	mat.set_shader_parameter("band_sharpness", 20.0)
	mat.set_shader_parameter("line_density", 0.0)
	mat.set_shader_parameter("line_strength", 0.0)
	mat.set_shader_parameter("bevel_strength", 1.0)
	mat.set_shader_parameter("bevel_size", 1.8)
	mat.set_shader_parameter("bevel_light_color", Color(0.5, 0.7, 1.0))
	mat.set_shader_parameter("shadow_offset_x", 2.5)
	mat.set_shader_parameter("shadow_offset_y", 3.5)
	mat.set_shader_parameter("shadow_softness", 3.0)
	mat.set_shader_parameter("shadow_color", Color(0.0, 0.0, 0.15, 0.85))
	mat.set_shader_parameter("gleam_enabled", 0.0)
	mat.set_shader_parameter("specular_enabled", 1.0)
	mat.set_shader_parameter("specular_pos", 0.32)
	mat.set_shader_parameter("specular_width", 0.015)
	mat.set_shader_parameter("specular_intensity", 3.0)
	mat.set_shader_parameter("specular_color", Color(0.9, 0.95, 1.0, 1.0))
	mat.set_shader_parameter("hdr_boost", 1.5)
	title_label.material = mat
	title_label.add_theme_color_override("font_color", Color(0.4, 0.65, 1.0))


func _setup_synthwave_bg() -> void:
	var bg: ColorRect = $Background

	# ── Planet layer: SubViewport with its own bloom ──
	var vp := SubViewport.new()
	vp.size = Vector2i(
		int(ProjectSettings.get_setting("display/window/size/viewport_width")),
		int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	)
	vp.transparent_bg = false
	vp.use_hdr_2d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Own WorldEnvironment with bloom so ring/planet glow resolves here
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = true
	env.glow_intensity = ThemeManager.get_float("glow_intensity")
	env.glow_bloom = ThemeManager.get_float("glow_bloom")
	env.glow_hdr_threshold = ThemeManager.get_float("glow_hdr_threshold")
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	for i in 7:
		var val: float = ThemeManager.get_float("glow_level_%d" % i)
		env.set_glow_level(i, val > 0.5)
	world_env.environment = env
	vp.add_child(world_env)

	var planet_rect := ColorRect.new()
	planet_rect.color = Color.WHITE
	planet_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var planet_shader: Shader = load("res://assets/shaders/synthwave_planet.gdshader")
	if planet_shader:
		var planet_mat := ShaderMaterial.new()
		planet_mat.shader = planet_shader
		planet_rect.material = planet_mat
	vp.add_child(planet_rect)
	add_child(vp)
	move_child(vp, 0)

	# Show SubViewport via TextureRect behind everything
	var tex_rect := TextureRect.new()
	tex_rect.texture = vp.get_texture()
	tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(tex_rect)
	move_child(tex_rect, 1)

	# ── Grid layer: renders on root viewport (root bloom = grid-only) ──
	var grid_shader: Shader = load("res://assets/shaders/synthwave_bg.gdshader")
	if grid_shader:
		var grid_mat := ShaderMaterial.new()
		grid_mat.shader = grid_shader
		bg.material = grid_mat
		bg.color = Color(1.0, 1.0, 1.0, 1.0)
	# Move Background above the planet texture
	move_child(bg, 2)

	# ── Load saved settings, route to correct shader ──
	if FileAccess.file_exists(SW_SETTINGS_PATH):
		var f: FileAccess = FileAccess.open(SW_SETTINGS_PATH, FileAccess.READ)
		if f:
			var json := JSON.new()
			if json.parse(f.get_as_text()) == OK and json.data is Dictionary:
				var data: Dictionary = json.data as Dictionary
				var planet_mat: ShaderMaterial = planet_rect.material as ShaderMaterial
				var grid_mat: ShaderMaterial = bg.material as ShaderMaterial
				for key in data:
					var val: Variant = data[key]
					if val is Dictionary:
						var d: Dictionary = val as Dictionary
						if d.has("r"):
							val = Color(float(d["r"]), float(d["g"]), float(d["b"]))
					if planet_mat and key in _PLANET_PARAMS:
						planet_mat.set_shader_parameter(key, val)
					if grid_mat and (key not in _PLANET_PARAMS or key in _SHARED_PARAMS):
						grid_mat.set_shader_parameter(key, val)
			f.close()


func _apply_styles() -> void:
	for btn_node in $VBoxContainer.get_children():
		if btn_node is Button:
			var btn: Button = btn_node as Button
			ThemeManager.apply_button_style(btn)
			for state in ["normal", "hover", "pressed", "focus"]:
				var sb: StyleBox = btn.get_theme_stylebox(state)
				if sb and sb is StyleBoxFlat:
					var dark: StyleBoxFlat = (sb as StyleBoxFlat).duplicate() as StyleBoxFlat
					if state == "hover":
						dark.bg_color = Color(0.18, 0.18, 0.18, 0.95)
					elif state == "pressed":
						dark.bg_color = Color(0.12, 0.12, 0.12, 0.95)
					else:
						dark.bg_color = Color(0.06, 0.06, 0.06, 0.95)
					btn.add_theme_stylebox_override(state, dark)


func _setup_vhs_overlay() -> void:
	var vhs_layer := CanvasLayer.new()
	vhs_layer.layer = 10
	add_child(vhs_layer)
	_vhs_overlay = ColorRect.new()
	_vhs_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vhs_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vhs_layer.add_child(_vhs_overlay)
	ThemeManager.apply_vhs_overlay(_vhs_overlay)


func _on_theme_changed() -> void:
	ThemeManager.apply_vhs_overlay(_vhs_overlay)
	_apply_styles()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
