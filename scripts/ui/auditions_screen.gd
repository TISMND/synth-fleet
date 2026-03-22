extends Control
## Auditions screen — side-by-side comparison of bar bezel/frame treatments.
## Each variant uses HudBuilder.build_side_panel("game", ...) for bars — the exact
## same rendering code, shaders, HDR glow rects, and chrome panel as the in-game HUD.
## Bars render directly on root viewport so they bloom identically to the game
## (root WorldEnvironment has glow_enabled = true, LINEAR tonemapping).
## Bezels are positioned AFTER layout settles via call_deferred — bars are never
## reparented or structurally modified.

const VARIANT_WIDTH: int = 90
const VARIANT_HEIGHT: int = 500
const VARIANT_SPACING: int = 30
const FILL_RATIO: float = 0.5
const BEZEL_PAD: int = 10  # pixels of bezel frame around each bar

# Gain pulse demo
const PULSE_INTERVAL_MIN: float = 1.5
const PULSE_INTERVAL_MAX: float = 3.5
const WAVE_SPEED: float = 2.5

var _vhs_overlay: ColorRect
var _bg: ColorRect
var _scroll: ScrollContainer
var _variants_hbox: HBoxContainer
var _title_label: Label
var _back_button: Button
var _bezel_shader: Shader
var _bezel_seg_shader: Shader
var _pulse_timer: float = 2.0

# Each variant: {name, params, no_bezel, name_label, panel_data, panel_root,
#                bar_entries: [{bar, seg, wave_pos, wave_active}],
#                bezel_rects: [ColorRect]}
var _variants: Array = []

## FINAL AUDITION: Current HUD vs proposed replacement.
## The replacement combines all winning choices:
##   - Near Black chrome panel background
##   - Per-segment shadow-grounded sockets (bar_bezel_segments.gdshader)
##   - Subtle HDR labels (font_color * 1.5, soft aura + bloom via text_glow shader)
##
## To apply this to the game HUD, another agent should:
##   1. Apply _REPLACEMENT_CHROME overrides to the chrome_panel shader in HudBuilder
##   2. Create socket bezel overlays in hud.gd using _REPLACEMENT_SOCKET params
##   3. Apply _REPLACEMENT_LABEL glow/HDR to bar labels in HudBuilder.apply_bar_label_theme

# ── Replacement spec (for the next agent to reference) ──

const _REPLACEMENT_SOCKET: Dictionary = {
	"socket_bezel": 0.16, "socket_radius": 0.04,
	"inner_shadow_intensity": 1.3, "inner_shadow_softness": 0.3,
	"shadow_direction": 0.5, "bevel_intensity": 0.35, "bevel_softness": 0.35,
	"rim_intensity": 0.0,
	"metal_color": Color(0.03, 0.03, 0.04, 1.0), "metal_roughness": 0.2,
	"outer_shadow_intensity": 0.8, "outer_shadow_size": 0.09,
	"depth_scale": 1.4,
}
const _REPLACEMENT_CHROME: Dictionary = {
	"base_color": Vector4(0.02, 0.02, 0.03, 1.0),
	"chrome_top_brightness": 0.3,
	"chrome_base_brightness": 0.15,
	"highlight_intensity": 0.06,
	"edge_brightness": 0.02,
}
const _REPLACEMENT_LABEL: Dictionary = {
	"hdr_mult": 1.5,
	"glow_aura_size": 3.0,
	"glow_aura_intensity": 0.8,
	"glow_bloom_size": 6.0,
	"glow_bloom_intensity": 0.4,
}

const PRESETS: Array = [
	{
		"name": "CURRENT\nHUD",
		"params": {},
		"no_bezel": true,
	},
	{
		"name": "PROPOSED\nREPLACEMENT",
		"per_segment": true,
		"params": _REPLACEMENT_SOCKET,
		"chrome": _REPLACEMENT_CHROME,
		"label": _REPLACEMENT_LABEL,
	},
]


func _ready() -> void:
	_bezel_shader = load("res://assets/shaders/bar_bezel.gdshader") as Shader
	_bezel_seg_shader = load("res://assets/shaders/bar_bezel_segments.gdshader") as Shader
	_build_ui()
	_apply_theme()
	ThemeManager.theme_changed.connect(_apply_theme)


func _process(delta: float) -> void:
	_update_pulses(delta)


