extends MarginContainer
## Sound Manager — browse, audition, rename, organize, and tag audio samples.
## File-manager style: click to select, double-click to play, right-click for context menu.

const SAMPLES_ROOT := "res://assets/audio/samples/"
const AUDIO_EXTENSIONS: Array[String] = ["wav", "ogg", "mp3"]

# Row highlight colors
const COLOR_NORMAL := Color(0.12, 0.12, 0.15)
const COLOR_HOVERED := Color(0.2, 0.25, 0.3)
const COLOR_SELECTED := Color(0.15, 0.25, 0.4)
const COLOR_PLAYING := Color(0.15, 0.35, 0.15)
const COLOR_SELECTED_PLAYING := Color(0.15, 0.3, 0.3)

# UI refs
var _search_input: LineEdit
var _tag_filter: OptionButton
var _folder_tree: Tree
var _file_list_container: VBoxContainer
var _file_header_label: Label
var _status_label: Label
var _audio_player: AudioStreamPlayer
var _loop_timer: Timer
var _context_menu: PopupMenu
var _move_submenu: PopupMenu
var _palette_flow: HFlowContainer
var _palette_name_input: LineEdit
var _palette_color_picker: ColorPickerButton

# Pre-cached StyleBoxFlat instances
var _style_normal: StyleBoxFlat
var _style_hovered: StyleBoxFlat
var _style_selected: StyleBoxFlat
var _style_playing: StyleBoxFlat
var _style_selected_playing: StyleBoxFlat

# State
var _current_folder: String = SAMPLES_ROOT
var _selected_file: String = ""
var _playing_file: String = ""
var _hovered_file: String = ""
var _file_row_panels: Dictionary = {}  # path -> PanelContainer
var _context_menu_file: String = ""  # file path for current right-click


func _ready() -> void:
	SoundTagManager.load_tags()
	_create_styles()
	_build_ui()
	_refresh_folder_tree()
	_refresh_file_list()
	visibility_changed.connect(_on_visibility_changed)


func _create_styles() -> void:
	_style_normal = _make_style(COLOR_NORMAL)
	_style_hovered = _make_style(COLOR_HOVERED)
	_style_selected = _make_style(COLOR_SELECTED)
	_style_playing = _make_style(COLOR_PLAYING)
	_style_selected_playing = _make_style(COLOR_SELECTED_PLAYING)


