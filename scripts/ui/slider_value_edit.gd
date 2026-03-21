class_name SliderValueEdit
extends LineEdit
## Compact editable value field that syncs with an HSlider.
## Looks like a label; click to type an exact value, press Enter or click away to apply.

var _slider: HSlider = null


static func create(slider: HSlider, width: float = 60.0) -> SliderValueEdit:
	var edit := SliderValueEdit.new()
	edit._slider = slider
	edit.custom_minimum_size.x = width
	edit.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	edit.text = "%.2f" % slider.value
	edit.select_all_on_focus = true

	# Style: flat background normally, subtle highlight on focus
	var normal_box := StyleBoxFlat.new()
	normal_box.bg_color = Color(0.1, 0.1, 0.15, 0.3)
	normal_box.set_content_margin_all(2)
	edit.add_theme_stylebox_override("normal", normal_box)

	var focus_box := StyleBoxFlat.new()
	focus_box.bg_color = Color(0.15, 0.15, 0.25, 0.6)
	focus_box.border_color = Color(0.4, 0.6, 0.9, 0.8)
	focus_box.set_border_width_all(1)
	focus_box.set_content_margin_all(2)
	edit.add_theme_stylebox_override("focus", focus_box)

	# Sync slider -> edit (only when not actively editing)
	slider.value_changed.connect(func(val: float) -> void:
		if not edit.has_focus():
			edit.text = "%.2f" % val
	)

	# Sync edit -> slider on Enter
	edit.text_submitted.connect(func(new_text: String) -> void:
		edit._apply_text(new_text)
		edit.release_focus()
	)

	# Sync edit -> slider on focus lost
	edit.focus_exited.connect(func() -> void:
		edit._apply_text(edit.text)
	)

	return edit


func _apply_text(new_text: String) -> void:
	if new_text.is_valid_float() and _slider:
		_slider.value = clampf(float(new_text), _slider.min_value, _slider.max_value)
	if _slider:
		text = "%.2f" % _slider.value
