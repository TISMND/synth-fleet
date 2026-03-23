extends Control
## Auditions screen — bottom HUD bar variants with Components + Fire Groups sections.
## All variants use HudBuilder.build_bottom_panel() — the exact same rendering
## code, shaders, HDR glow rects, and chrome panel as the in-game HUD.
## Renders directly on root viewport so bloom is identical to the game.

const BOTTOM_VARIANT_WIDTH: int = 900
const WARNING_FLASH_SPEED: float = 3.0

var _vhs_overlay: ColorRect
var _bg: ColorRect
var _title_label: Label
var _back_button: Button
var _bottom_variants: Array = []
var _warning_flash_time: float = 0.0
var _section_labels: Array = []  # screen section headers (not bar-style labels)

# Mock icon data — colors resolved at build time from ThemeManager to match hangar
const MOCK_ICON_DEFS: Array = [
	{"number": 1, "active": true, "type": "weapon"},
	{"number": 2, "active": true, "type": "weapon"},
	{"number": 3, "active": false, "type": "weapon"},
	{"number": 4, "active": true, "type": "weapon"},
	{"number": 5, "active": false, "type": "core"},
	{"number": 6, "active": true, "type": "field"},
]

# Mock fire groups — key labels and patterns from KeyBindingManager structure
const MOCK_FIRE_GROUPS: Array = [
	{"key_label": "F1", "pattern_label": "2W+1C", "active": false},
	{"key_label": "F2", "pattern_label": "3W+1F", "active": true},
	{"key_label": "Z", "pattern_label": "ALL", "active": false},
]

## WINNER: 96px tall, 180x44 warning screens, center_gap=100, labels above, lit bg icons.
const BOTTOM_PRESETS: Array = [
	{
		"name": "WINNER — 96px, medium center gap, lit bg",
		"mode": "new",
		"height": 96,
		"overrides": {"warning_width": 180, "warning_height": 44, "center_gap": 100},
	},
]


func _ready() -> void:
	_build_ui()
	_apply_theme()
	ThemeManager.theme_changed.connect(_apply_theme)


func _process(delta: float) -> void:
	_update_bottom_bar_animations(delta)


func _build_ui() -> void:
	# Grid background
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	ThemeManager.apply_grid_background(_bg)

	# Main layout — scrollable vertically
	var main_scroll := ScrollContainer.new()
	main_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var margin_val := 20
	main_scroll.offset_left = margin_val
	main_scroll.offset_top = margin_val
	main_scroll.offset_right = -margin_val
	main_scroll.offset_bottom = -margin_val
	add_child(main_scroll)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 16)
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_scroll.add_child(main_vbox)

	# Header row
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 20)
	main_vbox.add_child(header_hbox)

	_back_button = Button.new()
	_back_button.text = "BACK"
	_back_button.pressed.connect(_on_back)
	header_hbox.add_child(_back_button)

	_title_label = Label.new()
	_title_label.text = "AUDITIONS — Bottom Bar"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(_title_label)

	# Section label
	var section_label := Label.new()
	section_label.text = "BOTTOM BAR VARIANTS"
	main_vbox.add_child(section_label)
	_section_labels.append(section_label)

	# Variants
	var bottom_vbox := VBoxContainer.new()
	bottom_vbox.add_theme_constant_override("separation", 24)
	bottom_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(bottom_vbox)

	for i in BOTTOM_PRESETS.size():
		_build_bottom_variant(i, bottom_vbox)

	_setup_vhs_overlay()


func _resolve_mock_icons() -> Array:
	## Build icon_data with live ThemeManager colors matching hangar.
	var weapon_color: Color = ThemeManager.get_color("bar_shield")   # Cyan
	var core_color: Color = ThemeManager.get_color("bar_electric")   # Yellow
	var field_color := Color(0.2, 0.8, 1.0)                         # Teal
	var icons: Array = []
	for def in MOCK_ICON_DEFS:
		var icon_type: String = str(def["type"])
		var color: Color = weapon_color
		if icon_type == "core":
			color = core_color
		elif icon_type == "field":
			color = field_color
		icons.append({
			"number": int(def["number"]),
			"active": def["active"],
			"color": color,
			"type": icon_type,
		})
	return icons


# ── Bottom bar variant builder ──────────────────────────────────

