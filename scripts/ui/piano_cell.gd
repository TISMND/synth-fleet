extends ColorRect
## A single cell in the piano-roll grid sequencer.
## Click to place/remove/move notes.

signal cell_clicked(column: int, pitch_index: int)

var column: int = 0
var pitch_index: int = 0
var _is_c_row: bool = false
var _filled: bool = false
var _cursor_active: bool = false

const EMPTY_COLOR := Color(0.12, 0.12, 0.18, 1.0)
const EMPTY_C_ROW_COLOR := Color(0.16, 0.16, 0.22, 1.0)
const CURSOR_BRIGHTEN := 1.4


func _init() -> void:
	custom_minimum_size = Vector2(44, 22)
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(col: int, p_idx: int, is_c_row: bool) -> void:
	column = col
	pitch_index = p_idx
	_is_c_row = is_c_row
	set_empty()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		cell_clicked.emit(column, pitch_index)


func set_filled(fill_color: Color) -> void:
	_filled = true
	color = fill_color
	_apply_cursor()


func set_empty() -> void:
	_filled = false
	color = EMPTY_C_ROW_COLOR if _is_c_row else EMPTY_COLOR
	_apply_cursor()


func set_cursor_highlight(active: bool) -> void:
	_cursor_active = active
	_apply_cursor()


func _apply_cursor() -> void:
	if _cursor_active:
		modulate = Color(CURSOR_BRIGHTEN, CURSOR_BRIGHTEN, CURSOR_BRIGHTEN)
	else:
		modulate = Color(1, 1, 1)