func _build_ui() -> void:
	# Grid background
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	ThemeManager.apply_grid_background(_bg)

	# Main layout
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 16)
	var margin := 20
	main_vbox.offset_left = margin
	main_vbox.offset_top = margin
	main_vbox.offset_right = -margin
	main_vbox.offset_bottom = -margin
	add_child(main_vbox)

	# Header row
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 20)
	main_vbox.add_child(header_hbox)

	_back_button = Button.new()
	_back_button.text = "BACK"
	_back_button.pressed.connect(_on_back)
	header_hbox.add_child(_back_button)

	_title_label = Label.new()
	_title_label.text = "AUDITIONS — Bar Bezels"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(_title_label)

	# Scrollable area for variants
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(_scroll)

	_variants_hbox = HBoxContainer.new()
	_variants_hbox.add_theme_constant_override("separation", VARIANT_SPACING)
	_variants_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_variants_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_variants_hbox)

	for i in PRESETS.size():
		_build_variant(i)

	# Bezels must be placed AFTER layout settles so we can read bar positions
	call_deferred("_place_bezels")

	_setup_vhs_overlay()


func _build_variant(index: int) -> void:
	var preset: Dictionary = PRESETS[index]
	var preset_name: String = str(preset["name"])
	var params: Dictionary = preset["params"]
	var no_bezel: bool = preset.get("no_bezel", false) as bool

	# Outer container for label + panel
	var variant_vbox := VBoxContainer.new()
	variant_vbox.add_theme_constant_override("separation", 8)
	variant_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_variants_hbox.add_child(variant_vbox)

	# Variant name label
	var name_label := Label.new()
	name_label.text = preset_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	variant_vbox.add_child(name_label)

	# Panel holder — sizing container for the HBoxContainer layout.
	# NO clip_contents — let led_glow HDR bleed naturally for root viewport bloom.
	var panel_holder := Control.new()
	panel_holder.custom_minimum_size = Vector2(VARIANT_WIDTH, VARIANT_HEIGHT)
	panel_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	variant_vbox.add_child(panel_holder)

	# Build side panel via HudBuilder — exact same code path as game HUD.
	# "game" mode creates: ColorRect with chrome_panel shader → main_vbox →
	# zones with spacer → bar → pad → label → pad. Bars stay untouched.
	var panel_data: Dictionary = HudBuilder.build_side_panel(
		"game", ["SHIELD", "HULL"], {}, float(VARIANT_HEIGHT)
	)
	var panel_root: ColorRect = panel_data["root"]
	panel_root.position = Vector2.ZERO
	panel_root.size = Vector2(VARIANT_WIDTH, VARIANT_HEIGHT)
	panel_holder.add_child(panel_root)

	# Apply chrome panel overrides if preset specifies custom background look
	var chrome_overrides: Dictionary = preset.get("chrome", {}) as Dictionary
	if not chrome_overrides.is_empty() and panel_root.material is ShaderMaterial:
		var chrome_mat: ShaderMaterial = panel_root.material as ShaderMaterial
		for key in chrome_overrides:
			chrome_mat.set_shader_parameter(key, chrome_overrides[key])

	# Apply fill ratio, colors, and label theming — NO structural changes to bars.
	var bars: Dictionary = panel_data["bars"]
	var bar_entries: Array = []
	var specs: Array = ThemeManager.get_status_bar_specs()
	for spec in specs:
		var bar_name: String = str(spec["name"])
		if not bars.has(bar_name):
			continue
		var entry: Dictionary = bars[bar_name]
		var bar: ProgressBar = entry["bar"]
		var lbl: Label = entry["label"]
		var color: Color = ThemeManager.resolve_bar_color(spec)
		var seg: int = int(ShipData.DEFAULT_SEGMENTS.get(bar_name, 8))
		var is_vertical: bool = entry.get("vertical", false) as bool

		# Set fill to 50%
		bar.max_value = seg
		bar.value = int(float(seg) * FILL_RATIO)
		bar.custom_minimum_size.x = HudBuilder.BAR_WIDTH
		ThemeManager.apply_led_bar(bar, color, FILL_RATIO, seg, is_vertical)

		# Theme bar label — base styling from HudBuilder, then per-variant overrides
		var body_font: Font = ThemeManager.get_font("font_body")
		var body_size: int = ThemeManager.get_font_size("font_size_body")
		HudBuilder.apply_bar_label_theme(lbl, color, body_font, body_size)

		var label_cfg: Dictionary = preset.get("label", {}) as Dictionary
		_apply_label_overrides(lbl, color, label_cfg)

		bar_entries.append({
			"bar": bar,
			"seg": seg,
			"wave_pos": -1.0,
			"wave_active": false,
		})

	var per_segment: bool = preset.get("per_segment", false) as bool
	var border_params: Dictionary = preset.get("border", {}) as Dictionary
	var label_cfg: Dictionary = preset.get("label", {}) as Dictionary
	_variants.append({
		"name": preset_name,
		"params": params,
		"no_bezel": no_bezel,
		"per_segment": per_segment,
		"border": border_params,
		"chrome": chrome_overrides,
		"label": label_cfg,
		"name_label": name_label,
		"panel_data": panel_data,
		"panel_root": panel_root,
		"bar_entries": bar_entries,
		"bezel_rects": [],
		"border_rects": [],
	})


