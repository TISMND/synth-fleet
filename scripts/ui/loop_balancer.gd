extends Control
## Loop Balancer panel — embeddable within SFX Editor as a tab.
## Lists all audio loops with editable names, volume sliders, play preview, and VU meter.
## Renaming propagates to all data files that reference the loop.

var _preview_player: AudioStreamPlayer
var _playing_path: String = ""
var _vu_meter: Control  # Custom VU meter drawing node

# Per-loop UI refs keyed by loop file path
var _name_edits: Dictionary = {}      # path -> LineEdit
var _volume_sliders: Dictionary = {}  # path -> HSlider
var _volume_labels: Dictionary = {}   # path -> Label
var _play_buttons: Dictionary = {}    # path -> Button
var _usage_labels: Dictionary = {}    # path -> Label
var _row_panels: Dictionary = {}      # path -> PanelContainer
var _section_headers: Array[Label] = []
var _all_loop_paths: Array[String] = []

# Categories in display order
const CATEGORY_ORDER: Array[String] = [
	"bass", "drums", "percussion", "synth", "leads", "keys",
	"pads", "chords", "strings", "brass_and_winds", "guitar",
	"fx", "vocals", "others"
]

const LOOP_DIRS: Array[String] = [
	"res://loop_zips/sorted/",
	"res://assets/audio/loops/",
	"res://assets/audio/atmosphere/",
]


func _ready() -> void:
	_all_loop_paths = _scan_all_loops()
	_build_ui()


func _build_ui() -> void:
	# Preview audio player
	_preview_player = AudioStreamPlayer.new()
	add_child(_preview_player)

	# Main layout: scroll list on left, VU meter strip on right
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 8)
	add_child(hbox)

	# Scroll container with loop rows
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(vbox)

	# Get usage map for labels
	var usage: Dictionary = LoopUsageScanner.scan()

	# Group loops by category subdirectory
	var categories: Dictionary = {}  # category_name -> Array[String] of paths
	for path in _all_loop_paths:
		var cat: String = _category_from_path(path)
		if not categories.has(cat):
			categories[cat] = []
		var arr: Array = categories[cat]
		arr.append(path)

	# Build rows in category order
	for cat in CATEGORY_ORDER:
		if not categories.has(cat):
			continue
		var paths: Array = categories[cat]
		if paths.is_empty():
			continue

		_add_section_header(vbox, cat.to_upper().replace("_", " "))

		for loop_path in paths:
			var usage_arr: Array = usage.get(loop_path, []) as Array
			_add_loop_row(vbox, loop_path, usage_arr)

		# Spacer between categories
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 8)
		vbox.add_child(spacer)

	# Any loops in uncategorized directories
	var seen_cats: Dictionary = {}
	for cat in CATEGORY_ORDER:
		seen_cats[cat] = true
	for cat in categories:
		if not seen_cats.has(cat):
			_add_section_header(vbox, cat.to_upper().replace("_", " "))
			var paths: Array = categories[cat]
			for loop_path in paths:
				var usage_arr: Array = usage.get(loop_path, []) as Array
				_add_loop_row(vbox, loop_path, usage_arr)

	# VU meter strip on the right
	_vu_meter = _VUMeter.new()
	_vu_meter.custom_minimum_size = Vector2(36, 0)
	_vu_meter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(_vu_meter)


func _process(_delta: float) -> void:
	# Feed real-time peak level to VU meter
	if _vu_meter and _vu_meter is _VUMeter:
		var meter: _VUMeter = _vu_meter as _VUMeter
		if _preview_player and _preview_player.playing:
			# Read peak from the Master bus (index 0)
			var peak_l: float = AudioServer.get_bus_peak_volume_left_db(0, 0)
			var peak_r: float = AudioServer.get_bus_peak_volume_right_db(0, 0)
			var peak_db: float = maxf(peak_l, peak_r)
			meter.set_level(peak_db)
		else:
			meter.set_level(-80.0)

	# Auto-stop tracking when preview finishes
	if _playing_path != "" and _preview_player and not _preview_player.playing:
		_update_play_button(_playing_path, false)
		_playing_path = ""


