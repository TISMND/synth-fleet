extends Control
## SFX Editor screen — two tabs: SFX (one-shot event sounds) and LOOPS (loop balancing).

var _config: SfxConfig
var _vhs_overlay: ColorRect
var _bg_rect: ColorRect
var _title_label: Label
var _back_button: Button
var _preview_player: AudioStreamPlayer
var _preview_tween: Tween

# Tab system
var _tab_sfx_btn: Button
var _tab_loops_btn: Button
var _sfx_content: ScrollContainer
var _loops_content: Control  # LoopBalancer instance
var _active_tab: int = 0  # 0 = SFX, 1 = LOOPS

# Per-event UI refs keyed by event ID
var _file_buttons: Dictionary = {}      # OptionButton
var _volume_sliders: Dictionary = {}    # HSlider
var _volume_labels: Dictionary = {}     # Label
var _clip_sliders: Dictionary = {}      # HSlider
var _clip_labels: Dictionary = {}       # Label
var _fade_sliders: Dictionary = {}      # HSlider
var _fade_labels: Dictionary = {}       # Label
var _preview_buttons: Dictionary = {}   # Button
var _event_labels: Dictionary = {}      # Label
var _section_headers: Array[Label] = []

var _sfx_files: Array[String] = []


func _ready() -> void:
	_config = SfxConfigManager.load_config()
	_sfx_files = _scan_sfx_files()
	_build_ui()
	_populate_from_config()
	ThemeManager.theme_changed.connect(_apply_theme)
	_apply_theme()


func _build_ui() -> void:
	# Grid background
	_bg_rect = ColorRect.new()
	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_rect)
	ThemeManager.apply_grid_background(_bg_rect)

	# VHS overlay
	var vhs_layer := CanvasLayer.new()
	vhs_layer.layer = 10
	add_child(vhs_layer)
	_vhs_overlay = ColorRect.new()
	_vhs_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vhs_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vhs_layer.add_child(_vhs_overlay)
	ThemeManager.apply_vhs_overlay(_vhs_overlay)

	# Preview audio player (for SFX tab)
	_preview_player = AudioStreamPlayer.new()
	add_child(_preview_player)

	# Top bar with title, tabs, and back button
	var top_bar := HBoxContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 20.0
	top_bar.offset_top = 10.0
	top_bar.offset_right = -20.0
	top_bar.offset_bottom = 50.0
	top_bar.add_theme_constant_override("separation", 12)
	add_child(top_bar)

	_title_label = Label.new()
	_title_label.text = "SFX EDITOR"
	top_bar.add_child(_title_label)

	# Tab buttons
	var tab_spacer := Control.new()
	tab_spacer.custom_minimum_size = Vector2(20, 0)
	top_bar.add_child(tab_spacer)

	_tab_sfx_btn = Button.new()
	_tab_sfx_btn.text = "SFX"
	_tab_sfx_btn.toggle_mode = true
	_tab_sfx_btn.button_pressed = true
	_tab_sfx_btn.pressed.connect(_on_tab_sfx)
	top_bar.add_child(_tab_sfx_btn)

	_tab_loops_btn = Button.new()
	_tab_loops_btn.text = "LOOPS"
	_tab_loops_btn.toggle_mode = true
	_tab_loops_btn.button_pressed = false
	_tab_loops_btn.pressed.connect(_on_tab_loops)
	top_bar.add_child(_tab_loops_btn)

	# Spacer to push BACK to the right
	var right_spacer := Control.new()
	right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(right_spacer)

	_back_button = Button.new()
	_back_button.text = "BACK"
	_back_button.pressed.connect(_on_back)
	top_bar.add_child(_back_button)

	# SFX content (scroll container)
	_sfx_content = ScrollContainer.new()
	_sfx_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sfx_content.offset_top = 60.0
	_sfx_content.offset_left = 20.0
	_sfx_content.offset_right = -20.0
	_sfx_content.offset_bottom = -20.0
	add_child(_sfx_content)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	_sfx_content.add_child(vbox)

	# Hit Sounds section
	_add_section_header(vbox, "HIT SOUNDS")
	for event_id in ["enemy_shield_hit", "enemy_hull_hit", "player_shield_hit", "player_hull_hit"]:
		_add_event_row(vbox, event_id)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	vbox.add_child(spacer)

	# Explosions section
	_add_section_header(vbox, "EXPLOSIONS")
	for event_id in ["explosion_1", "explosion_2", "explosion_3"]:
		_add_event_row(vbox, event_id)

	# Loops content (LoopBalancer panel — built from script)
	var loop_balancer_script: GDScript = load("res://scripts/ui/loop_balancer.gd") as GDScript
	_loops_content = Control.new()
	_loops_content.set_script(loop_balancer_script)
	_loops_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loops_content.offset_top = 60.0
	_loops_content.offset_left = 20.0
	_loops_content.offset_right = -20.0
	_loops_content.offset_bottom = -20.0
	_loops_content.visible = false
	add_child(_loops_content)


