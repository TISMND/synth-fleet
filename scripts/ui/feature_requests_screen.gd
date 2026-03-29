extends Control
## Feature Requests screen — checkboxes for playtester feedback, plus a joke submit.

var _vhs_overlay: ColorRect


func _ready() -> void:
	_setup_vhs_overlay()
	ThemeManager.theme_changed.connect(_on_theme_changed)

	$SubmitPage.hide()
	$ChecklistPage.show()

	$ChecklistPage/VBoxContainer/SubmitButton.pressed.connect(_on_submit)
	$SubmitPage/VBoxContainer/BackButton.pressed.connect(_on_back)

	_apply_styles()


func _on_submit() -> void:
	$ChecklistPage.hide()
	$SubmitPage.show()


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _apply_styles() -> void:
	for page in [$ChecklistPage, $SubmitPage]:
		for node in page.get_node("VBoxContainer").get_children():
			if node is Button:
				var btn: Button = node as Button
				ThemeManager.apply_button_style(btn)
				for state in ["normal", "hover", "pressed", "focus"]:
					var sb: StyleBox = btn.get_theme_stylebox(state)
					if sb and sb is StyleBoxFlat:
						var dark: StyleBoxFlat = (sb as StyleBoxFlat).duplicate() as StyleBoxFlat
						if state == "hover":
							dark.bg_color = Color(0.18, 0.18, 0.18, 0.95)
						elif state == "pressed":
							dark.bg_color = Color(0.12, 0.12, 0.12, 0.95)
						else:
							dark.bg_color = Color(0.06, 0.06, 0.06, 0.95)
						btn.add_theme_stylebox_override(state, dark)
			if node is Label:
				ThemeManager.apply_text_glow(node as Label, "header")
				var lbl: Label = node as Label
				var russo: Font = load("res://assets/fonts/RussoOne-Regular.ttf") as Font
				lbl.add_theme_font_override("font", russo)
				lbl.add_theme_font_size_override("font_size", 36)
				lbl.add_theme_constant_override("shadow_offset_x", 2)
				lbl.add_theme_constant_override("shadow_offset_y", 2)
				lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
				lbl.add_theme_constant_override("shadow_outline_size", 8)
				# Cut HDR bloom in half
				if lbl.material is ShaderMaterial:
					var mat: ShaderMaterial = lbl.material as ShaderMaterial
					var current_hdr: float = float(mat.get_shader_parameter("hdr_multiplier"))
					mat.set_shader_parameter("hdr_multiplier", current_hdr * 0.5)
			if node is CheckBox:
				_style_checkbox(node as CheckBox)



func _style_checkbox(cb: CheckBox) -> void:
	var font: Font = ThemeManager.get_font("body")
	var font_size: int = ThemeManager.get_font_size("body")
	var accent: Color = ThemeManager.get_color("accent")
	var text_color: Color = ThemeManager.get_color("text")

	if font:
		cb.add_theme_font_override("font", font)
	cb.add_theme_font_size_override("font_size", font_size)
	cb.add_theme_color_override("font_color", text_color)
	cb.add_theme_color_override("font_hover_color", accent)
	cb.add_theme_color_override("font_pressed_color", accent)

	# Consistent flat styleboxes for all states — no size jumping
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color.TRANSPARENT
		sb.set_content_margin_all(4)
		cb.add_theme_stylebox_override(state, sb)

	# Replace default check icons with simple colored squares
	var unchecked := _make_check_icon(20, Color(0.3, 0.3, 0.35))
	var checked := _make_check_icon(20, accent)
	cb.add_theme_icon_override("checked", checked)
	cb.add_theme_icon_override("unchecked", unchecked)
	cb.add_theme_icon_override("checked_disabled", checked)
	cb.add_theme_icon_override("unchecked_disabled", unchecked)


func _make_check_icon(size: int, color: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	# Border
	img.fill(color)
	# Inner fill — darker for unchecked look, solid for checked
	var border: int = 2
	for x in range(border, size - border):
		for y in range(border, size - border):
			if color.v < 0.4:
				img.set_pixel(x, y, Color(0.08, 0.08, 0.1, 0.9))
			else:
				img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)


func _setup_vhs_overlay() -> void:
	var vhs_layer := CanvasLayer.new()
	vhs_layer.layer = 10
	add_child(vhs_layer)
	_vhs_overlay = ColorRect.new()
	_vhs_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vhs_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vhs_layer.add_child(_vhs_overlay)
	ThemeManager.apply_vhs_overlay(_vhs_overlay)


func _on_theme_changed() -> void:
	ThemeManager.apply_vhs_overlay(_vhs_overlay)
	_apply_styles()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
