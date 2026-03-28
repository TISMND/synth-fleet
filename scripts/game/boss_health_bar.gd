class_name BossHealthBar
extends Control
## Top-center boss health bar. LED or Holographic style, selectable via audition.

enum Style { LED, HOLOGRAPHIC }

const BAR_Y: float = 30.0
const BAR_HEIGHT: float = 24.0
const PCT_WIDTH: float = 60.0  # Fixed-width area for percentage text (prevents jiggle)
const PCT_GAP: float = 12.0  # Gap between percentage and bar
const TOTAL_WIDTH: float = 1700.0  # Total reserved width (pct + gap + bar)

var max_health: float = 100.0
var current_health: float = 100.0
var style: int = Style.HOLOGRAPHIC
var hdr: float = 2.2
var _time: float = 0.0
var _target_ratio: float = 1.0
var _display_ratio: float = 1.0  # Smoothly tracks target for drain animation
var _segment_count: int = 40
var _flash_timer: float = 0.0  # Brief flash on damage

# Audition settings (loaded from user://settings/boss_bar_audition.json)
var color_healthy: Color = Color(0.2, 1.0, 0.3)
var color_damaged: Color = Color(1.0, 0.8, 0.1)
var color_critical: Color = Color(1.0, 0.15, 0.1)

const SAVE_PATH := "user://settings/boss_bar_audition.json"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_settings()


func _process(delta: float) -> void:
	_time += delta
	_target_ratio = current_health / maxf(max_health, 1.0)
	if _display_ratio > _target_ratio:
		_display_ratio = move_toward(_display_ratio, _target_ratio, delta * 0.8)
	else:
		_display_ratio = _target_ratio
	if _flash_timer > 0.0:
		_flash_timer -= delta
	queue_redraw()


func take_damage(new_health: float) -> void:
	current_health = maxf(new_health, 0.0)
	_flash_timer = 0.12


func _draw() -> void:
	match style:
		Style.LED:
			_draw_led()
		Style.HOLOGRAPHIC:
			_draw_holographic()


func _get_bar_color() -> Color:
	var ratio: float = _display_ratio
	if ratio > 0.5:
		return color_healthy.lerp(color_damaged, (1.0 - ratio) * 2.0)
	else:
		return color_damaged.lerp(color_critical, (0.5 - ratio) * 2.0)


func _get_layout() -> Dictionary:
	## Returns fixed layout: pct area then bar area, all within TOTAL_WIDTH centered on screen.
	var total_start: float = (1920.0 - TOTAL_WIDTH) * 0.5
	var pct_x: float = total_start
	var bar_x: float = total_start + PCT_WIDTH + PCT_GAP
	var bar_w: float = TOTAL_WIDTH - PCT_WIDTH - PCT_GAP
	return {"pct_x": pct_x, "bar_x": bar_x, "bar_w": bar_w}


# ── LED Style ────────────────────────────────────────────────────────

func _draw_led() -> void:
	var layout: Dictionary = _get_layout()
	var bar_x: float = float(layout["bar_x"])
	var bar_w: float = float(layout["bar_w"])
	var bar_rect := Rect2(bar_x, BAR_Y, bar_w, BAR_HEIGHT)
	var col: Color = _get_bar_color()
	var h: float = hdr

	# Percentage left of bar (fixed-width, right-aligned)
	_draw_pct(float(layout["pct_x"]), col, h)

	# Background
	draw_rect(bar_rect, Color(0.05, 0.05, 0.08, 0.7))

	# Segments
	var seg_gap: float = 2.0
	var seg_w: float = (bar_w - seg_gap * float(_segment_count - 1)) / float(_segment_count)
	var filled: int = int(_display_ratio * float(_segment_count))
	for i in range(_segment_count):
		var sx: float = bar_x + float(i) * (seg_w + seg_gap)
		var seg_rect := Rect2(sx, BAR_Y + 2.0, seg_w, BAR_HEIGHT - 4.0)
		if i < filled:
			var seg_col := Color(col.r * h, col.g * h, col.b * h, 0.9)
			if _flash_timer > 0.0 and i >= filled - 3:
				seg_col = Color(h, h, h, 0.95)
			draw_rect(seg_rect, seg_col)
			var glow_rect := Rect2(sx - 1.0, BAR_Y + 1.0, seg_w + 2.0, BAR_HEIGHT - 2.0)
			draw_rect(glow_rect, Color(col.r * h, col.g * h, col.b * h, 0.15))
		else:
			draw_rect(seg_rect, Color(0.08, 0.08, 0.1, 0.5))

	# Border
	draw_rect(bar_rect, Color(col.r * h * 0.5, col.g * h * 0.5, col.b * h * 0.5, 0.4), false, 1.0)


# ── Holographic Style ────────────────────────────────────────────────

