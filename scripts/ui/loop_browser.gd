class_name LoopBrowser
extends VBoxContainer
## Reusable loop browser — scans loop_zips/sorted/ by instrument folder,
## prev/next navigation with autoplay, category filtering.
## Supports usage badges showing where each loop is already assigned.
## Loop scan is cached statically — only the first instance pays the cost.

signal loop_selected(path: String, category: String)

const SCAN_ROOT := "res://loop_zips/sorted/"

# Static cache — shared across all LoopBrowser instances
static var _cached_categories: Array[String] = []
static var _cached_loops_by_category: Dictionary = {}
static var _cached_all_loops: Array[Dictionary] = []
static var _cache_valid: bool = false

var _categories: Array[String] = []
var _loops_by_category: Dictionary = {}  # category -> Array[Dictionary]
var _all_loops: Array[Dictionary] = []   # flattened list for "ALL"
var _current_list: Array[Dictionary] = []
var _current_index: int = -1

var _category_button: OptionButton
var _prev_button: Button
var _next_button: Button
var _song_label: Label
var _file_label: Label
var _count_label: Label
var _usage_label: Label
var _hide_used_button: CheckBox

var _audition_id: String = "loop_browser_audition"
var _is_playing: bool = false
var _suppress_autoplay: bool = true  # suppress playback during initial build

# Usage tracking — set externally via set_usage_data() or auto-scanned
var _usage_data: Dictionary = {}  # path -> Array[String]
var _hide_used: bool = false


func _ready() -> void:
	_scan_loops()
	_suppress_autoplay = true
	_build_ui()
	_suppress_autoplay = false
	_apply_theme()
	ThemeManager.theme_changed.connect(_apply_theme)


func _exit_tree() -> void:
	_stop_playback()


func _build_ui() -> void:
	# Song name display (top)
	_song_label = Label.new()
	_song_label.text = "(no loop selected)"
	_song_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_song_label.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	add_child(_song_label)

	# File info (smaller)
	_file_label = Label.new()
	_file_label.text = ""
	_file_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_file_label.add_theme_color_override("font_color", ThemeManager.get_color("disabled"))
	add_child(_file_label)

	# Filter row: category dropdown + hide-used checkbox side by side
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 8)
	add_child(filter_row)

	_category_button = OptionButton.new()
	_category_button.custom_minimum_size.x = 140
	_category_button.add_item("ALL")
	for cat in _categories:
		_category_button.add_item(cat.to_upper())
	_category_button.item_selected.connect(_on_category_changed)
	filter_row.add_child(_category_button)

	_hide_used_button = CheckBox.new()
	_hide_used_button.text = "HIDE USED"
	_hide_used_button.button_pressed = false
	_hide_used_button.toggled.connect(_on_hide_used_toggled)
	filter_row.add_child(_hide_used_button)

	# Usage badges
	_usage_label = Label.new()
	_usage_label.text = ""
	_usage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_usage_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_usage_label.add_theme_font_size_override("font_size", 11)
	add_child(_usage_label)

	# Nav row
	var nav_row := HBoxContainer.new()
	nav_row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(nav_row)

	_prev_button = Button.new()
	_prev_button.text = "<  PREV"
	_prev_button.custom_minimum_size.x = 100
	_prev_button.pressed.connect(_on_prev)
	nav_row.add_child(_prev_button)

	_count_label = Label.new()
	_count_label.text = "0 / 0"
	_count_label.custom_minimum_size.x = 80
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nav_row.add_child(_count_label)

	_next_button = Button.new()
	_next_button.text = "NEXT  >"
	_next_button.custom_minimum_size.x = 100
	_next_button.pressed.connect(_on_next)
	nav_row.add_child(_next_button)

	# Set initial list
	_on_category_changed(0)


func _scan_loops() -> void:
	# Use static cache — only the first LoopBrowser instance pays the scan cost
	if _cache_valid:
		_categories = _cached_categories
		_loops_by_category = _cached_loops_by_category
		_all_loops = _cached_all_loops
		return

	var dir := DirAccess.open(SCAN_ROOT)
	if not dir:
		return
	dir.list_dir_begin()
	var folder: String = dir.get_next()
	while folder != "":
		if dir.current_is_dir() and not folder.begins_with("."):
			var loops: Array[Dictionary] = []
			_scan_folder(SCAN_ROOT + folder + "/", folder, loops)
			if loops.size() > 0:
				_categories.append(folder)
				_loops_by_category[folder] = loops
				_all_loops.append_array(loops)
		folder = dir.get_next()
	dir.list_dir_end()
	_categories.sort()
	_all_loops.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["song_name"]) < str(b["song_name"])
	)

	# Cache for other instances
	_cached_categories = _categories
	_cached_loops_by_category = _loops_by_category
	_cached_all_loops = _all_loops
	_cache_valid = true


func _scan_folder(path: String, category: String, results: Array[Dictionary]) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			var ext: String = fname.get_extension().to_lower()
			if ext == "wav" or ext == "ogg" or ext == "mp3":
				var song_name: String = _parse_song_name(fname)
				results.append({
					"path": path + fname,
					"filename": fname,
					"song_name": song_name,
					"category": category,
				})
		fname = dir.get_next()
	dir.list_dir_end()
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["song_name"]) < str(b["song_name"])
	)


