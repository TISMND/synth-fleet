extends MarginContainer
## Cargo counter auditions — shows various display styles for the in-game cargo HUD.
## Each style renders "CARGO: 12345" with a different aesthetic.

var _time: float = 0.0
var _demo_value: int = 12345
var _containers: Array[SubViewportContainer] = []
var _hdr_value: float = 2.5
var _hdr_labels: Array[Label] = []  # value labels that need HDR updates
var _hdr_colors: Array[Color] = []  # base colors before HDR multiply


func _ready() -> void:
	_build_ui()
	ThemeManager.theme_changed.connect(func(): queue_redraw())


func _build_ui() -> void:
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 12)
	add_child(main)

	var header := Label.new()
	header.text = "CARGO COUNTER STYLES"
	header.name = "CargoHeader"
	ThemeManager.apply_text_glow(header, "header")
	main.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(scroll)

	var grid := VBoxContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("separation", 16)
	scroll.add_child(grid)

	# HDR slider
	var hdr_row := HBoxContainer.new()
	hdr_row.add_theme_constant_override("separation", 8)
	grid.add_child(hdr_row)
	var hdr_label := Label.new()
	hdr_label.text = "HDR:"
	ThemeManager.apply_text_glow(hdr_label, "body")
	hdr_row.add_child(hdr_label)
	var hdr_slider := HSlider.new()
	hdr_slider.min_value = 0.5
	hdr_slider.max_value = 4.0
	hdr_slider.step = 0.1
	hdr_slider.value = _hdr_value
	hdr_slider.custom_minimum_size.x = 200
	hdr_slider.value_changed.connect(_on_hdr_changed)
	hdr_row.add_child(hdr_slider)
	var hdr_val_label := Label.new()
	hdr_val_label.text = str(_hdr_value)
	hdr_val_label.name = "HdrValLabel"
	hdr_row.add_child(hdr_val_label)

	_add_style(grid, "ORBITRON DIGITAL", _build_orbitron_digital)
	_add_style(grid, "OUTLINE MINIMAL", _build_outline_minimal)
	_add_style(grid, "BARE HDR", _build_bare_hdr)


func _add_style(parent: VBoxContainer, title: String, builder: Callable) -> void:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 12)
	ThemeManager.apply_text_glow(label, "body")
	parent.add_child(label)

	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.custom_minimum_size = Vector2(400, 60)
	vpc.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	parent.add_child(vpc)

	var vp := SubViewport.new()
	vp.transparent_bg = false
	vp.size = Vector2i(400, 60)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vpc.add_child(vp)
	VFXFactory.add_bloom_to_viewport(vp)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.04, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(bg)

	builder.call(vp)
	_containers.append(vpc)


# ── Style: Orbitron Digital ─────────────────────────────────────────────

func _build_orbitron_digital(vp: SubViewport) -> void:
	var container := HBoxContainer.new()
	container.position = Vector2(16, 8)
	container.add_theme_constant_override("separation", 8)
	vp.add_child(container)

	var cargo_label := Label.new()
	cargo_label.text = "CARGO:"
	var body_font: Font = ThemeManager.get_font("font_body")
	if body_font:
		cargo_label.add_theme_font_override("font", body_font)
	cargo_label.add_theme_font_size_override("font_size", 16)
	cargo_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.6, 0.6))
	container.add_child(cargo_label)

	var val_label := Label.new()
	val_label.text = str(_demo_value)
	var btn_font: Font = ThemeManager.get_font("font_button")
	if btn_font:
		val_label.add_theme_font_override("font", btn_font)
	val_label.add_theme_font_size_override("font_size", 32)
	val_label.add_theme_color_override("font_color", Color(0.2 * _hdr_value, 1.0 * _hdr_value, 0.5 * _hdr_value))
	val_label.add_theme_constant_override("outline_size", 2)
	val_label.add_theme_color_override("font_outline_color", Color(0.0, 0.2, 0.1, 0.4))
	container.add_child(val_label)
	_hdr_labels.append(val_label)
	_hdr_colors.append(Color(0.2, 1.0, 0.5))


# ── Style: Outline Minimal ─────────────────────────────────────────────

func _build_outline_minimal(vp: SubViewport) -> void:
	var label := Label.new()
	label.text = "CARGO: " + str(_demo_value)
	label.position = Vector2(16, 14)
	var font: Font = ThemeManager.get_font("font_body")
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 24)
	# Dim fill, bright outline
	label.add_theme_color_override("font_color", Color(0.1, 0.25, 0.15, 0.4))
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color(0.2 * _hdr_value, 0.9 * _hdr_value, 0.4 * _hdr_value, 0.9))
	vp.add_child(label)
	_hdr_labels.append(label)
	_hdr_colors.append(Color(0.2, 0.9, 0.4))


# ── Style: Bare HDR Digits ─────────────────────────────────────────────

func _build_bare_hdr(vp: SubViewport) -> void:
	var container := HBoxContainer.new()
	container.position = Vector2(16, 6)
	container.add_theme_constant_override("separation", 6)
	vp.add_child(container)

	var cargo_label := Label.new()
	cargo_label.text = "CARGO:"
	var header_font: Font = ThemeManager.get_font("font_header")
	if header_font:
		cargo_label.add_theme_font_override("font", header_font)
	cargo_label.add_theme_font_size_override("font_size", 20)
	cargo_label.add_theme_color_override("font_color", Color(0.4, 0.7, 0.5, 0.5))
	container.add_child(cargo_label)

	var val_label := Label.new()
	val_label.text = str(_demo_value)
	if header_font:
		val_label.add_theme_font_override("font", header_font)
	val_label.add_theme_font_size_override("font_size", 36)
	val_label.add_theme_color_override("font_color", Color(0.15 * _hdr_value, 0.9 * _hdr_value, 0.4 * _hdr_value))
	container.add_child(val_label)
	_hdr_labels.append(val_label)
	_hdr_colors.append(Color(0.15, 0.9, 0.4))


func _on_hdr_changed(val: float) -> void:
	_hdr_value = val
	# Update the readout label
	var val_label_node: Node = get_node_or_null("VBoxContainer/ScrollContainer/VBoxContainer/HBoxContainer/HdrValLabel")
	if not val_label_node:
		for child in get_children():
			var found: Node = child.find_child("HdrValLabel", true, false)
			if found:
				val_label_node = found
				break
	if val_label_node and val_label_node is Label:
		(val_label_node as Label).text = str(snapped(val, 0.1))
	# Update all registered HDR labels
	for i in range(_hdr_labels.size()):
		if not is_instance_valid(_hdr_labels[i]):
			continue
		var base: Color = _hdr_colors[i]
		var lbl: Label = _hdr_labels[i]
		# Check if this is an outline-style label (outline minimal)
		if lbl.get_theme_constant("outline_size") > 0 and lbl.get_theme_color("font_color").a < 0.5:
			lbl.add_theme_color_override("font_outline_color", Color(base.r * val, base.g * val, base.b * val, 0.9))
		else:
			lbl.add_theme_color_override("font_color", Color(base.r * val, base.g * val, base.b * val))
