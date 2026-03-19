class_name OrbitalGeneratorsTab
extends DeviceTabBase
## Orbital Generators tab — editor for orbiter-type devices.

# Visual subtab controls
var _radius_slider: HSlider
var _radius_label: Label
var _orbiter_style_button: OptionButton
var _orbiter_lifetime_slider: HSlider
var _orbiter_lifetime_label: Label
var _fade_in_slider: HSlider
var _fade_in_label: Label
var _fade_out_slider: HSlider
var _fade_out_label: Label

# Preview
var _preview_orbiter_renderer: OrbiterRenderer = null


func _get_visual_mode() -> String:
	return "orbiter"

func _get_type_label() -> String:
	return "ORBITAL GENERATOR"

func _get_id_prefix() -> String:
	return "ogn_"

func _save_data(id: String, data: Dictionary) -> void:
	OrbitalGeneratorDataManager.save(id, data)

func _delete_data(id: String) -> void:
	OrbitalGeneratorDataManager.delete(id)

func _list_ids() -> Array[String]:
	return OrbitalGeneratorDataManager.list_ids()

func _load_data(id: String) -> DeviceData:
	return OrbitalGeneratorDataManager.load_by_id(id)


func _build_visual_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(form)

	# Radius
	_add_section_header(form, "ORBIT RADIUS")
	var radius_row: Array = _add_slider_row(form, "Radius:", 20.0, 300.0, 100.0, 5.0)
	_radius_slider = radius_row[0]
	_radius_label = radius_row[1]

	_add_separator(form)

	# Orbiter Style selector
	_add_section_header(form, "ORBITER STYLE")
	_orbiter_style_button = OptionButton.new()
	_orbiter_style_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_orbiter_style_button.add_item("(none)")
	_refresh_orbiter_style_list()
	_orbiter_style_button.item_selected.connect(func(_idx: int) -> void:
		_mark_dirty()
		_update_visual_preview()
	)
	form.add_child(_orbiter_style_button)

	_add_separator(form)

	# Orbiter Lifetime
	_add_section_header(form, "ORBITER LIFETIME")
	var lt_row: Array = _add_slider_row(form, "Lifetime (s):", 0.5, 20.0, 4.0, 0.5)
	_orbiter_lifetime_slider = lt_row[0]
	_orbiter_lifetime_label = lt_row[1]

	_add_separator(form)

	# Fade durations
	_add_section_header(form, "FADE")
	var fi_row: Array = _add_slider_row(form, "Fade In (s):", 0.0, 2.0, 0.3, 0.05)
	_fade_in_slider = fi_row[0]
	_fade_in_label = fi_row[1]

	var fo_row: Array = _add_slider_row(form, "Fade Out (s):", 0.0, 2.0, 0.3, 0.05)
	_fade_out_slider = fo_row[0]
	_fade_out_label = fo_row[1]

	# Update orbiter preview fade durations when sliders change
	_fade_in_slider.value_changed.connect(func(_v: float) -> void:
		if _preview_orbiter_renderer:
			_preview_orbiter_renderer.set_fade_durations(_fade_in_slider.value, _fade_out_slider.value)
	)
	_fade_out_slider.value_changed.connect(func(_v: float) -> void:
		if _preview_orbiter_renderer:
			_preview_orbiter_renderer.set_fade_durations(_fade_in_slider.value, _fade_out_slider.value)
	)

	return scroll


func _setup_visual_preview(viewport: SubViewport) -> void:
	_preview_orbiter_renderer = OrbiterRenderer.new()
	_preview_orbiter_renderer.position = Vector2(150, 150)
	viewport.add_child(_preview_orbiter_renderer)


func _update_visual_preview() -> void:
	if not _ui_ready or not _preview_orbiter_renderer:
		return

	_preview_orbiter_renderer.remove_all()
	var orb_idx: int = _orbiter_style_button.selected
	if orb_idx <= 0:
		return
	var orb_id: String = _orbiter_style_button.get_item_text(orb_idx)
	var orb_style: OrbiterStyle = OrbiterStyleManager.load_by_id(orb_id)
	if not orb_style:
		return
	_preview_orbiter_renderer.setup(orb_style)
	_preview_orbiter_renderer.set_orbit_radius(_radius_slider.value)
	_preview_orbiter_renderer.set_lifetime(_orbiter_lifetime_slider.value)
	_preview_orbiter_renderer.set_fade_durations(_fade_in_slider.value, _fade_out_slider.value)


func _on_trigger_crossed() -> void:
	if _preview_orbiter_renderer:
		_preview_orbiter_renderer.spawn_batch()


func _collect_visual_data(data: Dictionary) -> void:
	data["radius"] = _radius_slider.value
	data["fade_in_duration"] = _fade_in_slider.value
	data["fade_out_duration"] = _fade_out_slider.value
	data["orbiter_lifetime"] = _orbiter_lifetime_slider.value
	data["orbiter_style_id"] = ""
	if _orbiter_style_button.selected > 0:
		data["orbiter_style_id"] = _orbiter_style_button.get_item_text(_orbiter_style_button.selected)
	data["field_style_id"] = ""
	data["animation_speed"] = 1.0


func _populate_visual_fields(device: DeviceData) -> void:
	_radius_slider.value = device.radius
	_fade_in_slider.value = device.fade_in_duration
	_fade_out_slider.value = device.fade_out_duration
	_orbiter_lifetime_slider.value = device.orbiter_lifetime

	_refresh_orbiter_style_list()
	if device.orbiter_style_id != "":
		for i in _orbiter_style_button.get_item_count():
			if _orbiter_style_button.get_item_text(i) == device.orbiter_style_id:
				_orbiter_style_button.selected = i
				break


func _reset_visual_defaults() -> void:
	_radius_slider.value = 100.0
	_fade_in_slider.value = 0.3
	_fade_out_slider.value = 0.3
	_orbiter_lifetime_slider.value = 4.0
	_orbiter_style_button.selected = 0


func _refresh_orbiter_style_list() -> void:
	var current_sel: int = _orbiter_style_button.selected if _orbiter_style_button.get_item_count() > 0 else 0
	_orbiter_style_button.clear()
	_orbiter_style_button.add_item("(none)")
	var ids: Array[String] = OrbiterStyleManager.list_ids()
	for id in ids:
		_orbiter_style_button.add_item(id)
	if current_sel < _orbiter_style_button.get_item_count():
		_orbiter_style_button.selected = current_sel