func _make_style(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left = 3
	s.corner_radius_top_right = 3
	s.corner_radius_bottom_left = 3
	s.corner_radius_bottom_right = 3
	s.content_margin_left = 4
	s.content_margin_right = 4
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	return s


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event: InputEventKey = event
		if key_event.keycode == KEY_SPACE and _selected_file != "":
			_toggle_play(_selected_file)
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_F2 and _selected_file != "":
			_on_rename(_selected_file)
			get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root)

	# ── Toolbar ──
	var toolbar := HBoxContainer.new()
	root.add_child(toolbar)

	var new_folder_btn := Button.new()
	new_folder_btn.text = "NEW FOLDER"
	new_folder_btn.pressed.connect(_on_new_folder)
	toolbar.add_child(new_folder_btn)

	var refresh_btn := Button.new()
	refresh_btn.text = "REFRESH"
	refresh_btn.pressed.connect(_on_refresh)
	toolbar.add_child(refresh_btn)

	_search_input = LineEdit.new()
	_search_input.placeholder_text = "Search files..."
	_search_input.custom_minimum_size.x = 180
	_search_input.text_changed.connect(func(_t: String) -> void: _refresh_file_list())
	toolbar.add_child(_search_input)

	_tag_filter = OptionButton.new()
	_tag_filter.custom_minimum_size.x = 120
	_tag_filter.item_selected.connect(func(_i: int) -> void: _refresh_file_list())
	toolbar.add_child(_tag_filter)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)

	var stop_btn := Button.new()
	stop_btn.text = "STOP"
	stop_btn.pressed.connect(_stop_playback)
	toolbar.add_child(stop_btn)

	# ── Main split ──
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 250
	root.add_child(split)

	# Left: folder tree
	_folder_tree = Tree.new()
	_folder_tree.custom_minimum_size.x = 200
	_folder_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_folder_tree.item_selected.connect(_on_folder_selected)
	split.add_child(_folder_tree)

	# Right: file list
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(right_vbox)

	_file_header_label = Label.new()
	_file_header_label.text = "FILES IN: " + SAMPLES_ROOT
	_file_header_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	right_vbox.add_child(_file_header_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_vbox.add_child(scroll)

	_file_list_container = VBoxContainer.new()
	_file_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_file_list_container)

	# ── Separator ──
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	root.add_child(sep)

	# ── Tag Palette Manager ──
	var palette_section := VBoxContainer.new()
	root.add_child(palette_section)

	var palette_header_row := HBoxContainer.new()
	palette_section.add_child(palette_header_row)

	var palette_header := Label.new()
	palette_header.text = "TAG PALETTE"
	palette_header.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	palette_header_row.add_child(palette_header)

	var palette_spacer := Control.new()
	palette_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	palette_header_row.add_child(palette_spacer)

	_palette_name_input = LineEdit.new()
	_palette_name_input.placeholder_text = "New tag name..."
	_palette_name_input.custom_minimum_size.x = 150
	_palette_name_input.text_submitted.connect(func(_t: String) -> void: _add_palette_tag())
	palette_header_row.add_child(_palette_name_input)

	_palette_color_picker = ColorPickerButton.new()
	_palette_color_picker.color = Color(0.4, 0.75, 1.0)
	_palette_color_picker.custom_minimum_size = Vector2(32, 28)
	palette_header_row.add_child(_palette_color_picker)

	var add_palette_btn := Button.new()
	add_palette_btn.text = "+"
	add_palette_btn.pressed.connect(_add_palette_tag)
	palette_header_row.add_child(add_palette_btn)

	_palette_flow = HFlowContainer.new()
	_palette_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	palette_section.add_child(_palette_flow)

	# ── Status ──
	_status_label = Label.new()
	_status_label.text = ""
	root.add_child(_status_label)

	# ── Audio player + loop timer ──
	_audio_player = AudioStreamPlayer.new()
	add_child(_audio_player)
	_audio_player.finished.connect(_on_audio_finished)

	_loop_timer = Timer.new()
	_loop_timer.one_shot = true
	_loop_timer.wait_time = 0.2
	_loop_timer.timeout.connect(_on_loop_timeout)
	add_child(_loop_timer)

	# ── Shared context menu ──
	_context_menu = PopupMenu.new()
	_context_menu.id_pressed.connect(_on_context_menu_id)
	add_child(_context_menu)

	_move_submenu = PopupMenu.new()
	_move_submenu.name = "MoveSubmenu"
	_move_submenu.id_pressed.connect(_on_move_submenu_id)
	_context_menu.add_child(_move_submenu)

	_refresh_palette_display()


# ── Folder tree ──────────────────────────────────────────────

func _refresh_folder_tree() -> void:
	_folder_tree.clear()
	var root_item: TreeItem = _folder_tree.create_item()
	root_item.set_text(0, "samples/")
	root_item.set_metadata(0, SAMPLES_ROOT)
	_add_subfolders(root_item, SAMPLES_ROOT)
	root_item.set_collapsed(false)


func _add_subfolders(parent_item: TreeItem, path: String) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if dir.current_is_dir() and not fname.begins_with("."):
			var full_path: String = path + fname + "/"
			var child: TreeItem = _folder_tree.create_item(parent_item)
			child.set_text(0, fname + "/")
			child.set_metadata(0, full_path)
			_add_subfolders(child, full_path)
		fname = dir.get_next()
	dir.list_dir_end()


func _on_folder_selected() -> void:
	var item: TreeItem = _folder_tree.get_selected()
	if item:
		_current_folder = str(item.get_metadata(0))
		_refresh_file_list()


# ── File list ────────────────────────────────────────────────