# ── Deferred bezel placement ────────────────────────────────────

func _place_bezels() -> void:
	## Called via call_deferred after layout settles. Creates bezel overlays:
	## 1. Outer border (bar_bezel.gdshader) — whole-bar frame, if "border" dict present
	## 2. Per-segment sockets (bar_bezel_segments.gdshader) — individual LED frames
	## Both layers use transparent cutouts so bars show through.
	for variant in _variants:
		if bool(variant["no_bezel"]):
			continue
		var panel_root: ColorRect = variant["panel_root"]
		var params: Dictionary = variant["params"]
		var border_params: Dictionary = variant["border"]
		var bars: Dictionary = variant["panel_data"]["bars"]
		var bar_entries: Array = variant["bar_entries"]
		var bezel_rects: Array = variant["bezel_rects"]
		var border_rects: Array = variant["border_rects"]

		var be_idx: int = 0
		var specs: Array = ThemeManager.get_status_bar_specs()
		for spec in specs:
			var bar_name: String = str(spec["name"])
			if not bars.has(bar_name):
				continue
			var bar: ProgressBar = bars[bar_name]["bar"]
			var seg: int = int(bar_entries[be_idx]["seg"]) if be_idx < bar_entries.size() else 8
			be_idx += 1

			var bar_pos: Vector2 = bar.global_position - panel_root.global_position
			var pad: float = float(BEZEL_PAD)

			# Layer 1: outer border frame (if present).
			# Compute bezel_width dynamically so the cutout aligns exactly with
			# the bar bounds — no visible gap between border and segments.
			if not border_params.is_empty() and _bezel_shader:
				var border_rect := ColorRect.new()
				border_rect.position = Vector2(bar_pos.x - pad, bar_pos.y - pad)
				var brd_size := Vector2(bar.size.x + pad * 2.0, bar.size.y + pad * 2.0)
				border_rect.size = brd_size
				border_rect.color = Color.WHITE
				border_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var bmat := ShaderMaterial.new()
				bmat.shader = _bezel_shader
				_apply_bezel_params(bmat, border_params)
				# Override bezel_width so cutout = bar bounds exactly.
				# bezel_width is in UV-x space; pad / border_width gives the fraction.
				bmat.set_shader_parameter("bezel_width", pad / maxf(brd_size.x, 1.0))
				border_rect.material = bmat
				panel_root.add_child(border_rect)
				border_rects.append(border_rect)

			# Layer 2: per-segment sockets.
			# Extend rect by BEZEL_PAD on all sides so end segments get full
			# bezel frames. edge_pad_x/y tell the shader where the bar region is.
			if _bezel_seg_shader:
				var seg_rect := ColorRect.new()
				seg_rect.position = Vector2(bar_pos.x - pad, bar_pos.y - pad)
				var seg_size := Vector2(bar.size.x + pad * 2.0, bar.size.y + pad * 2.0)
				seg_rect.size = seg_size
				seg_rect.color = Color.WHITE
				seg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var smat := ShaderMaterial.new()
				smat.shader = _bezel_seg_shader
				_apply_bezel_params(smat, params)
				smat.set_shader_parameter("segment_count", seg)
				if bar.material is ShaderMaterial:
					var bar_mat: ShaderMaterial = bar.material as ShaderMaterial
					smat.set_shader_parameter("segment_gap", bar_mat.get_shader_parameter("segment_gap"))
				smat.set_shader_parameter("vertical", 1)
				# Padding in UV space — tells shader where the bar grid lives
				# For vertical: uv.x = along segments (maps to rect height),
				# uv.y = across bar (maps to rect width).
				# edge_pad_x = padding along segments = pad / seg_rect_height (in uv after remap)
				# edge_pad_y = padding across bar = pad / seg_rect_width (in uv after remap)
				if seg_size.y > 0.0 and seg_size.x > 0.0:
					smat.set_shader_parameter("edge_pad_x", pad / seg_size.y)
					smat.set_shader_parameter("edge_pad_y", pad / seg_size.x)
				seg_rect.material = smat
				panel_root.add_child(seg_rect)
				bezel_rects.append(seg_rect)


