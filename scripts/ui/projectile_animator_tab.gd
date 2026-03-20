extends MarginContainer
## Projectile Animator Tab — design animated projectiles with mask + fill shader.
## Styles are saved to res://data/projectile_styles/ and referenced by weapons.

const ARCHETYPES: Array[String] = ["bullet", "beam", "pulse_wave"]
const FILL_SHADERS: Array[String] = ["energy", "plasma", "beam", "fire", "electric", "void", "ice", "toxic", "hologram", "glitch", "pulse", "smoke", "nebula_dual", "nebula_voronoi", "nebula_swirl", "nebula_wispy", "nebula_electric"]

const COMMON_PARAM_DISPLAY_NAMES: Dictionary = {
	"brightness": "HDR Brightness",
	"color_mix": "Desaturation",
	"animation_speed": "Time Scale",
	"edge_softness": "Thickness",
}

const COMMON_PARAM_DEFS: Dictionary = {
	"brightness": [0.5, 4.0, 1.0, 0.1],
	"color_mix": [0.0, 1.0, 0.0, 0.01],
	"animation_speed": [0.1, 3.0, 1.0, 0.1],
	"edge_softness": [0.0, 1.0, 0.5, 0.01],
}

const PROCEDURAL_SHAPES: Array[String] = ["circle", "diamond", "rounded_rect", "star", "hexagon", "arrow", "cross"]

const SHADER_PARAM_DEFS: Dictionary = {
	"energy": {"scroll_speed": [0.5, 5.0, 2.0, 0.1], "distortion": [0.0, 1.5, 0.15, 0.01], "edge_glow": [0.0, 3.0, 1.5, 0.1]},
	"plasma": {"turbulence_speed": [0.5, 5.0, 2.0, 0.1], "pulse_rate": [0.5, 4.0, 1.5, 0.1]},
	"beam": {"beam_speed": [0.5, 5.0, 3.0, 0.1], "beam_width": [0.1, 0.8, 0.3, 0.01], "flicker_rate": [0.0, 10.0, 4.0, 0.5]},
	"fire": {"scroll_speed": [0.5, 5.0, 2.0, 0.1], "heat_distortion": [0.0, 0.3, 0.1, 0.01], "flame_detail": [1.0, 6.0, 3.0, 0.5]},
	"electric": {"branch_density": [1.0, 8.0, 4.0, 0.5], "flicker_speed": [2.0, 16.0, 8.0, 1.0], "arc_width": [0.02, 0.2, 0.1, 0.01]},
	"void": {"pulse_speed": [0.5, 4.0, 1.5, 0.1], "edge_width": [0.05, 0.4, 0.15, 0.01], "inner_darkness": [0.5, 1.0, 0.9, 0.05]},
	"ice": {"crystal_density": [2.0, 10.0, 5.0, 0.5], "shimmer_speed": [0.5, 4.0, 2.0, 0.1], "fracture_sharpness": [0.5, 3.0, 1.5, 0.1]},
	"toxic": {"bubble_speed": [0.5, 4.0, 2.0, 0.1], "bubble_density": [1.0, 8.0, 4.0, 0.5], "drip_intensity": [0.0, 1.0, 0.5, 0.05]},
	"hologram": {"scan_speed": [1.0, 10.0, 4.0, 0.5], "scan_density": [4.0, 40.0, 20.0, 1.0], "aberration": [0.0, 0.1, 0.03, 0.005], "flicker_rate": [0.0, 8.0, 3.0, 0.5]},
	"glitch": {"block_size": [2.0, 20.0, 8.0, 1.0], "glitch_rate": [1.0, 12.0, 6.0, 0.5], "rgb_split": [0.0, 0.15, 0.05, 0.005], "intensity": [0.2, 1.0, 0.7, 0.05]},
	"pulse": {"ring_count": [2.0, 10.0, 5.0, 1.0], "ring_speed": [0.5, 4.0, 2.0, 0.1], "ring_width": [0.02, 0.2, 0.08, 0.01], "fade_rate": [0.5, 3.0, 1.5, 0.1]},
	"smoke": {"flow_speed": [0.5, 4.0, 1.5, 0.1], "density": [1.0, 6.0, 3.0, 0.5], "wisp_scale": [1.0, 8.0, 4.0, 0.5], "turbulence": [0.0, 1.0, 0.5, 0.05]},
	"nebula_dual": {"density": [0.5, 4.0, 2.0, 0.1]},
	"nebula_voronoi": {"cell_scale": [2.0, 8.0, 4.0, 0.5], "density": [0.5, 4.0, 2.0, 0.1]},
	"nebula_swirl": {"warp_strength": [1.0, 6.0, 4.0, 0.5], "density": [0.5, 4.0, 2.0, 0.1]},
	"nebula_wispy": {"filament_stretch": [1.0, 8.0, 4.0, 0.5], "density": [0.5, 4.0, 2.0, 0.1]},
	"nebula_electric": {"ridge_sharpness": [0.5, 4.0, 2.0, 0.1], "density": [0.5, 4.0, 2.0, 0.1]},
}