func _refresh_file_list() -> void:
	for child in _file_list_container.get_children():
		child.queue_free()
	_file_row_panels.clear()
	_hovered_file = ""

	_file_header_label.text = "FILES IN: " + _current_folder

	var search_text: String = _search_input.text.strip_edges().to_lower()
	var tag_filter_text: String = ""
	if _tag_filter.selected > 0:
		tag_filter_text = _tag_filter.get_item_text(_tag_filter.selected)

	var files: Array[String] = _scan_folder(_current_folder)
	for file_path in files:
		var fname: String = file_path.get_file()

		# Search filter
		if search_text != "" and not fname.to_lower().contains(search_text):
			continue

		# Tag filter
		if tag_filter_text != "":
			var tags: Array[String] = SoundTagManager.get_tags_for(file_path)
			if tag_filter_text not in tags:
				continue

		_add_file_row(file_path)

	_refresh_tag_filter_dropdown()


func _scan_folder(path: String) -> Array[String]:
	var files: Array[String] = []
	var dir := DirAccess.open(path)
	if not dir:
		return files
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			var ext: String = fname.get_extension().to_lower()
			if ext in AUDIO_EXTENSIONS:
				files.append(path + fname)
		fname = dir.get_next()
	dir.list_dir_end()
	files.sort()
	return files


func _add_file_row(file_path: String) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_file_list_container.add_child(panel)
	_file_row_panels[file_path] = panel

	# Connect mouse events
	panel.gui_input.connect(_on_row_gui_input.bind(file_path))
	panel.mouse_entered.connect(_on_row_mouse_entered.bind(file_path))
	panel.mouse_exited.connect(_on_row_mouse_exited.bind(file_path))

	var hbox := HBoxContainer.new()
	panel.add_child(hbox)

	# Play/stop indicator (not a button — just visual)
	var indicator := Label.new()
	indicator.name = "Indicator"
	indicator.custom_minimum_size.x = 20
	indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	indicator.text = "■" if _playing_file == file_path else "▶"
	if _playing_file == file_path:
		indicator.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		indicator.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hbox.add_child(indicator)

	# Filename
	var fname: String = file_path.get_file()
	var name_label := Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.text = fname
	name_label.tooltip_text = file_path
	name_label.custom_minimum_size.x = 200
	hbox.add_child(name_label)

	# Tag bubbles
	var tags: Array[String] = SoundTagManager.get_tags_for(file_path)
	for tag in tags:
		var tag_label := Label.new()
		tag_label.text = " " + tag + " "
		var tag_color: Color = SoundTagManager.get_tag_color(tag)
		# Use dark text on light backgrounds, light on dark
		var luminance: float = tag_color.r * 0.299 + tag_color.g * 0.587 + tag_color.b * 0.114
		if luminance > 0.5:
			tag_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
		else:
			tag_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(tag_color.r, tag_color.g, tag_color.b, 0.7)
		bg.corner_radius_top_left = 3
		bg.corner_radius_top_right = 3
		bg.corner_radius_bottom_left = 3
		bg.corner_radius_bottom_right = 3
		bg.content_margin_left = 4
		bg.content_margin_right = 4
		tag_label.add_theme_stylebox_override("normal", bg)
		hbox.add_child(tag_label)

	# Apply initial style
	_update_row_style(file_path)


func _on_row_gui_input(event: InputEvent, file_path: String) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.double_click:
				_toggle_play(file_path)
			else:
				_select_file(file_path)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_select_file(file_path)
			_show_context_menu(file_path)


func _on_row_mouse_entered(file_path: String) -> void:
	_hovered_file = file_path
	_update_row_style(file_path)


func _on_row_mouse_exited(file_path: String) -> void:
	if _hovered_file == file_path:
		_hovered_file = ""
	_update_row_style(file_path)


func _update_row_style(file_path: String) -> void:
	if file_path not in _file_row_panels:
		return
	var panel: PanelContainer = _file_row_panels[file_path]
	var is_selected: bool = file_path == _selected_file
	var is_playing: bool = file_path == _playing_file
	var is_hovered: bool = file_path == _hovered_file

	var style: StyleBoxFlat
	if is_selected and is_playing:
		style = _style_selected_playing
	elif is_playing:
		style = _style_playing
	elif is_selected:
		style = _style_selected
	elif is_hovered:
		style = _style_hovered
	else:
		style = _style_normal

	panel.add_theme_stylebox_override("panel", style)


func _select_file(file_path: String) -> void:
	var old_selected: String = _selected_file
	_selected_file = file_path
	if old_selected != "" and old_selected in _file_row_panels:
		_update_row_style(old_selected)
	_update_row_style(file_path)