func _reposition_bezels() -> void:
	## Re-reads bar positions and updates bezel/border rects after theme changes.
	var pad: float = float(BEZEL_PAD)
	for variant in _variants:
		if bool(variant["no_bezel"]):
			continue
		var panel_root: ColorRect = variant["panel_root"]
		var bars: Dictionary = variant["panel_data"]["bars"]
		var bezel_rects: Array = variant["bezel_rects"]
		var border_rects: Array = variant["border_rects"]

		var seg_idx: int = 0
		var brd_idx: int = 0
		var specs: Array = ThemeManager.get_status_bar_specs()
		for spec in specs:
			var bar_name: String = str(spec["name"])
			if not bars.has(bar_name):
				continue
			var bar: ProgressBar = bars[bar_name]["bar"]
			var bar_pos: Vector2 = bar.global_position - panel_root.global_position
			var full_pos := Vector2(bar_pos.x - pad, bar_pos.y - pad)
			var full_size := Vector2(bar.size.x + pad * 2.0, bar.size.y + pad * 2.0)

			if brd_idx < border_rects.size():
				var brect: ColorRect = border_rects[brd_idx]
				brect.position = full_pos
				brect.size = full_size
				brd_idx += 1

			if seg_idx < bezel_rects.size():
				var srect: ColorRect = bezel_rects[seg_idx]
				srect.position = full_pos
				srect.size = full_size
				seg_idx += 1


func _apply_bezel_params(mat: ShaderMaterial, params: Dictionary) -> void:
	for key in params:
		var value = params[key]
		mat.set_shader_parameter(key, value)


func _apply_label_overrides(lbl: Label, bar_color: Color, cfg: Dictionary) -> void:
	## Apply per-variant label overrides: font, size, glow shader params, HDR bloom.
	if cfg.is_empty():
		return

	# Font override
	var font_path: String = str(cfg.get("font_path", ""))
	if font_path != "":
		var font: Font = load(font_path) as Font
		if font:
			lbl.add_theme_font_override("font", font)

	# Size override
	var font_size: int = int(cfg.get("font_size", 0))
	if font_size > 0:
		lbl.add_theme_font_size_override("font_size", font_size)

	# Glow shader overrides — apply text_glow shader with custom params
	var has_glow: bool = float(cfg.get("glow_aura_size", 0.0)) > 0.0 or float(cfg.get("glow_bloom_size", 0.0)) > 0.0
	if has_glow:
		var glow_shader: Shader = load("res://assets/shaders/text_glow.gdshader") as Shader
		if glow_shader:
			var mat: ShaderMaterial
			if lbl.material is ShaderMaterial:
				mat = lbl.material as ShaderMaterial
			else:
				mat = ShaderMaterial.new()
				mat.shader = glow_shader
				lbl.material = mat
			mat.set_shader_parameter("inner_intensity", float(cfg.get("glow_inner_intensity", 0.3)))
			mat.set_shader_parameter("aura_size", float(cfg.get("glow_aura_size", 0.0)))
			mat.set_shader_parameter("aura_intensity", float(cfg.get("glow_aura_intensity", 0.0)))
			mat.set_shader_parameter("bloom_size", float(cfg.get("glow_bloom_size", 0.0)))
			mat.set_shader_parameter("bloom_intensity", float(cfg.get("glow_bloom_intensity", 0.0)))
			mat.set_shader_parameter("smudge_blur", float(cfg.get("glow_smudge_blur", 0.0)))

	# HDR bloom via font_color > 1.0. Godot's Label preserves HDR color values
	# and the root viewport WorldEnvironment bloom picks them up — no ColorRect needed.
	var hdr_mult: float = float(cfg.get("hdr_mult", 0.0))
	if hdr_mult > 1.0:
		var hdr_color := Color(
			bar_color.r * hdr_mult,
			bar_color.g * hdr_mult,
			bar_color.b * hdr_mult,
			1.0
		)
		lbl.add_theme_color_override("font_color", hdr_color)