const BEAM_PARAM_DEFS: Dictionary = {
	"max_length": [100.0, 800.0, 400.0, 10.0],
	"beam_duration": [0.1, 2.0, 0.3, 0.05],
	"width": [4.0, 64.0, 16.0, 2.0],
}

const PULSE_PARAM_DEFS: Dictionary = {
	"expansion_rate": [50.0, 600.0, 200.0, 10.0],
	"max_radius": [50.0, 500.0, 300.0, 10.0],
	"lifetime": [0.2, 3.0, 1.0, 0.1],
	"ring_width": [2.0, 24.0, 8.0, 1.0],
}

# UI references
var _load_button: OptionButton
var _save_button: Button
var _delete_button: Button
var _new_button: Button
var _status_label: Label
var _name_input: LineEdit
var _archetype_button: OptionButton
var _shader_button: OptionButton
var _scale_x_slider: HSlider
var _scale_x_label: Label
var _scale_y_slider: HSlider
var _scale_y_label: Label
var _color_picker: ColorPickerButton
var _secondary_color_picker: ColorPickerButton
var _secondary_color_row: HBoxContainer
var _preview_node: ProjectileAnimatorPreview

# Dynamic sections
var _shader_params_container: VBoxContainer
var _shader_param_sliders: Dictionary = {}
var _common_params_container: VBoxContainer
var _common_param_sliders: Dictionary = {}
var _archetype_params_container: VBoxContainer
var _archetype_param_sliders: Dictionary = {}
var _mask_grid: GridContainer
var _selected_mask: String = ""
var _mask_thumbnails: Dictionary = {}  # filename -> TextureRect
var _mask_mode: String = "none"  # "none" | "procedural" | "import"
var _procedural_shape_button: OptionButton
var _feather_slider: HSlider
var _feather_label: Label
var _procedural_controls: VBoxContainer
var _mask_preview: TextureRect

# State
var _current_id: String = ""
var _section_headers: Array[Label] = []
var _ui_ready: bool = false


func _ready() -> void:
	_build_ui()
	_ui_ready = true
	_refresh_load_list()
	_refresh_mask_grid()
	call_deferred("_start_preview")
	ThemeManager.theme_changed.connect(_apply_theme)


func _exit_tree() -> void:
	pass


