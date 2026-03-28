extends Control
## SFX Editor screen — three tabs: SFX (one-shot event sounds), LOOPS (loop balancing), EVENTS (timeline).

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
var _tab_events_btn: Button
var _tab_menu_btn: Button
var _sfx_content: ScrollContainer
var _loops_content: Control  # LoopBalancer instance
var _events_content: Control  # PowerLossTimeline instance
var _menu_content: ScrollContainer  # Menu music layer editor
var _active_tab: int = 0  # 0 = SFX, 1 = LOOPS, 2 = EVENTS, 3 = MENU

# Menu music editor state
var _menu_config: Dictionary = {}
var _menu_layer_container: VBoxContainer
var _menu_fade_slider: HSlider
var _menu_fade_label: Label
var _menu_browsers: Array = []  # Array of {browser: LoopBrowser, vol_slider: HSlider, bar_spin: SpinBox, active_check: CheckBox, id: String}
# Menu music preview playback
var _menu_preview_active: bool = false
var _menu_preview_elapsed: float = 0.0
var _menu_preview_bar_dur: float = 2.0
var _menu_preview_loop_ids: Array[String] = []
var _menu_preview_start_bars: Dictionary = {}  # loop_id -> int
var _menu_preview_unmuted: Dictionary = {}  # loop_id -> bool
var _menu_preview_btn: Button

# Per-event UI refs keyed by event ID
var _file_buttons: Dictionary = {}      # OptionButton
var _volume_sliders: Dictionary = {}    # HSlider
var _volume_labels: Dictionary = {}     # Label
var _clip_sliders: Dictionary = {}      # HSlider
var _clip_labels: Dictionary = {}       # Label
var _fade_in_sliders: Dictionary = {}    # HSlider
var _fade_in_labels: Dictionary = {}    # Label
var _fade_sliders: Dictionary = {}      # HSlider (fade out)
var _fade_labels: Dictionary = {}       # Label (fade out)
var _preview_buttons: Dictionary = {}   # Button
var _event_labels: Dictionary = {}      # Label
var _section_headers: Array[Label] = []

