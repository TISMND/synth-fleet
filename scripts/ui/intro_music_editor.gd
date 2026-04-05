class_name IntroMusicEditor
extends PopupPanel
## Popup wrapper around MusicTimelineEditor, bound to a LevelData's intro_tracks.
## No infinite-loop support (intro tracks always have an end).

signal tracks_changed

const POPUP_W: int = 960
const POPUP_H: int = 640

var _level_data: LevelData = null
var _header_label: Label
var _timeline_editor: MusicTimelineEditor


func _init() -> void:
	size = Vector2i(POPUP_W, POPUP_H)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.08, 0.96)
	style.border_color = ThemeManager.get_color("accent")
	style.border_width_bottom = 1
	style.border_width_top = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	add_theme_stylebox_override("panel", style)
	popup_hide.connect(_on_closed)


func _ready() -> void:
	_build_ui()


func open_for_level(level: LevelData) -> void:
	_level_data = level
	_header_label.text = "INTRO MUSIC — " + _level_data.display_name
	_timeline_editor.set_data(_level_data.intro_tracks, _level_data.bpm,
		_level_data.intro_duration_bars, false, "Atmosphere")
	popup_centered()


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	# Header row
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 16)
	root.add_child(header_row)

	_header_label = Label.new()
	_header_label.text = "INTRO MUSIC"
	ThemeManager.apply_text_glow(_header_label, "header")
	header_row.add_child(_header_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(spacer)

	var close_btn := Button.new()
	close_btn.text = "CLOSE"
	close_btn.pressed.connect(func() -> void: hide())
	ThemeManager.apply_button_style(close_btn)
	header_row.add_child(close_btn)

	# Shared timeline editor
	_timeline_editor = MusicTimelineEditor.new()
	_timeline_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timeline_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_timeline_editor.tracks_changed.connect(_on_tracks_changed)
	_timeline_editor.duration_changed.connect(_on_duration_changed)
	root.add_child(_timeline_editor)


func _on_tracks_changed() -> void:
	tracks_changed.emit()


func _on_duration_changed(bars: int) -> void:
	if _level_data:
		_level_data.intro_duration_bars = bars
	tracks_changed.emit()


func _on_closed() -> void:
	_timeline_editor._stop_audition()