# ── Context menu ─────────────────────────────────────────────

const CONTEXT_PLAY := 0
const CONTEXT_RENAME := 1
const CONTEXT_TAG_SECTION := 100  # tag IDs start at 100

func _show_context_menu(file_path: String) -> void:
	_context_menu_file = file_path
	_context_menu.clear()

	# Play/Stop
	if _playing_file == file_path:
		_context_menu.add_item("■ Stop", CONTEXT_PLAY)
	else:
		_context_menu.add_item("▶ Play", CONTEXT_PLAY)

	_context_menu.add_separator()

	# Rename
	_context_menu.add_item("Rename...", CONTEXT_RENAME)

	# Move submenu
	_move_submenu.clear()
	var subfolders: Array[String] = _get_all_subfolders(SAMPLES_ROOT)
	for i in subfolders.size():
		var display: String = subfolders[i].replace(SAMPLES_ROOT, "samples/")
		_move_submenu.add_item(display, i)
	_context_menu.add_submenu_node_item("Move to", _move_submenu)

	_context_menu.add_separator()

	# Tag palette section
	_context_menu.add_item("TAG PALETTE:", -1)
	var tag_header_idx: int = _context_menu.item_count - 1
	_context_menu.set_item_disabled(tag_header_idx, true)

	var palette: Dictionary = SoundTagManager.get_palette()
	var file_tags: Array[String] = SoundTagManager.get_tags_for(file_path)
	var tag_names: Array[String] = []
	for key in palette:
		tag_names.append(str(key))
	tag_names.sort()

	for i in tag_names.size():
		var tag_name: String = tag_names[i]
		var item_id: int = CONTEXT_TAG_SECTION + i
		_context_menu.add_check_item("  " + tag_name, item_id)
		var item_idx: int = _context_menu.get_item_index(item_id)
		if tag_name in file_tags:
			_context_menu.set_item_checked(item_idx, true)

	if tag_names.is_empty():
		_context_menu.add_item("  (add tags in palette below)", -1)
		_context_menu.set_item_disabled(_context_menu.item_count - 1, true)

	_context_menu.popup(Rect2i(Vector2i(DisplayServer.mouse_get_position()), Vector2i.ZERO))


var _move_subfolders_cache: Array[String] = []

func _on_context_menu_id(id: int) -> void:
	if _context_menu_file == "":
		return

	if id == CONTEXT_PLAY:
		_toggle_play(_context_menu_file)
	elif id == CONTEXT_RENAME:
		_on_rename(_context_menu_file)
	elif id >= CONTEXT_TAG_SECTION:
		# Tag toggle
		var palette: Dictionary = SoundTagManager.get_palette()
		var tag_names: Array[String] = []
		for key in palette:
			tag_names.append(str(key))
		tag_names.sort()
		var tag_idx: int = id - CONTEXT_TAG_SECTION
		if tag_idx >= 0 and tag_idx < tag_names.size():
			var tag_name: String = tag_names[tag_idx]
			var file_tags: Array[String] = SoundTagManager.get_tags_for(_context_menu_file)
			if tag_name in file_tags:
				file_tags.erase(tag_name)
				_status_label.text = "Removed tag '" + tag_name + "'"
			else:
				file_tags.append(tag_name)
				_status_label.text = "Added tag '" + tag_name + "'"
			SoundTagManager.set_tags_for(_context_menu_file, file_tags)
			_refresh_file_list()


func _on_move_submenu_id(id: int) -> void:
	if _context_menu_file == "":
		return
	var subfolders: Array[String] = _get_all_subfolders(SAMPLES_ROOT)
	if id < 0 or id >= subfolders.size():
		return
	var target_folder: String = subfolders[id]
	var new_path: String = target_folder + _context_menu_file.get_file()
	if new_path == _context_menu_file:
		_status_label.text = "File is already in that folder."
		return
	_do_rename(_context_menu_file, new_path)


# ── Playback ─────────────────────────────────────────────────