func _start_preview() -> void:
	_update_preview()


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root)

	# Top bar
	var top_bar := HBoxContainer.new()
	root.add_child(top_bar)

	var load_label := Label.new()
	load_label.text = "Load:"
	top_bar.add_child(load_label)

	_load_button = OptionButton.new()
	_load_button.custom_minimum_size.x = 250
	_load_button.item_selected.connect(_on_load_selected)
	top_bar.add_child(_load_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	_delete_button = Button.new()
	_delete_button.text = "DELETE"
	_delete_button.pressed.connect(_on_delete)
	top_bar.add_child(_delete_button)

	_new_button = Button.new()
	_new_button.text = "NEW"
	_new_button.pressed.connect(_on_new)
	top_bar.add_child(_new_button)

	# Main content: HSplitContainer
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 420
	root.add_child(split)

	# Left: Preview
	var left_panel := _build_left_panel()
	split.add_child(left_panel)

	# Right: Controls
	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(right_scroll)

	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(right_vbox)

	_build_controls(right_vbox)

	# Bottom bar
	var bottom_bar := HBoxContainer.new()
	root.add_child(bottom_bar)

	_save_button = Button.new()
	_save_button.text = "SAVE STYLE"
	_save_button.custom_minimum_size.x = 200
	_save_button.pressed.connect(_on_save)
	bottom_bar.add_child(_save_button)

	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.text = ""
	bottom_bar.add_child(_status_label)


func _build_left_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 420
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var preview_label := Label.new()
	preview_label.text = "LIVE PREVIEW"
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(preview_label)
	_section_headers.append(preview_label)

	var viewport_container := SubViewportContainer.new()
	viewport_container.custom_minimum_size = Vector2(400, 400)
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.stretch = true
	vbox.add_child(viewport_container)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(400, 500)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	viewport.use_hdr_2d = true
	viewport_container.add_child(viewport)

	VFXFactory.add_bloom_to_viewport(viewport)

	_preview_node = ProjectileAnimatorPreview.new()
	viewport.add_child(_preview_node)

	return panel


func _build_controls(parent: VBoxContainer) -> void:
	# Name
	_add_section_header(parent, "NAME")
	_name_input = LineEdit.new()
	_name_input.placeholder_text = "Enter style name..."
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_input.text_changed.connect(func(_t: String) -> void: pass)
	parent.add_child(_name_input)

	_add_separator(parent)

	# Archetype
	_add_section_header(parent, "ARCHETYPE")
	_archetype_button = OptionButton.new()
	_archetype_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for a in ARCHETYPES:
		_archetype_button.add_item(a)
	_archetype_button.item_selected.connect(_on_archetype_changed)
	parent.add_child(_archetype_button)

	_add_separator(parent)

	# Mask Browser
	_add_section_header(parent, "MASK")
	var mask_controls := HBoxContainer.new()
	parent.add_child(mask_controls)

	var no_mask_btn := Button.new()
	no_mask_btn.text = "No Mask"
	no_mask_btn.pressed.connect(_on_no_mask)
	ThemeManager.apply_button_style(no_mask_btn)
	mask_controls.add_child(no_mask_btn)

	var procedural_btn := Button.new()
	procedural_btn.text = "Procedural"
	procedural_btn.pressed.connect(_on_procedural_mask)
	ThemeManager.apply_button_style(procedural_btn)
	mask_controls.add_child(procedural_btn)

	var import_btn := Button.new()
	import_btn.text = "Import PNG..."
	import_btn.pressed.connect(_on_import_mask)
	ThemeManager.apply_button_style(import_btn)
	mask_controls.add_child(import_btn)

	# Procedural mask controls (hidden by default)
	_procedural_controls = VBoxContainer.new()
	_procedural_controls.visible = false
	parent.add_child(_procedural_controls)

	var shape_row := HBoxContainer.new()
	_procedural_controls.add_child(shape_row)
	var shape_label := Label.new()
	shape_label.text = "Shape:"
	shape_label.custom_minimum_size.x = 130
	shape_row.add_child(shape_label)
	_procedural_shape_button = OptionButton.new()
	_procedural_shape_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in PROCEDURAL_SHAPES:
		_procedural_shape_button.add_item(s)
	_procedural_shape_button.item_selected.connect(_on_procedural_shape_changed)
	shape_row.add_child(_procedural_shape_button)

	var feather_row: Array = _add_slider_row(_procedural_controls, "Feather:", 0.0, 1.0, 0.3, 0.01)
	_feather_slider = feather_row[0]
	_feather_label = feather_row[1]
	_feather_slider.value_changed.connect(func(_v: float) -> void: _update_procedural_preview())

	# Procedural mask preview
	var preview_row := HBoxContainer.new()
	_procedural_controls.add_child(preview_row)
	var preview_label := Label.new()
	preview_label.text = "Preview:"
	preview_label.custom_minimum_size.x = 130
	preview_row.add_child(preview_label)
	_mask_preview = TextureRect.new()
	_mask_preview.custom_minimum_size = Vector2(64, 64)
	_mask_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_mask_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	preview_row.add_child(_mask_preview)

	# Import mask grid
	_mask_grid = GridContainer.new()
	_mask_grid.columns = 5
	_mask_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mask_grid.visible = false
	parent.add_child(_mask_grid)

	_add_separator(parent)

	# Fill Shader
	_add_section_header(parent, "FILL SHADER")
	_shader_button = OptionButton.new()
	_shader_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in FILL_SHADERS:
		_shader_button.add_item(s)
	_shader_button.item_selected.connect(_on_shader_changed)
	parent.add_child(_shader_button)

	# Common Params (always visible)
	_add_section_header(parent, "COMMON")
	_common_params_container = VBoxContainer.new()
	_common_params_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(_common_params_container)
	_rebuild_common_params()

	# Shader Params (dynamic)
	_shader_params_container = VBoxContainer.new()
	_shader_params_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(_shader_params_container)
	_rebuild_shader_params("energy")

	_add_separator(parent)

	# Color
	_add_section_header(parent, "COLOR")
	var color_row := HBoxContainer.new()
	parent.add_child(color_row)
	var color_label := Label.new()
	color_label.text = "Color:"
	color_label.custom_minimum_size.x = 130
	color_row.add_child(color_label)
	_color_picker = ColorPickerButton.new()
	_color_picker.color = Color.CYAN
	_color_picker.custom_minimum_size = Vector2(80, 30)
	_color_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_color_picker.color_changed.connect(func(_c: Color) -> void: _update_preview())
	color_row.add_child(_color_picker)

	# Secondary color (shown only for nebula_dual shader)
	_secondary_color_row = HBoxContainer.new()
	_secondary_color_row.visible = false
	parent.add_child(_secondary_color_row)
	var sec_label := Label.new()
	sec_label.text = "Secondary:"
	sec_label.custom_minimum_size.x = 130
	_secondary_color_row.add_child(sec_label)
	_secondary_color_picker = ColorPickerButton.new()
	_secondary_color_picker.color = Color(1.0, 0.3, 0.5, 1.0)
	_secondary_color_picker.custom_minimum_size = Vector2(80, 30)
	_secondary_color_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_secondary_color_picker.color_changed.connect(func(_c: Color) -> void: _update_preview())
	_secondary_color_row.add_child(_secondary_color_picker)

	_add_separator(parent)

	# Scale
	_add_section_header(parent, "SCALE")
	var sx_row: Array = _add_slider_row(parent, "Width:", 4.0, 128.0, 24.0, 2.0)
	_scale_x_slider = sx_row[0]
	_scale_x_label = sx_row[1]

	var sy_row: Array = _add_slider_row(parent, "Height:", 4.0, 128.0, 32.0, 2.0)
	_scale_y_slider = sy_row[0]
	_scale_y_label = sy_row[1]

	# Archetype params container (kept for data but not shown in UI)
	_archetype_params_container = VBoxContainer.new()
	_archetype_params_container.visible = false
	parent.add_child(_archetype_params_container)


# ── Dynamic Param Sections ─────────────────────────────────

func _rebuild_common_params() -> void:
	for child in _common_params_container.get_children():
		child.queue_free()
	_common_param_sliders.clear()

	for param_name in COMMON_PARAM_DEFS:
		var bounds: Array = COMMON_PARAM_DEFS[param_name]
		var display: String = COMMON_PARAM_DISPLAY_NAMES.get(param_name, param_name) as String
		var row: Array = _add_slider_row(_common_params_container, display + ":",
			float(bounds[0]), float(bounds[1]), float(bounds[2]), float(bounds[3]))
		_common_param_sliders[param_name] = row[0]


func _rebuild_shader_params(shader_name: String) -> void:
	for child in _shader_params_container.get_children():
		child.queue_free()
	_shader_param_sliders.clear()

	var defs: Dictionary = SHADER_PARAM_DEFS.get(shader_name, {}) as Dictionary
	if defs.is_empty():
		var lbl := Label.new()
		lbl.text = "  (no parameters)"
		lbl.add_theme_color_override("font_color", ThemeManager.get_color("disabled"))
		_shader_params_container.add_child(lbl)
		return

	for param_name in defs:
		var bounds: Array = defs[param_name]
		var row: Array = _add_slider_row(_shader_params_container, param_name + ":",
			float(bounds[0]), float(bounds[1]), float(bounds[2]), float(bounds[3]))
		_shader_param_sliders[param_name] = row[0]


func _rebuild_archetype_params(archetype: String) -> void:
	for child in _archetype_params_container.get_children():
		child.queue_free()
	_archetype_param_sliders.clear()

	var defs: Dictionary = {}
	match archetype:
		"beam":
			defs = BEAM_PARAM_DEFS
		"pulse_wave":
			defs = PULSE_PARAM_DEFS
		"bullet":
			var lbl := Label.new()
			lbl.text = "  (no archetype-specific parameters)"
			lbl.add_theme_color_override("font_color", ThemeManager.get_color("disabled"))
			_archetype_params_container.add_child(lbl)
			return

	for param_name in defs:
		var bounds: Array = defs[param_name]
		var row: Array = _add_slider_row(_archetype_params_container, param_name + ":",
			float(bounds[0]), float(bounds[1]), float(bounds[2]), float(bounds[3]))
		_archetype_param_sliders[param_name] = row[0]


# ── Mask Browser ───────────────────────────────────────────

func _refresh_mask_grid() -> void:
	for child in _mask_grid.get_children():
		child.queue_free()
	_mask_thumbnails.clear()

	var masks: Array[String] = ProjectileStyleManager.list_masks()
	for mask_name in masks:
		var thumb := _create_mask_thumbnail(mask_name)
		_mask_grid.add_child(thumb)
		_mask_thumbnails[mask_name] = thumb


func _create_mask_thumbnail(mask_name: String) -> TextureRect:
	var rect := TextureRect.new()
	rect.custom_minimum_size = Vector2(64, 64)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL

	# Load thumbnail from res://data/ using Image (not load())
	var img := Image.new()
	var path: String = ProjectileStyleManager.MASKS_DIR + mask_name
	var err: Error = img.load(path)
	if err == OK:
		img.resize(64, 64, Image.INTERPOLATE_BILINEAR)
		rect.texture = ImageTexture.create_from_image(img)

	rect.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			_select_mask(mask_name)
	)

	rect.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return rect


