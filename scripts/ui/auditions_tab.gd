extends MarginContainer
## Powerups tab — side-by-side grid of powerup items at adjustable sizes for visual comparison.

var _items: Array[ItemData] = []
var _grid_content: VBoxContainer
var _current_size: float = 48.0
var _size_buttons: Array[Button] = []

const SIZES: Dictionary = {"SM": 24.0, "MD": 36.0, "LG": 48.0, "XL": 64.0}
const CELL_PADDING: int = 8


func _ready() -> void:
	_build_ui()
	ThemeManager.theme_changed.connect(_apply_theme)
	call_deferred("_apply_theme")
	call_deferred("_rebuild_grid")


func _build_ui() -> void:
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 8)
	add_child(main)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	main.add_child(controls)

	var header := Label.new()
	header.text = "AUDITIONS"
	header.name = "AuditionHeader"
	controls.add_child(header)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(spacer)

	var size_label := Label.new()
	size_label.text = "Size:"
	controls.add_child(size_label)

	for size_name in SIZES:
		var btn := Button.new()
		btn.text = size_name
		btn.toggle_mode = true
		btn.button_pressed = (size_name == "LG")
		btn.pressed.connect(_on_size_pressed.bind(size_name))
		controls.add_child(btn)
		ThemeManager.apply_button_style(btn)
		_size_buttons.append(btn)

	var refresh := Button.new()
	refresh.text = "REFRESH"
	refresh.name = "RefreshButton"
	refresh.pressed.connect(_rebuild_grid)
	controls.add_child(refresh)
	ThemeManager.apply_button_style(refresh)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(scroll)

	_grid_content = VBoxContainer.new()
	_grid_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_content.add_theme_constant_override("separation", 16)
	scroll.add_child(_grid_content)


func _rebuild_grid() -> void:
	for child in _grid_content.get_children():
		child.queue_free()

	_items = ItemDataManager.load_all()

	var powerup_items: Array[ItemData] = []
	var shape_items: Array[ItemData] = []
	for item in _items:
		if item.display_name.begins_with("Shape:"):
			shape_items.append(item)
		elif item.category != "money":
			powerup_items.append(item)

	if powerup_items.size() > 0:
		_add_section("POWERUPS", powerup_items)
	if shape_items.size() > 0:
		_add_section("SHAPES", shape_items)


func _add_section(title: String, items: Array[ItemData]) -> void:
	var label := Label.new()
	label.text = title
	_grid_content.add_child(label)
	ThemeManager.apply_text_glow(label, "header")

	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", CELL_PADDING)
	flow.add_theme_constant_override("v_separation", CELL_PADDING)
	_grid_content.add_child(flow)

	for item in items:
		_add_item_cell(flow, item)


func _add_item_cell(parent: HFlowContainer, item: ItemData) -> void:
	var cell_px: float = _current_size * 2.2
	var vp_size: int = int(cell_px)

	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 2)
	parent.add_child(card)

	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.custom_minimum_size = Vector2(cell_px, cell_px)
	vpc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.add_child(vpc)

	var vp := SubViewport.new()
	vp.transparent_bg = false
	vp.size = Vector2i(vp_size, vp_size)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vpc.add_child(vp)
	VFXFactory.add_bloom_to_viewport(vp)

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.07, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(bg)

	var render_size: float = _current_size * 0.45

	var renderer := ItemRenderer.new()
	renderer.position = Vector2(cell_px / 2.0, cell_px / 2.0)
	renderer.setup(item, render_size)
	vp.add_child(renderer)

	var name_label := Label.new()
	name_label.text = item.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size.x = cell_px
	name_label.add_theme_font_size_override("font_size", 10)
	ThemeManager.apply_text_glow(name_label, "body")
	card.add_child(name_label)

	# Per-item HDR intensity slider
	var slider_row := HBoxContainer.new()
	slider_row.add_theme_constant_override("separation", 4)
	slider_row.custom_minimum_size.x = cell_px
	card.add_child(slider_row)

	var hdr_label := Label.new()
	hdr_label.text = "HDR"
	hdr_label.add_theme_font_size_override("font_size", 9)
	slider_row.add_child(hdr_label)

	var slider := HSlider.new()
	slider.min_value = 0.5
	slider.max_value = 4.0
	slider.step = 0.1
	slider.value = item.hdr_intensity
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_on_item_hdr_changed.bind(item, renderer))
	slider_row.add_child(slider)


func _on_item_hdr_changed(val: float, item: ItemData, renderer: ItemRenderer) -> void:
	item.hdr_intensity = val
	ItemDataManager.save(item)
	renderer.queue_redraw()


func _on_size_pressed(size_name: String) -> void:
	_current_size = SIZES[size_name]
	for btn in _size_buttons:
		btn.button_pressed = (btn.text == size_name)
	_rebuild_grid()


func _apply_theme() -> void:
	_rebuild_grid()