func _toggle_play(file_path: String) -> void:
	if _playing_file == file_path:
		_stop_playback()
		return

	_stop_playback()
	_playing_file = file_path
	var stream: AudioStream = load(file_path) as AudioStream
	if not stream:
		_status_label.text = "Failed to load: " + file_path
		_playing_file = ""
		return
	_audio_player.stream = stream
	_audio_player.play()
	_status_label.text = "Playing: " + file_path.get_file()
	_update_all_row_styles()
	_update_row_indicator(file_path)


func _stop_playback() -> void:
	_audio_player.stop()
	_loop_timer.stop()
	var old_playing: String = _playing_file
	_playing_file = ""
	if old_playing != "" and old_playing in _file_row_panels:
		_update_row_style(old_playing)
		_update_row_indicator(old_playing)
	_status_label.text = ""


func _on_audio_finished() -> void:
	if _playing_file != "":
		_loop_timer.start()


func _on_loop_timeout() -> void:
	if _playing_file != "" and _audio_player.stream:
		_audio_player.play()


func _update_row_indicator(file_path: String) -> void:
	if file_path not in _file_row_panels:
		return
	var panel: PanelContainer = _file_row_panels[file_path]
	var hbox: HBoxContainer = panel.get_child(0) as HBoxContainer
	if not hbox or hbox.get_child_count() == 0:
		return
	var indicator: Label = hbox.get_child(0) as Label
	if not indicator:
		return
	if _playing_file == file_path:
		indicator.text = "■"
		indicator.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		indicator.text = "▶"
		indicator.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))


func _update_all_row_styles() -> void:
	for path in _file_row_panels:
		_update_row_style(path)
		_update_row_indicator(path)


func _on_visibility_changed() -> void:
	if not visible:
		_stop_playback()


# ── Tag Palette Manager ─────────────────────────────────────

func _add_palette_tag() -> void:
	var tag_name: String = _palette_name_input.text.strip_edges().to_lower()
	if tag_name == "":
		return
	var color_hex: String = "#" + _palette_color_picker.color.to_html(false)
	SoundTagManager.set_palette_entry(tag_name, color_hex)
	_palette_name_input.text = ""
	_refresh_palette_display()
	_refresh_tag_filter_dropdown()
	_status_label.text = "Added palette tag '" + tag_name + "'"


func _remove_palette_tag(tag_name: String) -> void:
	SoundTagManager.remove_palette_entry(tag_name)
	_refresh_palette_display()
	_refresh_tag_filter_dropdown()
	_refresh_file_list()
	_status_label.text = "Removed palette tag '" + tag_name + "'"


func _refresh_palette_display() -> void:
	for child in _palette_flow.get_children():
		child.queue_free()

	var palette: Dictionary = SoundTagManager.get_palette()
	var tag_names: Array[String] = []
	for key in palette:
		tag_names.append(str(key))
	tag_names.sort()

	for tag_name in tag_names:
		var tag_color: Color = SoundTagManager.get_tag_color(tag_name)

		var tag_hbox := HBoxContainer.new()
		tag_hbox.add_theme_constant_override("separation", 0)

		var tag_label := Label.new()
		tag_label.text = " " + tag_name + " "
		var luminance: float = tag_color.r * 0.299 + tag_color.g * 0.587 + tag_color.b * 0.114
		if luminance > 0.5:
			tag_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
		else:
			tag_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(tag_color.r, tag_color.g, tag_color.b, 0.8)
		bg.corner_radius_top_left = 3
		bg.corner_radius_bottom_left = 3
		bg.content_margin_left = 4
		bg.content_margin_right = 2
		tag_label.add_theme_stylebox_override("normal", bg)
		tag_hbox.add_child(tag_label)

		var del_btn := Button.new()
		del_btn.text = "x"
		del_btn.custom_minimum_size = Vector2(22, 0)
		del_btn.pressed.connect(_remove_palette_tag.bind(tag_name))
		tag_hbox.add_child(del_btn)

		_palette_flow.add_child(tag_hbox)


func _refresh_tag_filter_dropdown() -> void:
	var current_text: String = ""
	if _tag_filter.selected > 0:
		current_text = _tag_filter.get_item_text(_tag_filter.selected)
	_tag_filter.clear()
	_tag_filter.add_item("All Tags")
	var all_tags: Array[String] = SoundTagManager.all_tag_names()
	for t in all_tags:
		_tag_filter.add_item(t)
	# Restore selection
	if current_text != "":
		for i in _tag_filter.item_count:
			if _tag_filter.get_item_text(i) == current_text:
				_tag_filter.selected = i
				break


