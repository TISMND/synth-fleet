class_name FieldEmittersTab
extends DeviceTabBase
## Field Emitters tab — editor for field-type devices (force fields, shields, auras).

# Visual subtab controls
var _radius_slider: HSlider
var _radius_label: Label
var _field_style_button: OptionButton
var _fade_in_slider: HSlider
var _fade_in_label: Label
var _fade_out_slider: HSlider
var _fade_out_label: Label
var _anim_speed_slider: HSlider
var _anim_speed_label: Label

# Preview
var _preview_field_sprite: Sprite2D = null
var _preview_field_material: ShaderMaterial = null


func _get_visual_mode() -> String:
	return "field"

func _get_type_label() -> String:
	return "FIELD EMITTER"

func _get_id_prefix() -> String:
	return "fem_"

func _save_data(id: String, data: Dictionary) -> void:
	FieldEmitterDataManager.save(id, data)

func _delete_data(id: String) -> void:
	FieldEmitterDataManager.delete(id)

func _list_ids() -> Array[String]:
	return FieldEmitterDataManager.list_ids()

func _load_data(id: String) -> DeviceData:
	return FieldEmitterDataManager.load_by_id(id)


func _build_visual_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(form)

	# Radius
	_add_section_header(form, "RADIUS")
	var radius_row: Array = _add_slider_row(form, "Radius:", 20.0, 300.0, 100.0, 5.0)
	_radius_slider = radius_row[0]
	_radius_label = radius_row[1]

	_add_separator(form)

	# Field Style selector
	_add_section_header(form, "FIELD STYLE")
	_field_style_button = OptionButton.new()
	_field_style_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_field_style_button.add_item("(none)")
	_refresh_field_style_list()
	_field_style_button.item_selected.connect(func(_idx: int) -> void:
		_mark_dirty()
		_update_visual_preview()
	)
	form.add_child(_field_style_button)

	_add_separator(form)

	# Fade durations
	_add_section_header(form, "FADE")
	var fi_row: Array = _add_slider_row(form, "Fade In (s):", 0.0, 2.0, 0.3, 0.05)
	_fade_in_slider = fi_row[0]
	_fade_in_label = fi_row[1]

	var fo_row: Array = _add_slider_row(form, "Fade Out (s):", 0.0, 2.0, 0.3, 0.05)
	_fade_out_slider = fo_row[0]
	_fade_out_label = fo_row[1]

	_add_separator(form)

	# Animation speed
	_add_section_header(form, "ANIMATION")
	var anim_row: Array = _add_slider_row(form, "Anim Speed:", 0.1, 3.0, 1.0, 0.1)
	_anim_speed_slider = anim_row[0]
	_anim_speed_label = anim_row[1]

	return scroll


func _setup_visual_preview(viewport: SubViewport) -> void:
	var field_node := Node2D.new()
	field_node.position = Vector2(150, 150)
	viewport.add_child(field_node)

	_preview_field_sprite = Sprite2D.new()
	_preview_field_sprite.z_index = -1
	var img := Image.create(200, 200, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_preview_field_sprite.texture = ImageTexture.create_from_image(img)
	field_node.add_child(_preview_field_sprite)


func _update_visual_preview() -> void:
	if not _ui_ready or not _preview_field_sprite:
		return

	var style_idx: int = _field_style_button.selected
	if style_idx <= 0:
		var shader: Shader = VFXFactory.get_field_shader("force_bubble")
		if shader:
			_preview_field_material = ShaderMaterial.new()
			_preview_field_material.shader = shader
			_preview_field_material.set_shader_parameter("field_color", _color_override_picker.color)
			_preview_field_material.set_shader_parameter("brightness", 1.0)
			_preview_field_material.set_shader_parameter("opacity", 1.0)
			_preview_field_material.set_shader_parameter("pulse_intensity", 0.0)
			_preview_field_sprite.material = _preview_field_material
		return

	var style_id: String = _field_style_button.get_item_text(style_idx)
	var style: FieldStyle = FieldStyleManager.load_by_id(style_id)
	if not style:
		return

	_preview_field_material = VFXFactory.create_field_material(style, 100.0)
	_preview_field_material.set_shader_parameter("animation_speed", _anim_speed_slider.value)
	_preview_field_sprite.material = _preview_field_material


func _on_auto_pulse() -> void:
	if _preview_field_material:
		_preview_field_material.set_shader_parameter("pulse_intensity", 1.0)


func _on_trigger_crossed() -> void:
	if _preview_field_material:
		_preview_field_material.set_shader_parameter("pulse_intensity", 1.0)


func _update_visual_preview_frame(delta: float) -> void:
	# Decay field pulse
	if _preview_field_material:
		var current: float = float(_preview_field_material.get_shader_parameter("pulse_intensity"))
		if current > 0.0:
			current = maxf(0.0, current - delta / 0.3)
			_preview_field_material.set_shader_parameter("pulse_intensity", current)


func _collect_visual_data(data: Dictionary) -> void:
	data["radius"] = _radius_slider.value
	data["fade_in_duration"] = _fade_in_slider.value
	data["fade_out_duration"] = _fade_out_slider.value
	data["animation_speed"] = _anim_speed_slider.value
	data["field_style_id"] = ""
	if _field_style_button.selected > 0:
		data["field_style_id"] = _field_style_button.get_item_text(_field_style_button.selected)
	data["orbiter_style_id"] = ""
	data["orbiter_lifetime"] = 4.0


func _populate_visual_fields(device: DeviceData) -> void:
	_radius_slider.value = device.radius
	_fade_in_slider.value = device.fade_in_duration
	_fade_out_slider.value = device.fade_out_duration
	_anim_speed_slider.value = device.animation_speed

	_refresh_field_style_list()
	if device.field_style_id != "":
		for i in _field_style_button.get_item_count():
			if _field_style_button.get_item_text(i) == device.field_style_id:
				_field_style_button.selected = i
				break


func _reset_visual_defaults() -> void:
	_radius_slider.value = 100.0
	_fade_in_slider.value = 0.3
	_fade_out_slider.value = 0.3
	_anim_speed_slider.value = 1.0
	_field_style_button.selected = 0


func _refresh_field_style_list() -> void:
	var current_sel: int = _field_style_button.selected if _field_style_button.get_item_count() > 0 else 0
	_field_style_button.clear()
	_field_style_button.add_item("(none)")
	var ids: Array[String] = FieldStyleManager.list_ids()
	for id in ids:
		_field_style_button.add_item(id)
	if current_sel < _field_style_button.get_item_count():
		_field_style_button.selected = current_sel