func _select_mask(mask_name: String) -> void:
	_mask_mode = "import"
	_selected_mask = mask_name
	_update_mask_highlights()
	_update_preview()


func _update_mask_highlights() -> void:
	for fname in _mask_thumbnails:
		var rect: TextureRect = _mask_thumbnails[fname]
		if fname == _selected_mask:
			rect.modulate = Color(1.2, 1.2, 1.5, 1.0)
		else:
			rect.modulate = Color(0.7, 0.7, 0.7, 1.0)


func _on_no_mask() -> void:
	_mask_mode = "none"
	_selected_mask = ""
	_procedural_controls.visible = false
	_mask_grid.visible = false
	_mask_preview.texture = null
	_update_mask_highlights()
	_update_preview()


func _on_procedural_mask() -> void:
	_mask_mode = "procedural"
	_selected_mask = ""
	_procedural_controls.visible = true
	_mask_grid.visible = false
	_update_mask_highlights()
	_update_procedural_preview()
	_update_preview()


func _on_procedural_shape_changed(_idx: int) -> void:
	_update_procedural_preview()
	_update_preview()


func _update_procedural_preview() -> void:
	if _mask_mode != "procedural":
		return
	var shape: String = _procedural_shape_button.get_item_text(_procedural_shape_button.selected)
	var feather: float = _feather_slider.value
	var tex: ImageTexture = VFXFactory.generate_procedural_mask(shape, feather)
	_mask_preview.texture = tex