func _build_bottom_variant(index: int, parent: VBoxContainer) -> void:
	var preset: Dictionary = BOTTOM_PRESETS[index]
	var preset_name: String = str(preset["name"])
	var mode: String = str(preset["mode"])
	var bar_height: int = int(preset.get("height", 80))
	var overrides: Dictionary = preset.get("overrides", {}) as Dictionary

	# Variant name label
	var name_label := Label.new()
	name_label.text = preset_name
	parent.add_child(name_label)

	var icons: Array = _resolve_mock_icons()

	if mode == "current":
		# Show the current flat bottom bar for comparison
		var current_bar: Dictionary = HudBuilder._build_bottom_bar("game")
		var bar_root: Control = current_bar["root"]
		bar_root.custom_minimum_size = Vector2(BOTTOM_VARIANT_WIDTH, bar_height)
		parent.add_child(bar_root)
		var weapons_hbox: HBoxContainer = current_bar["weapons_hbox"]
		for idata in icons:
			var icon_number: int = int(idata["number"])
			var icon_active: bool = idata["active"]
			var icon_color: Color = idata["color"]
			var icon: Dictionary = HudBuilder.build_weapon_icon(icon_number, icon_active, icon_color)
			weapons_hbox.add_child(icon["container"])

		_bottom_variants.append({
			"name_label": name_label,
			"panel_result": {},
			"icon_entries": [],
			"fg_entries": [],
			"warning_labels": [],
			"bar_section_labels": [],
			"mode": mode,
		})
		return

	# Build redesigned bottom panel
	var panel_result: Dictionary = HudBuilder.build_bottom_panel(
		icons, MOCK_FIRE_GROUPS, float(BOTTOM_VARIANT_WIDTH), float(bar_height), overrides
	)
	var panel_root: Control = panel_result["root"]
	panel_root.custom_minimum_size = Vector2(BOTTOM_VARIANT_WIDTH, bar_height)
	parent.add_child(panel_root)

	_bottom_variants.append({
		"name_label": name_label,
		"panel_result": panel_result,
		"icon_entries": panel_result["icon_entries"],
		"fg_entries": panel_result["fg_entries"],
		"warning_labels": panel_result["warning_labels"],
		"bar_section_labels": panel_result["section_labels"],
		"mode": mode,
	})


# ── Bottom bar animations ──────────────────────────────────────

func _update_bottom_bar_animations(delta: float) -> void:
	_warning_flash_time += delta * WARNING_FLASH_SPEED

	for variant in _bottom_variants:
		var mode: String = str(variant["mode"])
		if mode == "current":
			continue

		var warning_labels: Array = variant["warning_labels"]
		var warning_color := Color(1.0, 0.2, 0.1)

		var cycle_idx: int = int(fmod(_warning_flash_time * 0.3, 4.0))
		var messages: Array = ["FIRE", "HULL BREACH", "SHIELD CRITICAL", "POWER FAILURE"]
		var flash: bool = fmod(_warning_flash_time, 2.0) < 1.4
		for i in warning_labels.size():
			var lbl: Label = warning_labels[i]
			if flash:
				lbl.text = str(messages[cycle_idx])
			HudBuilder.set_warning_active(lbl, flash, warning_color)


# ── Theme ────────────────────────────────────────────────────────

func _apply_theme() -> void:
	if _bg:
		ThemeManager.apply_grid_background(_bg)
	if _back_button:
		ThemeManager.apply_button_style(_back_button)
	if _title_label:
		ThemeManager.apply_text_glow(_title_label, "header")
		_title_label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
		var header_font: Font = ThemeManager.get_font("font_header")
		if header_font:
			_title_label.add_theme_font_override("font", header_font)
		_title_label.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	if _vhs_overlay:
		ThemeManager.apply_vhs_overlay(_vhs_overlay)

	var body_font: Font = ThemeManager.get_font("font_body")
	var body_size: int = ThemeManager.get_font_size("font_size_body")
	var accent: Color = ThemeManager.get_color("accent")

	# Screen section headers (the "BOTTOM BAR VARIANTS" header)
	for slbl in _section_labels:
		var section_lbl: Label = slbl as Label
		if section_lbl:
			section_lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
			section_lbl.add_theme_color_override("font_color", accent)
			var hfont: Font = ThemeManager.get_font("font_header")
			if hfont:
				section_lbl.add_theme_font_override("font", hfont)
			ThemeManager.apply_text_glow(section_lbl, "header")

	# Bottom bar variants
	for bv in _bottom_variants:
		# Variant name label
		var blbl: Label = bv["name_label"]
		blbl.add_theme_font_size_override("font_size", body_size)
		blbl.add_theme_color_override("font_color", ThemeManager.get_color("body"))
		if body_font:
			blbl.add_theme_font_override("font", body_font)
		ThemeManager.apply_text_glow(blbl, "body")

		# Icon themes (component + fire group)
		var icon_entries: Array = bv["icon_entries"]
		for entry in icon_entries:
			HudBuilder.apply_bezeled_icon_theme(entry)
		var fg_entries: Array = bv["fg_entries"]
		for entry in fg_entries:
			HudBuilder.apply_bezeled_icon_theme(entry)

		# Bar-style section labels (COMPONENTS, FIRE GROUPS) — re-apply on theme change
		var bar_labels: Array = bv["bar_section_labels"]
		for slbl in bar_labels:
			HudBuilder.apply_section_label_theme(slbl)


func _setup_vhs_overlay() -> void:
	var vhs_layer := CanvasLayer.new()
	vhs_layer.layer = 10
	add_child(vhs_layer)
	_vhs_overlay = ColorRect.new()
	_vhs_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vhs_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vhs_layer.add_child(_vhs_overlay)
	ThemeManager.apply_vhs_overlay(_vhs_overlay)


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/dev_studio_menu.tscn")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
