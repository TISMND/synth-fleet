class_name HudDebugOverlay extends Control
## Toggle with F3 — draws outlines showing actual bar/label rects,
## zone boundaries, and panel edges so positioning issues are visible.

var _hud: Control = null
var _hud_result: Dictionary = {}
var _bars: Dictionary = {}
var _enabled: bool = false


func setup(hud: Control, hud_result: Dictionary, bars: Dictionary) -> void:
	_hud = hud
	_hud_result = hud_result
	_bars = bars
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	visible = false
	size = Vector2(1920, 1080)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		_enabled = not _enabled
		visible = _enabled
		queue_redraw()


func _process(_delta: float) -> void:
	if _enabled:
		queue_redraw()


func _draw() -> void:
	if not _enabled:
		return

	var side_top: float = 60.0
	var side_bottom: float = 1080.0 - HudBuilder.BOTTOM_BAR_HEIGHT - 8.0
	var side_height: float = side_bottom - side_top
	var mid_y: float = side_height / 2.0

	# Draw panel outlines (white)
	var left_x: float = 0.0
	var right_x: float = 1920.0 - float(HudBuilder.SIDE_PANEL_WIDTH)
	var pw: float = float(HudBuilder.SIDE_PANEL_WIDTH)
	draw_rect(Rect2(left_x, side_top, pw, side_height), Color.WHITE, false, 2.0)
	draw_rect(Rect2(right_x, side_top, pw, side_height), Color.WHITE, false, 2.0)

	# Draw zone dividers (yellow dashed — solid line at midpoint)
	var left_mid_y: float = side_top + mid_y
	draw_line(Vector2(left_x, left_mid_y), Vector2(left_x + pw, left_mid_y), Color.YELLOW, 1.0)
	draw_line(Vector2(right_x, left_mid_y), Vector2(right_x + pw, left_mid_y), Color.YELLOW, 1.0)

	# Draw bar and label outlines
	for panel_key in ["left_panel", "right_panel"]:
		if not _hud_result.has(panel_key):
			continue
		var panel_data: Dictionary = _hud_result[panel_key]
		var root: Control = panel_data["root"]
		if not is_instance_valid(root):
			continue
		var panel_origin: Vector2 = root.global_position

		var bars_dict: Dictionary = panel_data["bars"]
		for bar_name in bars_dict:
			var entry: Dictionary = bars_dict[bar_name]
			var bar: ProgressBar = entry["bar"]
			var lbl: Label = entry["label"]

			if is_instance_valid(bar):
				# Actual bar rect (red outline)
				var bar_global: Vector2 = bar.global_position
				var bar_sz: Vector2 = bar.size
				draw_rect(Rect2(bar_global, bar_sz), Color.RED, false, 2.0)

				# Bar info text
				var info: String = "%s pos=(%.0f,%.0f) sz=(%.0f,%.0f) min=(%.0f,%.0f)" % [
					bar_name,
					bar.position.x, bar.position.y,
					bar_sz.x, bar_sz.y,
					bar.custom_minimum_size.x, bar.custom_minimum_size.y,
				]
				draw_string(ThemeDB.fallback_font, bar_global + Vector2(bar_sz.x + 4, 14), info, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.RED)

			if is_instance_valid(lbl):
				# Label rect (cyan outline)
				var lbl_global: Vector2 = lbl.global_position
				draw_rect(Rect2(lbl_global, lbl.size), Color.CYAN, false, 1.0)

	# Legend
	var legend_y: float = side_top + side_height + 20
	draw_string(ThemeDB.fallback_font, Vector2(10, legend_y), "F3: toggle debug | RED=bar rect | CYAN=label | YELLOW=zone mid | WHITE=panel", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.7))