# ── Rename ───────────────────────────────────────────────────

func _on_rename(file_path: String) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Rename File"
	dialog.min_size = Vector2i(400, 150)

	var vbox := VBoxContainer.new()
	dialog.add_child(vbox)

	var info_label := Label.new()
	info_label.text = "Rename: " + file_path.get_file()
	vbox.add_child(info_label)

	var name_input := LineEdit.new()
	name_input.text = file_path.get_file().get_basename()
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(name_input)

	var ext: String = file_path.get_extension()

	dialog.confirmed.connect(func() -> void:
		var new_name: String = name_input.text.strip_edges()
		if new_name == "":
			_status_label.text = "Name cannot be empty."
			dialog.queue_free()
			return
		var new_path: String = file_path.get_base_dir() + "/" + new_name + "." + ext
		if new_path == file_path:
			dialog.queue_free()
			return
		_do_rename(file_path, new_path)
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())

	add_child(dialog)
	dialog.popup_centered()


func _do_rename(old_path: String, new_path: String) -> void:
	var err: int = DirAccess.rename_absolute(old_path, new_path)
	if err != OK:
		_status_label.text = "Rename failed (error " + str(err) + ")"
		return

	# Delete old .import sidecar
	var old_import: String = old_path + ".import"
	if FileAccess.file_exists(old_import):
		DirAccess.remove_absolute(old_import)

	# Update tags
	SoundTagManager.rename_path(old_path, new_path)

	# Update weapon references
	var updated_count: int = _update_weapon_references(old_path, new_path)

	if _selected_file == old_path:
		_selected_file = new_path

	if _playing_file == old_path:
		_stop_playback()

	_refresh_file_list()
	var msg: String = "Renamed to " + new_path.get_file()
	if updated_count > 0:
		msg += " (" + str(updated_count) + " weapon(s) updated)"
	_status_label.text = msg


func _update_weapon_references(old_path: String, new_path: String) -> int:
	var count: int = 0
	var weapons: Array[WeaponData] = WeaponDataManager.load_all()
	for w in weapons:
		if w.audio_sample_path == old_path:
			var data: Dictionary = w.to_dict()
			data["audio_sample_path"] = new_path
			WeaponDataManager.save(w.id, data)
			count += 1
	return count


# ── Utility ──────────────────────────────────────────────────

func _get_all_subfolders(path: String) -> Array[String]:
	var result: Array[String] = [path]
	var dir := DirAccess.open(path)
	if not dir:
		return result
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if dir.current_is_dir() and not fname.begins_with("."):
			var sub: String = path + fname + "/"
			result.append_array(_get_all_subfolders(sub))
		fname = dir.get_next()
	dir.list_dir_end()
	return result


# ── New Folder ───────────────────────────────────────────────

func _on_new_folder() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "New Folder"
	dialog.min_size = Vector2i(350, 120)

	var vbox := VBoxContainer.new()
	dialog.add_child(vbox)

	var info_label := Label.new()
	info_label.text = "Create subfolder in: " + _current_folder.replace(SAMPLES_ROOT, "samples/")
	vbox.add_child(info_label)

	var name_input := LineEdit.new()
	name_input.placeholder_text = "Folder name..."
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(name_input)

	dialog.confirmed.connect(func() -> void:
		var folder_name: String = name_input.text.strip_edges()
		if folder_name == "":
			_status_label.text = "Folder name cannot be empty."
			dialog.queue_free()
			return
		var new_dir: String = _current_folder + folder_name
		DirAccess.make_dir_recursive_absolute(new_dir)
		_refresh_folder_tree()
		_status_label.text = "Created folder: " + folder_name
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())

	add_child(dialog)
	dialog.popup_centered()


# ── Refresh ──────────────────────────────────────────────────

func _on_refresh() -> void:
	SoundTagManager.load_tags()
	_refresh_folder_tree()
	_refresh_file_list()
	_refresh_palette_display()
	_status_label.text = "Refreshed."