func _on_import_mask() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(["*.png ; PNG Images"])
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_selected.connect(func(path: String) -> void:
		var fname: String = path.get_file()
		var result: String = ProjectileStyleManager.import_mask(path, fname)
		if result != "":
			_mask_mode = "import"
			_procedural_controls.visible = false
			_mask_grid.visible = true
			_status_label.text = "Imported: " + fname
			_refresh_mask_grid()
			_select_mask(fname)
		else:
			_status_label.text = "Failed to import mask."
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	# Add to parent tree so it displays
	var parent_node: Node = get_parent()
	if parent_node:
		parent_node = parent_node.get_parent()
	if parent_node:
		parent_node.add_child(dialog)
	else:
		add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))


# ── Event Handlers ─────────────────────────────────────────

func _on_archetype_changed(_idx: int) -> void:
	var archetype: String = _archetype_button.get_item_text(_archetype_button.selected)
	_rebuild_archetype_params(archetype)
	_update_preview()


func _on_shader_changed(_idx: int) -> void:
	var shader_name: String = _shader_button.get_item_text(_shader_button.selected)
	_rebuild_shader_params(shader_name)
	_secondary_color_row.visible = (shader_name == "nebula_dual")
	_update_preview()


# ── Data Collection ────────────────────────────────────────