func _parse_song_name(filename: String) -> String:
	# Format: "Song Name - 120 BPM - N - Category - original.wav"
	var parts: PackedStringArray = filename.split(" - ")
	if parts.size() > 0:
		return parts[0].strip_edges()
	return filename.get_basename()


func _on_category_changed(idx: int) -> void:
	var raw_list: Array[Dictionary] = []
	if idx == 0:
		# ALL
		for loop in _all_loops:
			raw_list.append(loop)
	else:
		var cat: String = _categories[idx - 1]
		var cat_loops: Array = _loops_by_category.get(cat, [])
		for loop in cat_loops:
			raw_list.append(loop)

	_current_list = _apply_filter(raw_list)

	if _current_list.size() > 0:
		_current_index = 0
		_select_current()
	else:
		_current_index = -1
		_update_display_empty()


func _apply_filter(source: Array[Dictionary]) -> Array[Dictionary]:
	if not _hide_used or _usage_data.is_empty():
		return source
	var filtered: Array[Dictionary] = []
	for loop in source:
		var path: String = str(loop["path"])
		if not _usage_data.has(path):
			filtered.append(loop)
	return filtered


func _on_hide_used_toggled(pressed: bool) -> void:
	_hide_used = pressed
	# Re-apply current category with new filter
	_on_category_changed(_category_button.selected)


func _on_prev() -> void:
	if _current_list.size() == 0:
		return
	_current_index -= 1
	if _current_index < 0:
		_current_index = _current_list.size() - 1
	_select_current()


func _on_next() -> void:
	if _current_list.size() == 0:
		return
	_current_index += 1
	if _current_index >= _current_list.size():
		_current_index = 0
	_select_current()


func _select_current() -> void:
	if _current_index < 0 or _current_index >= _current_list.size():
		return
	var loop: Dictionary = _current_list[_current_index]
	var path: String = str(loop["path"])
	var song: String = str(loop["song_name"])
	var cat: String = str(loop["category"])
	var fname: String = str(loop["filename"])

	_song_label.text = song
	_file_label.text = fname
	_count_label.text = "%d / %d" % [_current_index + 1, _current_list.size()]

	# Update usage badge
	_update_usage_display(path)

	# Autoplay (suppressed during initial build)
	if not _suppress_autoplay:
		_start_playback(path)

	loop_selected.emit(path, cat)


func _update_usage_display(path: String) -> void:
	if _usage_data.has(path):
		var users: Array = _usage_data[path]
		_usage_label.text = "USED BY: " + ", ".join(users)
		_usage_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
	else:
		_usage_label.text = ""


func _update_display_empty() -> void:
	_song_label.text = "(no loops in category)" if not _hide_used else "(all loops in use)"
	_file_label.text = ""
	_count_label.text = "0 / 0"
	_usage_label.text = ""


func _start_playback(path: String) -> void:
	_stop_playback()
	LoopMixer.add_loop(_audition_id, path, "Master", 0.0, false)
	LoopMixer.start_all()
	_is_playing = true


func _stop_playback() -> void:
	if _is_playing:
		LoopMixer.remove_loop(_audition_id)
		_is_playing = false


## Set usage data from an external scan. Pass result of LoopUsageScanner.scan().
func set_usage_data(data: Dictionary) -> void:
	_usage_data = data
	# Refresh display if we have a selection
	if _current_index >= 0 and _current_index < _current_list.size():
		var path: String = str(_current_list[_current_index]["path"])
		_update_usage_display(path)


## Refresh usage data by rescanning all data sources.
func refresh_usage() -> void:
	set_usage_data(LoopUsageScanner.scan())


func get_selected_path() -> String:
	if _current_index >= 0 and _current_index < _current_list.size():
		return str(_current_list[_current_index]["path"])
	return ""


func get_selected_category() -> String:
	if _current_index >= 0 and _current_index < _current_list.size():
		return str(_current_list[_current_index]["category"])
	return ""


func select_path(path: String) -> void:
	# Find and select a specific loop path
	for i in _current_list.size():
		if str(_current_list[i]["path"]) == path:
			_current_index = i
			_select_current()
			return
	# Try in ALL loops and switch category
	for i in _all_loops.size():
		if str(_all_loops[i]["path"]) == path:
			_category_button.selected = 0
			_current_list = _apply_filter(_all_loops)
			# Find index in filtered list
			for j in _current_list.size():
				if str(_current_list[j]["path"]) == path:
					_current_index = j
					_select_current()
					return
			# If hidden by filter, temporarily show it anyway
			_current_list = _all_loops.duplicate()
			_current_index = i
			_select_current()
			return


func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed:
		var key: InputEventKey = event
		if key.keycode == KEY_LEFT:
			_on_prev()
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_RIGHT:
			_on_next()
			get_viewport().set_input_as_handled()


func _apply_theme() -> void:
	if _song_label:
		_song_label.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	if _file_label:
		_file_label.add_theme_color_override("font_color", ThemeManager.get_color("disabled"))
	if _prev_button:
		ThemeManager.apply_button_style(_prev_button)
	if _next_button:
		ThemeManager.apply_button_style(_next_button)
	if _hide_used_button:
		_hide_used_button.add_theme_color_override("font_color", ThemeManager.get_color("text"))