var _sfx_files: Array[String] = []
var _sfx_by_category: Dictionary = {}  # category -> Array[String]
var _sfx_categories: Array[String] = []
var _category_filter: OptionButton  # Global filter at top of SFX tab
var _active_category: String = "ALL"


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
	_bg_rect.color = Color(0.02, 0.02, 0.03, 1.0)
	add_child(_bg_rect)

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

	_tab_events_btn = Button.new()
	_tab_events_btn.text = "EVENTS"
	_tab_events_btn.toggle_mode = true
	_tab_events_btn.button_pressed = false
	_tab_events_btn.pressed.connect(_on_tab_events)
	top_bar.add_child(_tab_events_btn)

	_tab_menu_btn = Button.new()
	_tab_menu_btn.text = "MENU"
	_tab_menu_btn.toggle_mode = true
	_tab_menu_btn.button_pressed = false
	_tab_menu_btn.pressed.connect(_on_tab_menu)
	top_bar.add_child(_tab_menu_btn)

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

	# Category filter — subfolders in assets/audio/sfx/ become filter tags
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 8)
	vbox.add_child(filter_row)
	var filter_lbl := Label.new()
	filter_lbl.text = "SFX Folder Filter:"
	filter_lbl.custom_minimum_size = Vector2(130, 0)
	filter_row.add_child(filter_lbl)
	_category_filter = OptionButton.new()
	_category_filter.custom_minimum_size = Vector2(180, 0)
	_category_filter.add_item("ALL")
	for cat in _sfx_categories:
		_category_filter.add_item(cat)
	_category_filter.item_selected.connect(_on_category_filter_changed)
	filter_row.add_child(_category_filter)

	var filter_spacer := Control.new()
	filter_spacer.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(filter_spacer)

	# Hit Sounds section
	_add_section_header(vbox, "HIT SOUNDS", "Projectile and contact impacts — shield vs hull variants for both player and enemies")
	for event_id in ["enemy_shield_hit", "enemy_hull_hit", "player_shield_hit", "player_hull_hit", "immune_hit"]:
		_add_event_row(vbox, event_id)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	vbox.add_child(spacer)

	# Explosions section
	_add_section_header(vbox, "EXPLOSIONS", "Enemy death explosions — size tiers from small drones to bosses")
	for event_id in ["explosion_1", "explosion_2", "explosion_3"]:
		_add_event_row(vbox, event_id)

	var spacer_2 := Control.new()
	spacer_2.custom_minimum_size = Vector2(0, 12)
	vbox.add_child(spacer_2)

	# Warning alarms section
	_add_section_header(vbox, "WARNING ALARMS", "Loop while warning condition is active — stop when condition clears")
	for event_id in ["alarm_heat", "alarm_fire", "alarm_low_power", "alarm_overdraw", "alarm_shields_low", "alarm_hull_damaged", "alarm_hull_critical"]:
		_add_event_row(vbox, event_id)

	var spacer_3 := Control.new()
	spacer_3.custom_minimum_size = Vector2(0, 12)
	vbox.add_child(spacer_3)

	# Boss transition section
	_add_section_header(vbox, "BOSS TRANSITION", "Cues during the boss approach sequence — disruption wave, music breakdown, remodulation")
	for event_id in ["boss_wave_sweep", "boss_wave_hit", "boss_music_degrade", "boss_silence", "boss_music_bleed", "boss_warning", "boss_typing_thunk", "boss_remodulate", "boss_weapons_online", "boss_control_restored", "boss_transition_end"]:
		_add_event_row(vbox, event_id)

	# Power loss events (power failure, reboot, power-down, power-up) are managed
	# exclusively in the EVENTS tab timeline — not shown here.

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

	# Events content (PowerLossTimeline panel — built from script)
	var timeline_script: GDScript = load("res://scripts/ui/power_loss_timeline.gd") as GDScript
	_events_content = Control.new()
	_events_content.set_script(timeline_script)
	_events_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_events_content.offset_top = 60.0
	_events_content.offset_left = 20.0
	_events_content.offset_right = -20.0
	_events_content.offset_bottom = -20.0
	_events_content.visible = false
	add_child(_events_content)

	# Menu music content
	_menu_content = ScrollContainer.new()
	_menu_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_content.offset_top = 60.0
	_menu_content.offset_left = 20.0
	_menu_content.offset_right = -20.0
	_menu_content.offset_bottom = -20.0
	_menu_content.visible = false
	add_child(_menu_content)
	_build_menu_tab()


# --- Tab switching ---

func _switch_sfx_tab(idx: int) -> void:
	_active_tab = idx
	_tab_sfx_btn.button_pressed = (idx == 0)
	_tab_loops_btn.button_pressed = (idx == 1)
	_tab_events_btn.button_pressed = (idx == 2)
	_tab_menu_btn.button_pressed = (idx == 3)
	_sfx_content.visible = (idx == 0)
	_loops_content.visible = (idx == 1)
	_events_content.visible = (idx == 2)
	_menu_content.visible = (idx == 3)
	# Stop previews on non-active tabs
	if idx != 0:
		if _preview_tween and _preview_tween.is_valid():
			_preview_tween.kill()
		_preview_player.stop()
	if idx != 1 and _loops_content.has_method("stop_preview"):
		_loops_content.stop_preview()
	if idx != 2 and _events_content.has_method("stop_playback"):
		_events_content.stop_playback()
	if idx != 3:
		_stop_menu_preview()


func _on_tab_sfx() -> void:
	if _active_tab == 0:
		_tab_sfx_btn.button_pressed = true
		return
	_switch_sfx_tab(0)


func _on_tab_loops() -> void:
	if _active_tab == 1:
		_tab_loops_btn.button_pressed = true
		return
	_switch_sfx_tab(1)


func _on_tab_events() -> void:
	if _active_tab == 2:
		_tab_events_btn.button_pressed = true
		return
	_switch_sfx_tab(2)


func _on_tab_menu() -> void:
	if _active_tab == 3:
		_tab_menu_btn.button_pressed = true
		return
	_switch_sfx_tab(3)


func _add_section_header(parent: VBoxContainer, text: String, description: String = "") -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	if description != "":
		label.tooltip_text = description
		label.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(label)
	_section_headers.append(label)


