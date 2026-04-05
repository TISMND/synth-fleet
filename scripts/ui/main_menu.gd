extends Control
## Main menu with navigation to Play sub-menu, Options, Quit, and Dev Studio sub-menu.
## Menu music: all layers start muted, each unmutes on-beat at its configured start_bar.
## Music persists across menu screens — fades out only when entering gameplay.
##
## Background is split into rendering layers to prevent HDR bloom blowout.
## See SynthwaveBgSetup for the shared setup used across menu screens.

var _vhs_overlay: ColorRect
var _menu_loop_ids: Array[String] = []
var _menu_fade_ms: int = 2000


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

	# Load all arrangements, filter to in-rotation ones, pick random
	var arrangements: Array[MenuArrangement] = MenuArrangementManager.load_all()
	var eligible: Array[MenuArrangement] = []
	for a in arrangements:
		if a.in_rotation and a.tracks.size() > 0:
			eligible.append(a)
	if eligible.is_empty():
		return  # no menu music — menu is silent
	var chosen: MenuArrangement = eligible[randi() % eligible.size()]
	var bpm: float = chosen.bpm if chosen.bpm > 0.0 else 120.0
	var bar_dur: float = 60.0 / bpm * 4.0

	_menu_loop_ids.clear()
	var schedule: Array = []
	for i in range(chosen.tracks.size()):
		var tr: Dictionary = chosen.tracks[i]
		var file_path: String = str(tr.get("loop_path", ""))
		if file_path == "":
			continue
		if not FileAccess.file_exists(file_path) and not ResourceLoader.exists(file_path):
			push_warning("MenuMusic: missing audio file '%s'" % file_path)
			continue
		var loop_id: String = "menu_arr_%s_%d" % [chosen.id, i]
		var vol: float = float(tr.get("volume_db", 0.0))
		LoopMixer.add_loop(loop_id, file_path, "Master", vol, true)
		_menu_loop_ids.append(loop_id)
		schedule.append({
			"loop_id": loop_id,
			"start_sec": float(tr.get("start_bar", 0.0)) * bar_dur,
			"end_sec": float(tr.get("end_bar", 4.0)) * bar_dur,
			"fade_in_ms": int(float(tr.get("fade_in_bars", 0.0)) * bar_dur * 1000.0),
			"fade_out_ms": int(float(tr.get("fade_out_bars", 1.0)) * bar_dur * 1000.0),
			"infinite": bool(tr.get("infinite_loop", false)),
		})
	if _menu_loop_ids.size() > 0:
		LoopMixer.start_all()
		GameState.set_meta("menu_music_start_ticks", Time.get_ticks_msec())
		GameState.start_menu_arrangement(schedule)
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
	# Normal-from-alpha lighting — Deep Bulge Saturated preset.
	# 8-tap Sobel gradient on font alpha → pseudo-normal → Blinn-Phong.
	var shader: Shader = load("res://assets/shaders/title_3d_normal.gdshader")
	if not shader:
		return
	var mat := ShaderMaterial.new()
	mat.shader = shader
	# Front-Lit Chrome (light overhead) — auditions preset [A]
	mat.set_shader_parameter("base_color", Color(0.06, 0.12, 0.32, 1.0))
	mat.set_shader_parameter("highlight_color", Color(0.40, 0.65, 1.00, 1.0))
	mat.set_shader_parameter("specular_color", Color(1.0, 1.0, 1.0, 1.0))
	mat.set_shader_parameter("light_angle", 2.36)
	mat.set_shader_parameter("light_elevation", 0.92)
	mat.set_shader_parameter("ambient", 0.35)
	mat.set_shader_parameter("diffuse_strength", 0.95)
	mat.set_shader_parameter("specular_strength", 1.2)
	mat.set_shader_parameter("specular_power", 64.0)
	mat.set_shader_parameter("normal_sample_radius", 2.5)
	mat.set_shader_parameter("depth_scale", 3.0)
	mat.set_shader_parameter("hdr_boost", 1.0)
	title_label.material = mat
	title_label.add_theme_color_override("font_color", Color(0.4, 0.65, 1.0))


func _setup_synthwave_bg() -> void:
	SynthwaveBgSetup.setup(self)


func _apply_styles() -> void:
	for btn_node in $VBoxContainer.get_children():
		if btn_node is Button:
			var btn: Button = btn_node as Button
			ThemeManager.apply_button_style(btn)


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