func _add_section_header(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	parent.add_child(label)
	_section_headers.append(label)


func _add_loop_row(parent: VBoxContainer, loop_path: String, usage_arr: Array) -> void:
	# Dark backing panel (hangar style)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	panel_style.corner_radius_top_left = 4
	panel_style.corner_radius_top_right = 4
	panel_style.corner_radius_bottom_left = 4
	panel_style.corner_radius_bottom_right = 4
	panel_style.content_margin_left = 8
	panel_style.content_margin_right = 8
	panel_style.content_margin_top = 4
	panel_style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", panel_style)
	parent.add_child(panel)
	_row_panels[loop_path] = panel

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	# Editable display name (left side, expands)
	var name_edit := LineEdit.new()
	name_edit.text = LoopConfigManager.get_display_name(loop_path)
	name_edit.custom_minimum_size = Vector2(240, 42)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_submitted.connect(_on_name_submitted.bind(loop_path))
	name_edit.focus_exited.connect(_on_name_focus_lost.bind(loop_path))
	row.add_child(name_edit)
	_name_edits[loop_path] = name_edit

	# Usage info (dimmed, between name and controls)
	var usage_label := Label.new()
	if usage_arr.size() > 0:
		var parts: PackedStringArray = PackedStringArray()
		for u in usage_arr:
			parts.append(str(u))
		usage_label.text = ", ".join(parts)
	else:
		usage_label.text = "(unused)"
	usage_label.custom_minimum_size = Vector2(180, 0)
	usage_label.clip_text = true
	usage_label.modulate = Color(1.0, 1.0, 1.0, 0.45)
	row.add_child(usage_label)
	_usage_labels[loop_path] = usage_label

	# Play button (close to slider)
	var play_btn := Button.new()
	play_btn.text = "\u25b6"
	play_btn.custom_minimum_size = Vector2(48, 42)
	play_btn.pressed.connect(_on_play.bind(loop_path))
	row.add_child(play_btn)
	_play_buttons[loop_path] = play_btn

	# Volume slider (wide for fine control)
	var vol_slider := HSlider.new()
	vol_slider.min_value = -40.0
	vol_slider.max_value = 5.0
	vol_slider.step = 0.1
	vol_slider.value = LoopConfigManager.get_volume(loop_path)
	vol_slider.custom_minimum_size = Vector2(300, 0)
	vol_slider.value_changed.connect(_on_volume_changed.bind(loop_path))
	row.add_child(vol_slider)
	_volume_sliders[loop_path] = vol_slider

	# Volume value display
	var vol_val := Label.new()
	vol_val.text = "%.1f dB" % vol_slider.value
	vol_val.custom_minimum_size = Vector2(65, 0)
	row.add_child(vol_val)
	_volume_labels[loop_path] = vol_val


# --- Scanning ---

func _scan_all_loops() -> Array[String]:
	var files: Array[String] = []
	for base_dir in LOOP_DIRS:
		_scan_dir_recursive(base_dir, files)
	files.sort()
	return files


func _scan_dir_recursive(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				_scan_dir_recursive(dir_path.path_join(file_name), out)
		else:
			var lower: String = file_name.to_lower()
			if lower.ends_with(".wav") or lower.ends_with(".ogg"):
				out.append(dir_path.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()


func _category_from_path(path: String) -> String:
	var parts: PackedStringArray = path.replace("\\", "/").split("/")
	if parts.size() >= 2:
		return parts[parts.size() - 2]
	return "others"


# --- Signal handlers ---

func _on_play(loop_path: String) -> void:
	# If already playing this loop, stop it
	if _playing_path == loop_path and _preview_player.playing:
		_preview_player.stop()
		_update_play_button(_playing_path, false)
		_playing_path = ""
		return

	# Stop previous
	if _playing_path != "" and _play_buttons.has(_playing_path):
		_update_play_button(_playing_path, false)
	_preview_player.stop()

	# Load and play
	var stream: AudioStream = load(loop_path) as AudioStream
	if stream == null:
		return
	_preview_player.stream = stream
	_preview_player.volume_db = LoopConfigManager.get_volume(loop_path)
	_preview_player.play()
	_playing_path = loop_path
	_update_play_button(loop_path, true)


func _update_play_button(loop_path: String, playing: bool) -> void:
	if not _play_buttons.has(loop_path):
		return
	var btn: Button = _play_buttons[loop_path]
	btn.text = "\u25a0" if playing else "\u25b6"


func _on_volume_changed(value: float, loop_path: String) -> void:
	LoopConfigManager.set_volume(loop_path, value)
	if _volume_labels.has(loop_path):
		var label: Label = _volume_labels[loop_path]
		label.text = "%.1f dB" % value
	# Update live preview volume
	if _playing_path == loop_path and _preview_player.playing:
		_preview_player.volume_db = value


func _on_name_submitted(new_name: String, loop_path: String) -> void:
	_commit_name_change(loop_path, new_name)
	if _name_edits.has(loop_path):
		var edit: LineEdit = _name_edits[loop_path]
		edit.release_focus()


func _on_name_focus_lost(loop_path: String) -> void:
	if not _name_edits.has(loop_path):
		return
	var edit: LineEdit = _name_edits[loop_path]
	var new_name: String = edit.text.strip_edges()
	if new_name == "" or new_name == LoopConfigManager.get_display_name(loop_path):
		edit.text = LoopConfigManager.get_display_name(loop_path)
		return
	_commit_name_change(loop_path, new_name)


func _commit_name_change(loop_path: String, new_name: String) -> void:
	var old_name: String = LoopConfigManager.get_display_name(loop_path)
	new_name = new_name.strip_edges()
	if new_name == "" or new_name == old_name:
		return

	# Save display name in config
	LoopConfigManager.set_display_name(loop_path, new_name)

	# Build new filename from display name
	var sanitized: String = new_name.to_lower().replace(" ", "_")
	sanitized = _sanitize_filename(sanitized)
	if sanitized == "":
		return

	var old_dir: String = loop_path.get_base_dir()
	var old_ext: String = loop_path.get_extension()
	var new_path: String = old_dir.path_join(sanitized + "." + old_ext)

	# Skip file rename if path didn't change
	if new_path == loop_path:
		return

	# Ensure no collision
	if FileAccess.file_exists(new_path):
		push_warning("LoopBalancer: target file already exists: " + new_path)
		if _name_edits.has(loop_path):
			var edit: LineEdit = _name_edits[loop_path]
			edit.text = old_name
		LoopConfigManager.set_display_name(loop_path, old_name)
		return

	# Rename file on disk
	var err: int = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(loop_path),
		ProjectSettings.globalize_path(new_path)
	)
	if err != OK:
		push_warning("LoopBalancer: failed to rename file: %s -> %s (error %d)" % [loop_path, new_path, err])
		if _name_edits.has(loop_path):
			var edit: LineEdit = _name_edits[loop_path]
			edit.text = old_name
		LoopConfigManager.set_display_name(loop_path, old_name)
		return

	# Also rename the .import file if it exists
	var import_path: String = loop_path + ".import"
	var new_import_path: String = new_path + ".import"
	if FileAccess.file_exists(import_path):
		DirAccess.rename_absolute(
			ProjectSettings.globalize_path(import_path),
			ProjectSettings.globalize_path(new_import_path)
		)

	# Propagate path change to all data files
	LoopUsageScanner.rename_loop_path(loop_path, new_path)

	# Migrate config entry
	LoopConfigManager.migrate_path(loop_path, new_path)

	# Update internal tracking — swap keys in all dictionaries
	_migrate_ui_refs(loop_path, new_path)

	# Update the path in the master list
	var idx: int = _all_loop_paths.find(loop_path)
	if idx >= 0:
		_all_loop_paths[idx] = new_path

	# If currently previewing this loop, update tracking
	if _playing_path == loop_path:
		_playing_path = new_path


func _migrate_ui_refs(old_path: String, new_path: String) -> void:
	for dict in [_name_edits, _volume_sliders, _volume_labels, _play_buttons, _usage_labels, _row_panels]:
		if dict.has(old_path):
			dict[new_path] = dict[old_path]
			dict.erase(old_path)

	# Refresh usage labels since references changed
	var usage: Dictionary = LoopUsageScanner.scan()
	if _usage_labels.has(new_path):
		var label: Label = _usage_labels[new_path]
		var usage_arr: Array = usage.get(new_path, []) as Array
		if usage_arr.size() > 0:
			var parts: PackedStringArray = PackedStringArray()
			for u in usage_arr:
				parts.append(str(u))
			label.text = ", ".join(parts)
		else:
			label.text = "(unused)"


func _sanitize_filename(name: String) -> String:
	var result: String = ""
	for i in name.length():
		var c: String = name[i]
		if c == " " or c == "_" or c == "-" or c == ".":
			result += c
		elif c >= "a" and c <= "z":
			result += c
		elif c >= "0" and c <= "9":
			result += c
	return result


func stop_preview() -> void:
	## Called by parent when switching away from this tab.
	if _preview_player:
		_preview_player.stop()
	if _playing_path != "" and _play_buttons.has(_playing_path):
		_update_play_button(_playing_path, false)
	_playing_path = ""


# --- Theming ---

func apply_theme() -> void:
	for header in _section_headers:
		if is_instance_valid(header):
			ThemeManager.apply_text_glow(header, "header")
	for path in _play_buttons:
		var btn: Button = _play_buttons[path]
		if is_instance_valid(btn):
			ThemeManager.apply_button_style(btn)


# --- VU Meter ---

class _VUMeter extends Control:
	## Vertical level meter with green/yellow/red zones.
	## Displays peak audio level in real-time.

	var _current_db: float = -80.0
	var _display_db: float = -80.0  # Smoothed for visual
	var _peak_db: float = -80.0     # Peak hold
	var _peak_hold_timer: float = 0.0

	const MIN_DB := -60.0
	const MAX_DB := 6.0
	const PEAK_HOLD_SEC := 1.5
	const FALL_RATE := 40.0  # dB per second for smooth falloff
	const PEAK_FALL_RATE := 15.0

	# Zone thresholds (in dB)
	const YELLOW_DB := -12.0
	const RED_DB := -3.0

	func set_level(db: float) -> void:
		_current_db = clampf(db, MIN_DB, MAX_DB)
		# Update peak hold
		if _current_db > _peak_db:
			_peak_db = _current_db
			_peak_hold_timer = PEAK_HOLD_SEC

	func _process(delta: float) -> void:
		# Smooth rise/fall
		if _current_db > _display_db:
			_display_db = _current_db  # Instant rise
		else:
			_display_db = maxf(_display_db - FALL_RATE * delta, _current_db)

		# Peak hold decay
		if _peak_hold_timer > 0.0:
			_peak_hold_timer -= delta
		else:
			_peak_db = maxf(_peak_db - PEAK_FALL_RATE * delta, _display_db)

		queue_redraw()

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		if h <= 0.0 or w <= 0.0:
			return

		# Dark background
		draw_rect(Rect2(0, 0, w, h), Color(0.05, 0.05, 0.05, 0.8))

		# Draw segmented meter
		var segment_count: int = 30
		var gap: float = 2.0
		var seg_h: float = (h - gap * float(segment_count - 1)) / float(segment_count)
		if seg_h < 1.0:
			seg_h = 1.0

		var db_range: float = MAX_DB - MIN_DB
		var level_frac: float = clampf((_display_db - MIN_DB) / db_range, 0.0, 1.0)
		var peak_frac: float = clampf((_peak_db - MIN_DB) / db_range, 0.0, 1.0)
		var yellow_frac: float = (YELLOW_DB - MIN_DB) / db_range
		var red_frac: float = (RED_DB - MIN_DB) / db_range

		for i in range(segment_count):
			var seg_frac: float = float(i) / float(segment_count)
			var seg_top_frac: float = float(i + 1) / float(segment_count)
			# Segments go bottom-to-top: segment 0 is at the bottom
			var y: float = h - float(i + 1) * (seg_h + gap)

			# Determine segment color based on its position in the range
			var seg_color: Color
			if seg_frac >= red_frac:
				seg_color = Color(1.0, 0.15, 0.15)  # Red
			elif seg_frac >= yellow_frac:
				seg_color = Color(1.0, 0.85, 0.0)   # Yellow
			else:
				seg_color = Color(0.1, 0.9, 0.2)    # Green

			var is_lit: bool = seg_top_frac <= level_frac
			var is_peak: bool = not is_lit and absf(seg_frac - peak_frac) < (1.0 / float(segment_count) + 0.01)

			if is_lit:
				draw_rect(Rect2(2, y, w - 4, seg_h), seg_color)
			elif is_peak:
				# Peak indicator — bright line
				draw_rect(Rect2(2, y, w - 4, seg_h), seg_color.lerp(Color.WHITE, 0.3))
			else:
				# Dim unlit segment
				draw_rect(Rect2(2, y, w - 4, seg_h), seg_color * Color(0.15, 0.15, 0.15, 0.4))

		# dB labels along the right edge
		var font: Font = ThemeManager.get_font("default")
		var font_size: int = 9
		for db_mark in [0, -6, -12, -24, -48]:
			var mark_frac: float = (float(db_mark) - MIN_DB) / db_range
			var mark_y: float = h - mark_frac * h
			var label_text: String = str(db_mark)
			draw_string(font, Vector2(1, mark_y + 3), label_text, HORIZONTAL_ALIGNMENT_LEFT, int(w), font_size, Color(0.7, 0.7, 0.7, 0.6))