func _add_event_row(parent: VBoxContainer, event_id: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	# Event label with tooltip description
	var label := Label.new()
	var display_name: String = SfxConfig.EVENT_LABELS.get(event_id, event_id)
	label.text = display_name
	label.custom_minimum_size = Vector2(180, 0)
	var desc: String = SfxConfig.EVENT_DESCRIPTIONS.get(event_id, "")
	if desc != "":
		label.tooltip_text = desc
		label.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(label)
	_event_labels[event_id] = label

	# File dropdown — shows files filtered by active category
	var file_btn := OptionButton.new()
	file_btn.custom_minimum_size = Vector2(280, 0)
	_populate_file_dropdown(file_btn)
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

	# Fade In slider
	var fade_in_label := Label.new()
	fade_in_label.text = "FdIn:"
	fade_in_label.custom_minimum_size = Vector2(36, 0)
	row.add_child(fade_in_label)

	var fade_in_slider := HSlider.new()
	fade_in_slider.min_value = 0.0
	fade_in_slider.max_value = 5.0
	fade_in_slider.step = 0.01
	fade_in_slider.value = 0.0
	fade_in_slider.custom_minimum_size = Vector2(80, 0)
	fade_in_slider.editable = false
	fade_in_slider.value_changed.connect(_on_fade_in_changed.bind(event_id))
	row.add_child(fade_in_slider)
	_fade_in_sliders[event_id] = fade_in_slider

	var fade_in_val := Label.new()
	fade_in_val.text = "0.00s"
	fade_in_val.custom_minimum_size = Vector2(50, 0)
	row.add_child(fade_in_val)
	_fade_in_labels[event_id] = fade_in_val

	# Fade Out slider
	var fade_label := Label.new()
	fade_label.text = "FdOut:"
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

	# Preview / Stop buttons
	var preview_btn := Button.new()
	preview_btn.text = "\u25b6"
	preview_btn.disabled = true
	preview_btn.pressed.connect(_on_preview.bind(event_id))
	row.add_child(preview_btn)
	_preview_buttons[event_id] = preview_btn

	var stop_btn := Button.new()
	stop_btn.text = "\u25a0"
	stop_btn.pressed.connect(_on_stop_preview)
	row.add_child(stop_btn)


func _populate_from_config() -> void:
	for event_id in SfxConfig.EVENT_IDS:
		if not _file_buttons.has(event_id):
			continue  # Event not shown in editor — skip
		var ev: Dictionary = _config.get_event(event_id)
		var file_path: String = ev["file_path"]

		# Set file dropdown — match by full path in metadata
		var file_btn: OptionButton = _file_buttons[event_id]
		if file_path != "":
			for i in range(1, file_btn.item_count):
				if str(file_btn.get_item_metadata(i)) == file_path:
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

		var fade_in_slider: HSlider = _fade_in_sliders[event_id]
		fade_in_slider.value = float(ev["fade_in_duration"])
		_update_fade_in_label(event_id)

		var fade_slider: HSlider = _fade_sliders[event_id]
		fade_slider.value = float(ev["fade_out_duration"])
		_update_fade_label(event_id)


func _scan_sfx_files() -> Array[String]:
	## Scans res://assets/audio/sfx/ including subfolders.
	## Subfolders become categories (tags). Root files go in "uncategorized".
	var all_files: Array[String] = []
	_sfx_by_category.clear()
	_sfx_categories.clear()
	var root_path: String = "res://assets/audio/sfx/"
	var dir := DirAccess.open(root_path)
	if dir == null:
		return all_files
	# Scan root files
	var root_files: Array[String] = []
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			# Subfolder = category
			var cat_files: Array[String] = []
			_scan_sfx_folder(root_path + entry + "/", cat_files)
			if cat_files.size() > 0:
				cat_files.sort()
				_sfx_categories.append(entry)
				_sfx_by_category[entry] = cat_files
				all_files.append_array(cat_files)
		elif not dir.current_is_dir():
			var lower: String = entry.to_lower()
			if lower.ends_with(".wav") or lower.ends_with(".ogg"):
				root_files.append(root_path + entry)
		entry = dir.get_next()
	dir.list_dir_end()
	if root_files.size() > 0:
		root_files.sort()
		_sfx_categories.insert(0, "uncategorized")
		_sfx_by_category["uncategorized"] = root_files
		all_files.append_array(root_files)
	_sfx_categories.sort()
	all_files.sort()
	return all_files


func _scan_sfx_folder(path: String, results: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			var lower: String = fname.to_lower()
			if lower.ends_with(".wav") or lower.ends_with(".ogg"):
				results.append(path + fname)
		fname = dir.get_next()
	dir.list_dir_end()


func _get_stream_length(file_path: String) -> float:
	if file_path == "":
		return 0.0
	var stream: AudioStream = load(file_path) as AudioStream
	if stream == null:
		return 0.0
	return stream.get_length()


func _populate_file_dropdown(btn: OptionButton) -> void:
	btn.clear()
	btn.add_item("(none)")
	var files: Array[String] = _get_filtered_files()
	for f in files:
		# Show "category/filename" for subfolder files, just "filename" for root
		var display: String = f.replace("res://assets/audio/sfx/", "")
		var item_idx: int = btn.item_count
		btn.add_item(display)
		btn.set_item_metadata(item_idx, f)


func _get_filtered_files() -> Array[String]:
	if _active_category == "ALL":
		return _sfx_files
	if _sfx_by_category.has(_active_category):
		var cat_files: Array = _sfx_by_category[_active_category]
		var result: Array[String] = []
		for f in cat_files:
			result.append(str(f))
		return result
	return _sfx_files


func _on_category_filter_changed(idx: int) -> void:
	if idx <= 0:
		_active_category = "ALL"
	else:
		_active_category = _category_filter.get_item_text(idx)
	# Rebuild all file dropdowns with the new filter, preserving selections.
	# If the assigned file isn't in the filtered set, add it as a special entry
	# so the dropdown doesn't clear to "(none)".
	for event_id in _file_buttons:
		var btn: OptionButton = _file_buttons[event_id]
		var ev: Dictionary = _config.get_event(event_id)
		var saved_path: String = str(ev.get("file_path", ""))
		# Block signal during rebuild so clear() doesn't fire _on_file_selected
		btn.set_block_signals(true)
		_populate_file_dropdown(btn)
		if saved_path != "":
			var found: bool = false
			for i in range(1, btn.item_count):
				if str(btn.get_item_metadata(i)) == saved_path:
					btn.selected = i
					found = true
					break
			if not found:
				var display: String = saved_path.replace("res://assets/audio/sfx/", "")
				var pinned_idx: int = btn.item_count
				btn.add_item(display + " (current)")
				btn.set_item_metadata(pinned_idx, saved_path)
				btn.selected = pinned_idx
		btn.set_block_signals(false)


func _file_path_for_event(event_id: String) -> String:
	var file_btn: OptionButton = _file_buttons[event_id]
	var idx: int = file_btn.selected
	if idx <= 0:
		return ""
	# Full path stored as metadata on each item
	return str(file_btn.get_item_metadata(idx))


func _update_sliders_enabled(event_id: String, has_file: bool) -> void:
	var clip_slider: HSlider = _clip_sliders[event_id]
	var fade_in_slider: HSlider = _fade_in_sliders[event_id]
	var fade_slider: HSlider = _fade_sliders[event_id]
	var preview_btn: Button = _preview_buttons[event_id]
	clip_slider.editable = has_file
	fade_in_slider.editable = has_file
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


func _update_fade_in_label(event_id: String) -> void:
	var slider: HSlider = _fade_in_sliders[event_id]
	var label: Label = _fade_in_labels[event_id]
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
		var fade_in_slider: HSlider = _fade_in_sliders[event_id]
		fade_in_slider.value = 0.0
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


func _on_fade_in_changed(value: float, event_id: String) -> void:
	var ev: Dictionary = _config.get_event(event_id)
	ev["fade_in_duration"] = value
	_update_fade_in_label(event_id)
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


func _on_stop_preview() -> void:
	if _preview_tween and _preview_tween.is_valid():
		_preview_tween.kill()
	_preview_player.stop()


# --- Menu music tab ---

func _build_menu_tab() -> void:
	_menu_config = MenuMusicConfigManager.load_config()
	_menu_browsers.clear()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_content.add_child(vbox)

	var header := Label.new()
	header.text = "MENU MUSIC LAYERS"
	vbox.add_child(header)

	var desc := Label.new()
	desc.text = "Build up a layered menu song. Each layer unmutes at its Start Bar for a staggered buildup. All loops play from bar 1 simultaneously."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	# BPM
	var bpm_row := HBoxContainer.new()
	bpm_row.add_theme_constant_override("separation", 8)
	vbox.add_child(bpm_row)
	var bpm_lbl := Label.new()
	bpm_lbl.text = "BPM"
	bpm_lbl.custom_minimum_size.x = 120
	bpm_row.add_child(bpm_lbl)
	var bpm_slider := HSlider.new()
	bpm_slider.min_value = 60
	bpm_slider.max_value = 200
	bpm_slider.step = 1
	bpm_slider.value = float(_menu_config.get("bpm", 120))
	bpm_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bpm_row.add_child(bpm_slider)
	var bpm_val := Label.new()
	bpm_val.text = str(int(bpm_slider.value))
	bpm_val.custom_minimum_size.x = 40
	bpm_row.add_child(bpm_val)
	bpm_slider.value_changed.connect(func(v: float):
		bpm_val.text = str(int(v))
		_save_menu_config()
	)
	# Store ref for _save_menu_config
	bpm_slider.set_meta("is_bpm", true)
	vbox.set_meta("bpm_slider", bpm_slider)

	# Fade out duration
	var fade_row := HBoxContainer.new()
	fade_row.add_theme_constant_override("separation", 8)
	vbox.add_child(fade_row)
	var fade_lbl := Label.new()
	fade_lbl.text = "Fade Out (ms)"
	fade_lbl.custom_minimum_size.x = 120
	fade_row.add_child(fade_lbl)
	_menu_fade_slider = HSlider.new()
	_menu_fade_slider.min_value = 0
	_menu_fade_slider.max_value = 5000
	_menu_fade_slider.step = 100
	_menu_fade_slider.value = float(_menu_config.get("fade_out_duration_ms", 2000))
	_menu_fade_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_fade_slider.value_changed.connect(_on_menu_fade_changed)
	fade_row.add_child(_menu_fade_slider)
	_menu_fade_label = Label.new()
	_menu_fade_label.text = str(int(_menu_fade_slider.value)) + "ms"
	_menu_fade_label.custom_minimum_size.x = 60
	fade_row.add_child(_menu_fade_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Layer list container
	_menu_layer_container = VBoxContainer.new()
	_menu_layer_container.add_theme_constant_override("separation", 16)
	vbox.add_child(_menu_layer_container)

	# Populate existing layers
	var layers: Array = _menu_config.get("layers", []) as Array
	for layer in layers:
		_add_menu_layer(layer as Dictionary)

	# Button row
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	var add_btn := Button.new()
	add_btn.text = "+ ADD LAYER"
	add_btn.pressed.connect(_on_add_menu_layer)
	btn_row.add_child(add_btn)

	_menu_preview_btn = Button.new()
	_menu_preview_btn.text = "PREVIEW BUILDUP"
	_menu_preview_btn.pressed.connect(_on_menu_preview_toggle)
	btn_row.add_child(_menu_preview_btn)


func _add_menu_layer(layer_data: Dictionary) -> void:
	var layer_idx: int = _menu_browsers.size()
	var layer_id: String = str(layer_data.get("id", "menu_layer_" + str(layer_idx)))
	var file_path: String = str(layer_data.get("file_path", ""))

	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 6)
	_menu_layer_container.add_child(panel)

	# Header row: layer label + active toggle + mute button + remove
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	panel.add_child(header_row)

	var layer_label := Label.new()
	layer_label.text = "LAYER " + str(layer_idx + 1)
	header_row.add_child(layer_label)

	var active_check := CheckBox.new()
	active_check.text = "Active on menu start"
	active_check.button_pressed = bool(layer_data.get("default_active", true))
	active_check.toggled.connect(func(_b: bool): _save_menu_config())
	header_row.add_child(active_check)

	var mute_btn := Button.new()
	mute_btn.text = "MUTE"
	mute_btn.toggle_mode = true
	var audition_id: String = "menu_audition_" + str(layer_idx)
	mute_btn.pressed.connect(func():
		if LoopMixer.has_loop(audition_id):
			if LoopMixer.is_muted(audition_id):
				LoopMixer.unmute(audition_id, 200)
				mute_btn.text = "MUTE"
			else:
				LoopMixer.mute(audition_id, 200)
				mute_btn.text = "UNMUTE"
	)
	header_row.add_child(mute_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(spacer)

	var remove_btn := Button.new()
	remove_btn.text = "REMOVE"
	remove_btn.pressed.connect(func():
		# Stop audition loop
		if LoopMixer.has_loop(audition_id):
			LoopMixer.release_loop(audition_id, 100)
		# Remove from arrays
		for i in range(_menu_browsers.size()):
			var entry: Dictionary = _menu_browsers[i]
			if str(entry.get("id", "")) == layer_id:
				_menu_browsers.remove_at(i)
				break
		panel.queue_free()
		call_deferred("_save_menu_config")
	)
	header_row.add_child(remove_btn)

	# Start bar + Volume row
	var settings_row := HBoxContainer.new()
	settings_row.add_theme_constant_override("separation", 16)
	panel.add_child(settings_row)

	var bar_lbl := Label.new()
	bar_lbl.text = "Start Bar"
	settings_row.add_child(bar_lbl)
	var bar_spin := SpinBox.new()
	bar_spin.min_value = 0
	bar_spin.max_value = 32
	bar_spin.step = 1
	bar_spin.value = int(layer_data.get("start_bar", 0))
	bar_spin.custom_minimum_size = Vector2(80, 0)
	bar_spin.value_changed.connect(func(_v: float): _save_menu_config())
	settings_row.add_child(bar_spin)

	var vol_lbl := Label.new()
	vol_lbl.text = "Volume"
	settings_row.add_child(vol_lbl)
	var vol_slider := HSlider.new()
	vol_slider.min_value = -20.0
	vol_slider.max_value = 6.0
	vol_slider.step = 0.5
	vol_slider.value = float(layer_data.get("volume_db", 0.0))
	vol_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_row.add_child(vol_slider)
	var vol_val := Label.new()
	vol_val.text = str(snapped(vol_slider.value, 0.5)) + "dB"
	vol_val.custom_minimum_size.x = 50
	settings_row.add_child(vol_val)
	vol_slider.value_changed.connect(func(v: float):
		vol_val.text = str(snapped(v, 0.5)) + "dB"
		_save_menu_config()
	)

	# LoopBrowser — same component used by weapons tab
	var browser := LoopBrowser.new()
	browser._audition_id = audition_id
	browser.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(browser)

	# Select the saved path if we have one
	if file_path != "":
		browser.call_deferred("select_path", file_path)

	# Wire loop_selected to auto-save
	browser.loop_selected.connect(func(_path: String, _cat: String): _save_menu_config())

	# Separator
	var line := HSeparator.new()
	panel.add_child(line)

	_menu_browsers.append({
		"id": layer_id,
		"browser": browser,
		"vol_slider": vol_slider,
		"bar_spin": bar_spin,
		"active_check": active_check,
		"panel": panel,
		"audition_id": audition_id,
	})


func _on_add_menu_layer() -> void:
	var idx: int = _menu_browsers.size()
	var data: Dictionary = {"id": "menu_layer_" + str(idx), "file_path": "", "volume_db": 0.0, "default_active": true, "start_bar": 0}
	_add_menu_layer(data)
	_save_menu_config()


func _on_menu_fade_changed(val: float) -> void:
	_menu_fade_label.text = str(int(val)) + "ms"
	_save_menu_config()


func _save_menu_config() -> void:
	var layers: Array = []
	for entry in _menu_browsers:
		if not is_instance_valid(entry.get("browser")):
			continue
		var browser: LoopBrowser = entry["browser"] as LoopBrowser
		var vol_slider: HSlider = entry["vol_slider"] as HSlider
		var bar_spin: SpinBox = entry["bar_spin"] as SpinBox
		var active_check: CheckBox = entry["active_check"] as CheckBox
		var file_path: String = browser.get_selected_path()
		layers.append({
			"id": str(entry.get("id", "")),
			"file_path": file_path,
			"volume_db": vol_slider.value,
			"start_bar": int(bar_spin.value),
			"default_active": active_check.button_pressed,
		})
	# Get BPM from the slider stored on the parent vbox
	var bpm: int = 120
	if _menu_layer_container and _menu_layer_container.get_parent():
		var parent_vbox: Node = _menu_layer_container.get_parent()
		if parent_vbox.has_meta("bpm_slider"):
			var bpm_slider: HSlider = parent_vbox.get_meta("bpm_slider") as HSlider
			bpm = int(bpm_slider.value)
	var config: Dictionary = {
		"bpm": bpm,
		"layers": layers,
		"fade_out_duration_ms": int(_menu_fade_slider.value),
	}
	MenuMusicConfigManager.save_config(config)


func _process(delta: float) -> void:
	if not _menu_preview_active:
		return
	_menu_preview_elapsed += delta
	var current_bar: int = int(_menu_preview_elapsed / _menu_preview_bar_dur)
	for loop_id in _menu_preview_start_bars:
		if bool(_menu_preview_unmuted.get(loop_id, false)):
			continue
		var start_bar: int = int(_menu_preview_start_bars[loop_id])
		if current_bar >= start_bar:
			var bar_pos: float = fmod(_menu_preview_elapsed, _menu_preview_bar_dur)
			if bar_pos < delta * 2.0 or current_bar > start_bar:
				LoopMixer.unmute(loop_id, 100)
				_menu_preview_unmuted[loop_id] = true


func _on_menu_preview_toggle() -> void:
	if _menu_preview_active:
		_stop_menu_preview()
	else:
		_start_menu_preview()


func _start_menu_preview() -> void:
	_stop_menu_preview()
	# Stop all LoopBrowser audition loops so they don't clash
	for entry in _menu_browsers:
		var aud_id: String = str(entry.get("audition_id", ""))
		if aud_id != "" and LoopMixer.has_loop(aud_id):
			LoopMixer.mute(aud_id, 50)

	_save_menu_config()
	var config: Dictionary = MenuMusicConfigManager.load_config()
	var bpm: float = float(config.get("bpm", 120.0))
	_menu_preview_bar_dur = 60.0 / maxf(bpm, 1.0) * 4.0
	_menu_preview_elapsed = 0.0
	_menu_preview_loop_ids.clear()
	_menu_preview_start_bars.clear()
	_menu_preview_unmuted.clear()

	var layers: Array = config.get("layers", []) as Array
	for layer in layers:
		var d: Dictionary = layer as Dictionary
		var lid: String = "menu_preview_" + str(d.get("id", ""))
		var file_path: String = str(d.get("file_path", ""))
		var vol: float = float(d.get("volume_db", 0.0))
		var start_bar: int = int(d.get("start_bar", 0))
		if file_path == "" or not FileAccess.file_exists(file_path):
			continue
		LoopMixer.add_loop(lid, file_path, "Master", vol, true)
		_menu_preview_loop_ids.append(lid)
		_menu_preview_start_bars[lid] = start_bar
		_menu_preview_unmuted[lid] = false
	if _menu_preview_loop_ids.size() > 0:
		LoopMixer.start_all()
		_menu_preview_active = true
		_menu_preview_btn.text = "STOP PREVIEW"


func _stop_menu_preview() -> void:
	_menu_preview_active = false
	for loop_id in _menu_preview_loop_ids:
		if LoopMixer.has_loop(loop_id):
			LoopMixer.release_loop(loop_id, 100)
	_menu_preview_loop_ids.clear()
	_menu_preview_start_bars.clear()
	_menu_preview_unmuted.clear()
	if _menu_preview_btn:
		_menu_preview_btn.text = "PREVIEW BUILDUP"


func _on_back() -> void:
	if _preview_tween and _preview_tween.is_valid():
		_preview_tween.kill()
	_preview_player.stop()
	_stop_menu_preview()
	if _loops_content and _loops_content.has_method("stop_preview"):
		_loops_content.stop_preview()
	if _events_content and _events_content.has_method("stop_playback"):
		_events_content.stop_playback()
	get_tree().change_scene_to_file("res://scenes/ui/dev_studio_menu.tscn")


func _auto_save() -> void:
	SfxConfigManager.save(_config)
	SfxPlayer.reload()


# --- Theming ---

func _apply_theme() -> void:
	if _bg_rect:
		_bg_rect.color = Color(0.02, 0.02, 0.03, 1.0)
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
	if _tab_events_btn:
		ThemeManager.apply_button_style(_tab_events_btn)
	if _tab_menu_btn:
		ThemeManager.apply_button_style(_tab_menu_btn)
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
	# Theme the events tab content
	if _events_content and _events_content.has_method("apply_theme"):
		_events_content.apply_theme()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
