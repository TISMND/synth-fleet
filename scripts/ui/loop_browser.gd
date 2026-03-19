class_name LoopBrowser
extends VBoxContainer
## Reusable loop browser — scans loop_zips/sorted/ by instrument folder,
## prev/next navigation with autoplay, category filtering.

signal loop_selected(path: String, category: String)

const SCAN_ROOT := "res://loop_zips/sorted/"

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

var _audition_id: String = "loop_browser_audition"
var _is_playing: bool = false


func _ready() -> void:
	_scan_loops()
	_build_ui()
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

	# Category row
	var cat_row := HBoxContainer.new()
	add_child(cat_row)

	var cat_label := Label.new()
	cat_label.text = "Category:"
	cat_label.custom_minimum_size.x = 80
	cat_row.add_child(cat_label)

	_category_button = OptionButton.new()
	_category_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_category_button.add_item("ALL")
	for cat in _categories:
		_category_button.add_item(cat.to_upper())
	_category_button.item_selected.connect(_on_category_changed)
	cat_row.add_child(_category_button)

	# Set initial list
	_on_category_changed(0)


func _scan_loops() -> void:
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
	if idx == 0:
		# ALL
		_current_list = _all_loops.duplicate()
	else:
		var cat: String = _categories[idx - 1]
		var cat_loops: Array = _loops_by_category.get(cat, [])
		_current_list = []
		for loop in cat_loops:
			_current_list.append(loop)

	if _current_list.size() > 0:
		_current_index = 0
		_select_current()
	else:
		_current_index = -1
		_update_display_empty()


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

	# Autoplay
	_start_playback(path)

	loop_selected.emit(path, cat)


func _update_display_empty() -> void:
	_song_label.text = "(no loops in category)"
	_file_label.text = ""
	_count_label.text = "0 / 0"


func _start_playback(path: String) -> void:
	_stop_playback()
	LoopMixer.add_loop(_audition_id, path, "Master", 0.0, false)
	LoopMixer.start_all()
	_is_playing = true


func _stop_playback() -> void:
	if _is_playing:
		LoopMixer.remove_loop(_audition_id)
		_is_playing = false


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
			_current_list = _all_loops.duplicate()
			_current_index = i
			_song_label.text = str(_all_loops[i]["song_name"])
			_file_label.text = str(_all_loops[i]["filename"])
			_count_label.text = "%d / %d" % [_current_index + 1, _current_list.size()]
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
