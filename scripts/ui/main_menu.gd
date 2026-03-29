extends Control
## Main menu with navigation to Play sub-menu, Options, Quit, and Dev Studio sub-menu.
## Menu music: all layers start muted, each unmutes on-beat at its configured start_bar.
## Music persists across menu screens — fades out only when entering gameplay.

var _vhs_overlay: ColorRect
var _menu_loop_ids: Array[String] = []
var _menu_fade_ms: int = 2000


func _ready() -> void:
	_setup_vhs_overlay()
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


func _apply_styles() -> void:
	for btn_node in $VBoxContainer.get_children():
		if btn_node is Button:
			ThemeManager.apply_button_style(btn_node as Button)


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