func _draw_holographic() -> void:
	var layout: Dictionary = _get_layout()
	var bar_x: float = float(layout["bar_x"])
	var bar_w: float = float(layout["bar_w"])
	var bar_rect := Rect2(bar_x, BAR_Y, bar_w, BAR_HEIGHT)
	var col: Color = _get_bar_color()
	var h: float = hdr
	var flicker: float = 1.0 - 0.1 * (0.5 + 0.5 * sin(_time * 7.0 + sin(_time * 2.3) * 3.0))

	# Percentage left of bar
	_draw_pct(float(layout["pct_x"]), col, h)

	# Glow layers
	for gi in range(3, 0, -1):
		var t: float = float(gi) / 3.0
		var expand: float = t * 4.0
		var glow_alpha: float = (1.0 - t) * 0.12 * flicker
		var glow_col := Color(col.r * h, col.g * h, col.b * h, glow_alpha)
		draw_rect(Rect2(bar_x - expand, BAR_Y - expand, bar_w + expand * 2.0, BAR_HEIGHT + expand * 2.0),
			glow_col, false, 1.5 + expand * 0.3)

	# Filled region
	var fill_w: float = bar_w * _display_ratio
	var fill_col := Color(col.r * h, col.g * h, col.b * h, 0.6 * flicker)
	draw_rect(Rect2(bar_x, BAR_Y, fill_w, BAR_HEIGHT), fill_col)

	# Scanlines
	var scan_col := Color(col.r * h * 0.3, col.g * h * 0.3, col.b * h * 0.3, 0.25 * flicker)
	var scroll_offset: float = fmod(_time * 40.0, 3.0)
	var y: float = BAR_Y + scroll_offset
	while y < BAR_Y + BAR_HEIGHT:
		draw_line(Vector2(bar_x, y), Vector2(bar_x + bar_w, y), scan_col, 1.0)
		y += 3.0

	# Border
	draw_rect(bar_rect, Color(col.r * h, col.g * h, col.b * h, 0.7 * flicker), false, 1.5)

	# Corner marks
	var cm: float = 10.0
	var cm_col := Color(col.r * h, col.g * h, col.b * h, 0.6 * flicker)
	var bx: float = bar_x
	var by: float = BAR_Y
	var bh: float = BAR_HEIGHT
	draw_line(Vector2(bx - 3.0, by - 3.0), Vector2(bx - 3.0 + cm, by - 3.0), cm_col, 1.5)
	draw_line(Vector2(bx - 3.0, by - 3.0), Vector2(bx - 3.0, by - 3.0 + cm), cm_col, 1.5)
	draw_line(Vector2(bx + bar_w + 3.0, by - 3.0), Vector2(bx + bar_w + 3.0 - cm, by - 3.0), cm_col, 1.5)
	draw_line(Vector2(bx + bar_w + 3.0, by - 3.0), Vector2(bx + bar_w + 3.0, by - 3.0 + cm), cm_col, 1.5)
	draw_line(Vector2(bx - 3.0, by + bh + 3.0), Vector2(bx - 3.0 + cm, by + bh + 3.0), cm_col, 1.5)
	draw_line(Vector2(bx - 3.0, by + bh + 3.0), Vector2(bx - 3.0, by + bh + 3.0 - cm), cm_col, 1.5)
	draw_line(Vector2(bx + bar_w + 3.0, by + bh + 3.0), Vector2(bx + bar_w + 3.0 - cm, by + bh + 3.0), cm_col, 1.5)
	draw_line(Vector2(bx + bar_w + 3.0, by + bh + 3.0), Vector2(bx + bar_w + 3.0, by + bh + 3.0 - cm), cm_col, 1.5)


# ── Percentage label (fixed-width, right-aligned, left of bar) ───────

func _draw_pct(pct_x: float, col: Color, h: float) -> void:
	var font: Font = ThemeManager.get_font("font_header")
	if not font:
		font = ThemeDB.fallback_font
	var pct: int = int(_display_ratio * 100.0)
	var pct_text: String = str(pct) + "%"
	var text_y: float = BAR_Y + BAR_HEIGHT * 0.5 + 6.0  # Vertically centered with bar
	var pct_col := Color(col.r * h, col.g * h, col.b * h, 0.85)
	# Right-align within fixed PCT_WIDTH area so changing numbers don't shift the bar
	draw_string(font, Vector2(pct_x, text_y), pct_text, HORIZONTAL_ALIGNMENT_RIGHT, int(PCT_WIDTH), 16, pct_col)


# ── Settings persistence ─────────────────────────────────────────────

func _load_settings() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not (json.data is Dictionary):
		return
	var d: Dictionary = json.data
	style = int(d.get("style", Style.LED))
	hdr = float(d.get("hdr", 2.2))
	if d.has("color_healthy"):
		var c: Array = d["color_healthy"]
		color_healthy = Color(float(c[0]), float(c[1]), float(c[2]))
	if d.has("color_damaged"):
		var c: Array = d["color_damaged"]
		color_damaged = Color(float(c[0]), float(c[1]), float(c[2]))
	if d.has("color_critical"):
		var c: Array = d["color_critical"]
		color_critical = Color(float(c[0]), float(c[1]), float(c[2]))


func save_settings() -> void:
	DirAccess.make_dir_recursive_absolute("user://settings/")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		return
	var d: Dictionary = {
		"style": style,
		"hdr": hdr,
		"color_healthy": [color_healthy.r, color_healthy.g, color_healthy.b],
		"color_damaged": [color_damaged.r, color_damaged.g, color_damaged.b],
		"color_critical": [color_critical.r, color_critical.g, color_critical.b],
	}
	file.store_string(JSON.stringify(d, "\t"))