func _collect_style_data() -> Dictionary:
	var shader_params: Dictionary = {}
	# Common params
	for param_name in _common_param_sliders:
		var slider: HSlider = _common_param_sliders[param_name]
		shader_params[param_name] = slider.value
	# Per-shader params
	for param_name in _shader_param_sliders:
		var slider: HSlider = _shader_param_sliders[param_name]
		shader_params[param_name] = slider.value

	var archetype_params: Dictionary = {}
	for param_name in _archetype_param_sliders:
		var slider: HSlider = _archetype_param_sliders[param_name]
		archetype_params[param_name] = slider.value

	var mask_path: String = ""
	if _mask_mode == "import" and _selected_mask != "":
		mask_path = ProjectileStyleManager.MASKS_DIR + _selected_mask

	var proc_shape: String = ""
	var proc_feather: float = 0.3
	if _mask_mode == "procedural":
		proc_shape = _procedural_shape_button.get_item_text(_procedural_shape_button.selected)
		proc_feather = _feather_slider.value

	var sec_color: Color = _secondary_color_picker.color

	return {
		"id": _current_id if _current_id != "" else _generate_id(_name_input.text),
		"display_name": _name_input.text,
		"archetype": _archetype_button.get_item_text(_archetype_button.selected),
		"mask_path": mask_path,
		"fill_shader": _shader_button.get_item_text(_shader_button.selected),
		"shader_params": shader_params,
		"glow_intensity": 1.5,
		"base_scale": [_scale_x_slider.value, _scale_y_slider.value],
		"archetype_params": archetype_params,
		"color": [_color_picker.color.r, _color_picker.color.g, _color_picker.color.b, _color_picker.color.a],
		"secondary_color": [sec_color.r, sec_color.g, sec_color.b, sec_color.a],
		"procedural_mask_shape": proc_shape,
		"procedural_mask_feather": proc_feather,
	}


func _update_preview() -> void:
	if not _ui_ready or not _preview_node:
		return
	var data: Dictionary = _collect_style_data()
	data["color"] = _color_picker.color
	data["secondary_color"] = _secondary_color_picker.color
	data["base_scale"] = Vector2(_scale_x_slider.value, _scale_y_slider.value)
	_preview_node.update_style(data)


# ── Save / Load / Delete ──────────────────────────────────

func _on_save() -> void:
	var name_text: String = _name_input.text.strip_edges()
	if name_text == "":
		_status_label.text = "Enter a style name first!"
		return
	var data: Dictionary = _collect_style_data()
	var id: String = str(data["id"])
	_current_id = id
	ProjectileStyleManager.save(id, data)
	_status_label.text = "Saved: " + id
	_refresh_load_list()


func _on_load_selected(idx: int) -> void:
	if idx <= 0:
		return
	var id: String = _load_button.get_item_text(idx)
	var style: ProjectileStyle = ProjectileStyleManager.load_by_id(id)
	if not style:
		_status_label.text = "Failed to load: " + id
		return
	_populate_from_style(style)
	_status_label.text = "Loaded: " + id


func _on_delete() -> void:
	if _current_id == "":
		_status_label.text = "No style loaded to delete."
		return
	ProjectileStyleManager.delete(_current_id)
	_status_label.text = "Deleted: " + _current_id
	_current_id = ""
	_on_new()
	_refresh_load_list()


func _on_new() -> void:
	_current_id = ""
	_name_input.text = ""
	_archetype_button.selected = 0
	_shader_button.selected = 0
	_scale_x_slider.value = 24.0
	_scale_y_slider.value = 32.0
	_color_picker.color = Color.CYAN
	_secondary_color_picker.color = Color(1.0, 0.3, 0.5, 1.0)
	_secondary_color_row.visible = false
	_selected_mask = ""
	_mask_mode = "none"
	_procedural_controls.visible = false
	_mask_grid.visible = false
	if _procedural_shape_button.get_item_count() > 0:
		_procedural_shape_button.selected = 0
	_feather_slider.value = 0.3
	_mask_preview.texture = null
	_update_mask_highlights()
	_rebuild_common_params()
	_rebuild_shader_params("energy")
	_rebuild_archetype_params("bullet")
	_update_preview()
	_status_label.text = "New style — ready to edit."