# ── Gain pulse animation ────────────────────────────────────────

func _update_pulses(delta: float) -> void:
	_pulse_timer -= delta
	if _pulse_timer <= 0.0:
		_trigger_random_pulse()
		_pulse_timer = randf_range(PULSE_INTERVAL_MIN, PULSE_INTERVAL_MAX)

	# Advance all active waves
	for variant in _variants:
		var bar_entries: Array = variant["bar_entries"]
		for entry in bar_entries:
			if not bool(entry["wave_active"]):
				continue
			var pos: float = float(entry["wave_pos"])
			pos += WAVE_SPEED * delta
			if pos > 1.3:
				entry["wave_active"] = false
				entry["wave_pos"] = -1.0
			else:
				entry["wave_pos"] = pos

			# Update shader uniform — same as game HUD _apply_wave_uniforms
			var bar: ProgressBar = entry["bar"]
			if bar.material is ShaderMaterial:
				var mat: ShaderMaterial = bar.material as ShaderMaterial
				var wave_val: float = float(entry["wave_pos"]) if bool(entry["wave_active"]) else -1.0
				mat.set_shader_parameter("gain_wave_pos", wave_val)


func _trigger_random_pulse() -> void:
	if _variants.is_empty():
		return
	var vi: int = randi_range(0, _variants.size() - 1)
	var variant: Dictionary = _variants[vi]
	var bar_entries: Array = variant["bar_entries"]
	if bar_entries.is_empty():
		return
	var bi: int = randi_range(0, bar_entries.size() - 1)
	var entry: Dictionary = bar_entries[bi]
	if not bool(entry["wave_active"]):
		entry["wave_pos"] = 0.0
	entry["wave_active"] = true


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

	for variant in _variants:
		# Variant name label
		var name_lbl: Label = variant["name_label"]
		name_lbl.add_theme_font_size_override("font_size", body_size)
		name_lbl.add_theme_color_override("font_color", ThemeManager.get_color("body"))
		if body_font:
			name_lbl.add_theme_font_override("font", body_font)
		ThemeManager.apply_text_glow(name_lbl, "body")

		# Chrome panel — update divider accent + reapply custom overrides
		var panel_root: ColorRect = variant["panel_root"]
		if panel_root.material is ShaderMaterial:
			var chrome_mat: ShaderMaterial = panel_root.material as ShaderMaterial
			chrome_mat.set_shader_parameter("divider_color", Vector4(accent.r, accent.g, accent.b, 0.5))
			var chrome_ov: Dictionary = variant["chrome"]
			for key in chrome_ov:
				chrome_mat.set_shader_parameter(key, chrome_ov[key])

		# Re-apply LED bars and bar labels — pass stored segment count (never -1)
		var panel_data: Dictionary = variant["panel_data"]
		var bars: Dictionary = panel_data["bars"]
		var bar_entries: Array = variant["bar_entries"]
		var be_idx: int = 0
		var specs: Array = ThemeManager.get_status_bar_specs()
		for spec in specs:
			var bar_name: String = str(spec["name"])
			if not bars.has(bar_name):
				continue
			var entry: Dictionary = bars[bar_name]
			var color: Color = ThemeManager.resolve_bar_color(spec)
			var bar: ProgressBar = entry["bar"]
			var is_vertical: bool = entry.get("vertical", false) as bool
			var seg: int = int(bar_entries[be_idx]["seg"]) if be_idx < bar_entries.size() else 8
			bar.custom_minimum_size.x = HudBuilder.BAR_WIDTH
			ThemeManager.apply_led_bar(bar, color, FILL_RATIO, seg, is_vertical)
			HudBuilder.apply_bar_label_theme(entry["label"], color, body_font, body_size)
			var lcfg: Dictionary = variant["label"]
			_apply_label_overrides(entry["label"], color, lcfg)
			be_idx += 1

	# Reposition bezels after bars may have changed size
	call_deferred("_reposition_bezels")


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