# --- Tab switching ---

func _on_tab_sfx() -> void:
	if _active_tab == 0:
		_tab_sfx_btn.button_pressed = true
		return
	_active_tab = 0
	_tab_sfx_btn.button_pressed = true
	_tab_loops_btn.button_pressed = false
	_sfx_content.visible = true
	_loops_content.visible = false
	# Stop loops preview when switching away
	if _loops_content.has_method("stop_preview"):
		_loops_content.stop_preview()


func _on_tab_loops() -> void:
	if _active_tab == 1:
		_tab_loops_btn.button_pressed = true
		return
	_active_tab = 1
	_tab_sfx_btn.button_pressed = false
	_tab_loops_btn.button_pressed = true
	_sfx_content.visible = false
	_loops_content.visible = true
	# Stop SFX preview when switching away
	if _preview_tween and _preview_tween.is_valid():
		_preview_tween.kill()
	_preview_player.stop()


func _add_section_header(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	parent.add_child(label)
	_section_headers.append(label)


func _add_event_row(parent: VBoxContainer, event_id: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	# Event label
	var label := Label.new()
	var display_name: String = SfxConfig.EVENT_LABELS.get(event_id, event_id)
	label.text = display_name
	label.custom_minimum_size = Vector2(180, 0)
	row.add_child(label)
	_event_labels[event_id] = label

	# File dropdown
	var file_btn := OptionButton.new()
	file_btn.custom_minimum_size = Vector2(200, 0)
	file_btn.add_item("(none)")
	for f in _sfx_files:
		file_btn.add_item(f.get_file())
	file_btn.item_selected.connect(_on_file_selected.bind(event_id))
	row.add_child(file_btn)
	_file_buttons[event_id] = file_btn

	# Volume slider
	var vol_label := Label.new()
	vol_label.text = "Vol:"
	vol_label.custom_minimum_size = Vector2(30, 0)
	row.add_child(vol_label)

	var vol_slider := HSlider.new()
	vol_slider.min_value = -40.0
	vol_slider.max_value = 6.0
	vol_slider.step = 0.5
	vol_slider.value = 0.0
	vol_slider.custom_minimum_size = Vector2(100, 0)
	vol_slider.value_changed.connect(_on_volume_changed.bind(event_id))
	row.add_child(vol_slider)
	_volume_sliders[event_id] = vol_slider

	var vol_val := Label.new()
	vol_val.text = "0.0 dB"
	vol_val.custom_minimum_size = Vector2(65, 0)
	row.add_child(vol_val)
	_volume_labels[event_id] = vol_val

	# Clip End slider
	var clip_label := Label.new()
	clip_label.text = "Clip:"
	clip_label.custom_minimum_size = Vector2(32, 0)
	row.add_child(clip_label)

	var clip_slider := HSlider.new()
	clip_slider.min_value = 0.0
	clip_slider.max_value = 10.0
	clip_slider.step = 0.01
	clip_slider.value = 0.0
	clip_slider.custom_minimum_size = Vector2(80, 0)
	clip_slider.editable = false
	clip_slider.value_changed.connect(_on_clip_changed.bind(event_id))
	row.add_child(clip_slider)
	_clip_sliders[event_id] = clip_slider

	var clip_val := Label.new()
	clip_val.text = "0.00s"
	clip_val.custom_minimum_size = Vector2(50, 0)
	row.add_child(clip_val)
	_clip_labels[event_id] = clip_val

	# Fade Out slider
	var fade_label := Label.new()
	fade_label.text = "Fade:"
	fade_label.custom_minimum_size = Vector2(36, 0)
	row.add_child(fade_label)

	var fade_slider := HSlider.new()
	fade_slider.min_value = 0.0
	fade_slider.max_value = 2.0
	fade_slider.step = 0.01
	fade_slider.value = 0.0
	fade_slider.custom_minimum_size = Vector2(80, 0)
	fade_slider.editable = false
	fade_slider.value_changed.connect(_on_fade_changed.bind(event_id))
	row.add_child(fade_slider)
	_fade_sliders[event_id] = fade_slider

	var fade_val := Label.new()
	fade_val.text = "0.00s"
	fade_val.custom_minimum_size = Vector2(50, 0)
	row.add_child(fade_val)
	_fade_labels[event_id] = fade_val

	# Preview button
	var preview_btn := Button.new()
	preview_btn.text = "\u25b6"
	preview_btn.disabled = true
	preview_btn.pressed.connect(_on_preview.bind(event_id))
	row.add_child(preview_btn)
	_preview_buttons[event_id] = preview_btn


func _populate_from_config() -> void:
	for event_id in SfxConfig.EVENT_IDS:
		var ev: Dictionary = _config.get_event(event_id)
		var file_path: String = ev["file_path"]

		# Set file dropdown
		var file_btn: OptionButton = _file_buttons[event_id]
		if file_path != "":
			var file_name: String = file_path.get_file()
			for i in file_btn.item_count:
				if file_btn.get_item_text(i) == file_name:
					file_btn.select(i)
					break

		# Set slider values
		var vol_slider: HSlider = _volume_sliders[event_id]
		vol_slider.value = float(ev["volume_db"])
		_update_volume_label(event_id)

		var has_file: bool = file_path != ""
		_update_sliders_enabled(event_id, has_file)

		if has_file:
			var stream_length: float = _get_stream_length(file_path)
			if stream_length > 0.0:
				var clip_slider: HSlider = _clip_sliders[event_id]
				clip_slider.max_value = stream_length

		var clip_slider: HSlider = _clip_sliders[event_id]
		clip_slider.value = float(ev["clip_end_time"])
		_update_clip_label(event_id)

		var fade_slider: HSlider = _fade_sliders[event_id]
		fade_slider.value = float(ev["fade_out_duration"])
		_update_fade_label(event_id)


func _scan_sfx_files() -> Array[String]:
	var files: Array[String] = []
	var dir := DirAccess.open("res://assets/audio/sfx/")
	if dir == null:
		return files
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var lower: String = file_name.to_lower()
			if lower.ends_with(".wav") or lower.ends_with(".ogg"):
				files.append("res://assets/audio/sfx/" + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	files.sort()
	return files


func _get_stream_length(file_path: String) -> float:
	if file_path == "":
		return 0.0
	var stream: AudioStream = load(file_path) as AudioStream
	if stream == null:
		return 0.0
	return stream.get_length()


func _file_path_for_event(event_id: String) -> String:
	var file_btn: OptionButton = _file_buttons[event_id]
	var idx: int = file_btn.selected
	if idx <= 0:
		return ""
	var file_name: String = file_btn.get_item_text(idx)
	return "res://assets/audio/sfx/" + file_name


func _update_sliders_enabled(event_id: String, has_file: bool) -> void:
	var clip_slider: HSlider = _clip_sliders[event_id]
	var fade_slider: HSlider = _fade_sliders[event_id]
	var preview_btn: Button = _preview_buttons[event_id]
	clip_slider.editable = has_file
	fade_slider.editable = has_file
	preview_btn.disabled = not has_file


func _update_volume_label(event_id: String) -> void:
	var slider: HSlider = _volume_sliders[event_id]
	var label: Label = _volume_labels[event_id]
	label.text = "%.1f dB" % slider.value


func _update_clip_label(event_id: String) -> void:
	var slider: HSlider = _clip_sliders[event_id]
	var label: Label = _clip_labels[event_id]
	label.text = "%.2fs" % slider.value


func _update_fade_label(event_id: String) -> void:
	var slider: HSlider = _fade_sliders[event_id]
	var label: Label = _fade_labels[event_id]
	label.text = "%.2fs" % slider.value


# --- Signal handlers ---

func _on_file_selected(idx: int, event_id: String) -> void:
	var file_path: String = _file_path_for_event(event_id)
	var has_file: bool = file_path != ""

	var ev: Dictionary = _config.get_event(event_id)
	ev["file_path"] = file_path

	_update_sliders_enabled(event_id, has_file)

	if has_file:
		var stream_length: float = _get_stream_length(file_path)
		if stream_length > 0.0:
			var clip_slider: HSlider = _clip_sliders[event_id]
			clip_slider.max_value = stream_length
			if clip_slider.value == 0.0 or clip_slider.value > stream_length:
				clip_slider.value = 0.0
	else:
		var clip_slider: HSlider = _clip_sliders[event_id]
		clip_slider.value = 0.0
		var fade_slider: HSlider = _fade_sliders[event_id]
		fade_slider.value = 0.0

	_auto_save()


func _on_volume_changed(value: float, event_id: String) -> void:
	var ev: Dictionary = _config.get_event(event_id)
	ev["volume_db"] = value
	_update_volume_label(event_id)
	_auto_save()


func _on_clip_changed(value: float, event_id: String) -> void:
	var ev: Dictionary = _config.get_event(event_id)
	ev["clip_end_time"] = value
	_update_clip_label(event_id)
	_auto_save()


func _on_fade_changed(value: float, event_id: String) -> void:
	var ev: Dictionary = _config.get_event(event_id)
	ev["fade_out_duration"] = value
	_update_fade_label(event_id)
	_auto_save()


func _on_preview(event_id: String) -> void:
	var ev: Dictionary = _config.get_event(event_id)
	var file_path: String = ev["file_path"]
	if file_path == "":
		return

	var stream: AudioStream = load(file_path) as AudioStream
	if stream == null:
		return

	# Kill any active preview
	if _preview_tween and _preview_tween.is_valid():
		_preview_tween.kill()
	_preview_player.stop()

	_preview_player.stream = stream
	var vol_db: float = ev["volume_db"]
	_preview_player.volume_db = vol_db
	_preview_player.play()

	var clip_end: float = ev["clip_end_time"]
	var fade_dur: float = ev["fade_out_duration"]
	var stream_length: float = stream.get_length()

	# Determine effective end time
	var end_time: float = stream_length
	if clip_end > 0.0 and clip_end < stream_length:
		end_time = clip_end

	if fade_dur > 0.0 and fade_dur < end_time:
		# Wait until fade start, then tween volume down, then stop
		var fade_start: float = end_time - fade_dur
		_preview_tween = create_tween()
		_preview_tween.tween_interval(fade_start)
		_preview_tween.tween_property(_preview_player, "volume_db", -60.0, fade_dur)
		_preview_tween.tween_callback(_preview_player.stop)
		_preview_tween.tween_callback(func() -> void: _preview_player.volume_db = vol_db)
	elif clip_end > 0.0 and clip_end < stream_length:
		# Just stop at clip end
		_preview_tween = create_tween()
		_preview_tween.tween_interval(end_time)
		_preview_tween.tween_callback(_preview_player.stop)


func _on_back() -> void:
	if _preview_tween and _preview_tween.is_valid():
		_preview_tween.kill()
	_preview_player.stop()
	if _loops_content and _loops_content.has_method("stop_preview"):
		_loops_content.stop_preview()
	get_tree().change_scene_to_file("res://scenes/ui/dev_studio_menu.tscn")


func _auto_save() -> void:
	SfxConfigManager.save(_config)
	SfxPlayer.reload()


# --- Theming ---

func _apply_theme() -> void:
	if _bg_rect:
		ThemeManager.apply_grid_background(_bg_rect)
	if _vhs_overlay:
		ThemeManager.apply_vhs_overlay(_vhs_overlay)
	if _title_label:
		ThemeManager.apply_text_glow(_title_label, "header")
	if _back_button:
		ThemeManager.apply_button_style(_back_button)
	if _tab_sfx_btn:
		ThemeManager.apply_button_style(_tab_sfx_btn)
	if _tab_loops_btn:
		ThemeManager.apply_button_style(_tab_loops_btn)
	for header in _section_headers:
		if is_instance_valid(header):
			ThemeManager.apply_text_glow(header, "header")
	for event_id in SfxConfig.EVENT_IDS:
		if _event_labels.has(event_id):
			var label: Label = _event_labels[event_id]
			ThemeManager.apply_text_glow(label, "body")
		if _preview_buttons.has(event_id):
			var btn: Button = _preview_buttons[event_id]
			ThemeManager.apply_button_style(btn)
	# Theme the loops tab content
	if _loops_content and _loops_content.has_method("apply_theme"):
		_loops_content.apply_theme()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