func _refresh_load_list() -> void:
	_load_button.clear()
	_load_button.add_item("(select style)")
	var ids: Array[String] = ProjectileStyleManager.list_ids()
	for id in ids:
		_load_button.add_item(id)


func _populate_from_style(style: ProjectileStyle) -> void:
	_current_id = style.id
	_name_input.text = style.display_name

	# Archetype
	var arch_idx: int = ARCHETYPES.find(style.archetype)
	_archetype_button.selected = arch_idx if arch_idx >= 0 else 0

	# Fill shader
	var shader_idx: int = FILL_SHADERS.find(style.fill_shader)
	_shader_button.selected = shader_idx if shader_idx >= 0 else 0
	_rebuild_shader_params(style.fill_shader)

	# Set common param values
	for param_name in style.shader_params:
		if param_name in _common_param_sliders:
			var slider: HSlider = _common_param_sliders[param_name]
			slider.value = float(style.shader_params[param_name])

	# Set shader param values
	for param_name in style.shader_params:
		if param_name in _shader_param_sliders:
			var slider: HSlider = _shader_param_sliders[param_name]
			slider.value = float(style.shader_params[param_name])

	# Color
	_color_picker.color = style.color
	_secondary_color_picker.color = style.secondary_color
	_secondary_color_row.visible = (style.fill_shader == "nebula_dual")

	# Scale
	_scale_x_slider.value = style.base_scale.x
	_scale_y_slider.value = style.base_scale.y

	# Mask
	if style.procedural_mask_shape != "":
		_mask_mode = "procedural"
		_procedural_controls.visible = true
		_mask_grid.visible = false
		var shape_idx: int = PROCEDURAL_SHAPES.find(style.procedural_mask_shape)
		_procedural_shape_button.selected = shape_idx if shape_idx >= 0 else 0
		_feather_slider.value = style.procedural_mask_feather
		_selected_mask = ""
		_update_procedural_preview()
	elif style.mask_path != "":
		_mask_mode = "import"
		_procedural_controls.visible = false
		_mask_grid.visible = true
		_selected_mask = style.mask_path.get_file()
	else:
		_mask_mode = "none"
		_procedural_controls.visible = false
		_mask_grid.visible = false
		_selected_mask = ""
	_update_mask_highlights()

	# Archetype params
	_rebuild_archetype_params(style.archetype)
	for param_name in style.archetype_params:
		if param_name in _archetype_param_sliders:
			var slider: HSlider = _archetype_param_sliders[param_name]
			slider.value = float(style.archetype_params[param_name])

	_update_preview()


func _generate_id(display_name: String) -> String:
	if display_name.strip_edges() == "":
		return "style_" + str(randi() % 10000)
	var id: String = display_name.strip_edges().to_lower().replace(" ", "_")
	var valid_chars: String = "abcdefghijklmnopqrstuvwxyz0123456789_"
	var clean: String = ""
	for c in id:
		if valid_chars.contains(c):
			clean += c
	if clean == "":
		clean = "style_" + str(randi() % 10000)
	return clean


# ── UI Helpers ─────────────────────────────────────────────

func _add_section_header(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	parent.add_child(label)
	_section_headers.append(label)
	return label


func _add_separator(parent: Control) -> void:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	parent.add_child(sep)


func _add_slider_row(parent: Control, label_text: String, min_val: float, max_val: float, default_val: float, step_val: float) -> Array:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 130
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.value = default_val
	slider.step = step_val
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 150
	row.add_child(slider)

	var value_label := Label.new()
	value_label.text = str(default_val)
	value_label.custom_minimum_size.x = 60
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	slider.value_changed.connect(func(val: float) -> void:
		if step_val >= 1.0:
			value_label.text = str(int(val))
		else:
			value_label.text = "%.2f" % val
		_update_preview()
	)

	return [slider, value_label]


func _apply_theme() -> void:
	for label in _section_headers:
		if is_instance_valid(label):
			label.add_theme_color_override("font_color", ThemeManager.get_color("header"))
			label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	if _save_button:
		ThemeManager.apply_button_style(_save_button)
	if _delete_button:
		ThemeManager.apply_button_style(_delete_button)
	if _new_button:
		ThemeManager.apply_button_style(_new_button)
