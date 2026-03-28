extends MarginContainer
## Nebula definition editor — create named nebulas, pick a shader style, tweak parameters.
## Parameters organized into two columns: left (Appearance + Layers), right (Storm + Effects).

const STYLES: Dictionary = {
	"classic_fbm": {"name": "Classic FBM", "shader": "res://assets/shaders/nebula_classic_fbm.gdshader", "dual": false},
	"wispy_filaments": {"name": "Wispy Filaments", "shader": "res://assets/shaders/nebula_wispy_filaments.gdshader", "dual": false},
	"dual_color": {"name": "Dual Color", "shader": "res://assets/shaders/nebula_dual_color.gdshader", "dual": true},
	"voronoi": {"name": "Voronoi Cells", "shader": "res://assets/shaders/nebula_voronoi.gdshader", "dual": false},
	"turbulent_swirl": {"name": "Turbulent Swirl", "shader": "res://assets/shaders/nebula_turbulent_swirl.gdshader", "dual": false},
	"electric_filaments": {"name": "Electric Filaments", "shader": "res://assets/shaders/nebula_electric_filaments.gdshader", "dual": false},
	"lightning_strike": {"name": "Lightning Strike", "shader": "res://assets/shaders/nebula_lightning_strike.gdshader", "dual": false},
	"arc_discharge": {"name": "Arc Discharge", "shader": "res://assets/shaders/nebula_arc_discharge.gdshader", "dual": false},
	"energy_flare": {"name": "Energy Flare", "shader": "res://assets/shaders/nebula_energy_flare.gdshader", "dual": false},
	"dual_swirl": {"name": "Dual Swirl", "shader": "res://assets/shaders/nebula_dual_swirl.gdshader", "dual": true},
	"dual_voronoi": {"name": "Dual Voronoi", "shader": "res://assets/shaders/nebula_dual_voronoi.gdshader", "dual": true},
}

var _style_keys: Array[String] = []
var _nebulas: Array[NebulaData] = []
var _selected_id: String = ""
var _suppressing_signals: bool = false

# UI refs — top level
var _list_container: VBoxContainer
var _create_btn: Button
var _delete_btn: Button
var _preview_rect: ColorRect
var _name_edit: LineEdit
var _style_option: OptionButton
var _editor_panel: VBoxContainer
var _empty_label: Label

# Two-column param layout
var _params_columns: HBoxContainer  # Holds left_col and right_col side by side
var _left_col: VBoxContainer
var _right_col: VBoxContainer
var _active_slider_container: VBoxContainer  # Points to whichever column is being built

# Appearance tab controls
var _color_picker: ColorPickerButton
var _color2_picker: ColorPickerButton
var _color2_row: HBoxContainer
var _brightness_slider: HSlider
var _brightness_value: Label
var _speed_slider: HSlider
var _speed_value: Label
var _density_slider: HSlider
var _density_value: Label
var _seed_slider: HSlider
var _seed_value: Label
var _spread_slider: HSlider
var _spread_value: Label

# Layers tab controls
var _bottom_opacity_slider: HSlider
var _bottom_opacity_value: Label
var _top_opacity_slider: HSlider
var _top_opacity_value: Label
var _veil_contrast_slider: HSlider
var _veil_contrast_value: Label
var _wash_opacity_slider: HSlider
var _wash_opacity_value: Label

# Storm tab controls
var _storm_enabled_check: CheckBox
var _storm_frequency_slider: HSlider
var _storm_frequency_value: Label
var _storm_strike_size_slider: HSlider
var _storm_strike_size_value: Label
var _storm_duration_slider: HSlider
var _storm_duration_value: Label
var _storm_glow_slider: HSlider
var _storm_glow_value: Label
var _storm_controls_container: VBoxContainer  # Holds sliders, disabled when storm off

# Warning controls
var _warning_enabled_check: CheckBox
var _warning_controls_container: VBoxContainer
var _warning_text_edit: LineEdit
var _warning_color_picker: ColorPickerButton
var _alarm_sfx_option: OptionButton
const NEBULA_ALARM_IDS: Array[String] = ["nebula_alarm_1", "nebula_alarm_2", "nebula_alarm_3", "nebula_alarm_4", "nebula_alarm_5"]

# Effects tab controls
var _bar_effect_spinboxes: Dictionary = {}
var _special_effect_checks: Dictionary = {}
const KNOWN_SPECIAL_EFFECTS: Array[String] = ["cloak", "slow", "damage_boost"]
var _key_change_option: OptionButton
var _key_change_ids: Array[String] = []

# Game events controls
var _game_event_checks: Dictionary = {}  # event_id -> CheckBox
var _game_event_ids: Array[String] = []
var _event_interval_min_slider: HSlider
var _event_interval_min_value: Label
var _event_interval_max_slider: HSlider
var _event_interval_max_value: Label
var _event_controls_container: VBoxContainer  # Holds interval sliders, disabled when no events

# Preview layering refs
var _preview_container: Control
var _preview_bottom: ColorRect
var _preview_ship: ShipRenderer
var _preview_wash: ColorRect
var _preview_storm: ColorRect  # Storm overlay layer
var _preview_top: ColorRect


func _ready() -> void:
	for key in STYLES:
		_style_keys.append(key)

	_nebulas = NebulaDataManager.load_all()
	_build_ui()

	if _nebulas.size() > 0:
		_select_nebula(_nebulas[0].id)
	else:
		_show_empty_state()

	ThemeManager.theme_changed.connect(_apply_theme)
	call_deferred("_apply_theme")
	call_deferred("_center_preview_ship")


func _build_ui() -> void:
	var split := HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = -200
	add_child(split)

	# --- Left panel: nebula list (~35%) ---
	var left_panel := VBoxContainer.new()
	left_panel.custom_minimum_size.x = 200
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 0.35
	left_panel.add_theme_constant_override("separation", 8)
	split.add_child(left_panel)

	var header := Label.new()
	header.text = "NEBULAS"
	header.name = "ListHeader"
	left_panel.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.add_child(scroll)

	_list_container = VBoxContainer.new()
	_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_container.add_theme_constant_override("separation", 4)
	scroll.add_child(_list_container)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	left_panel.add_child(btn_row)

	_create_btn = Button.new()
	_create_btn.text = "+ NEW"
	_create_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_create_btn.pressed.connect(_on_create_new)
	btn_row.add_child(_create_btn)

	_delete_btn = Button.new()
	_delete_btn.text = "DELETE"
	_delete_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_delete_btn.disabled = true
	_delete_btn.pressed.connect(_on_delete)
	btn_row.add_child(_delete_btn)

	# --- Right panel: editor (~65%) ---
	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_stretch_ratio = 0.65
	split.add_child(right_scroll)

	_editor_panel = VBoxContainer.new()
	_editor_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor_panel.add_theme_constant_override("separation", 10)
	right_scroll.add_child(_editor_panel)

	# Preview — layered: black bg, bottom nebula, ship, wash, storm overlay, top veil
	_preview_container = Control.new()
	_preview_container.custom_minimum_size = Vector2(400, 600)
	_preview_container.clip_contents = true
	_editor_panel.add_child(_preview_container)

	var preview_bg := ColorRect.new()
	preview_bg.color = Color(0, 0, 0, 1)
	preview_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview_container.add_child(preview_bg)

	_preview_bottom = ColorRect.new()
	_preview_bottom.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview_bottom.color = Color.WHITE
	_preview_container.add_child(_preview_bottom)

	_preview_ship = ShipRenderer.new()
	_preview_ship.ship_id = 4  # Stiletto
	_preview_ship.render_mode = ShipRenderer.RenderMode.CHROME
	_preview_ship.animate = false
	_preview_ship.scale = Vector2(1.5, 1.5)
	_preview_container.add_child(_preview_ship)

	_preview_wash = ColorRect.new()
	_preview_wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview_wash.color = Color.WHITE
	_preview_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_container.add_child(_preview_wash)

	_preview_storm = ColorRect.new()
	_preview_storm.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview_storm.color = Color.WHITE
	_preview_storm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_container.add_child(_preview_storm)

	_preview_top = ColorRect.new()
	_preview_top.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview_top.color = Color.WHITE
	_preview_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_container.add_child(_preview_top)

	_preview_rect = _preview_bottom

	# Name row
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	_editor_panel.add_child(name_row)
	var name_label := Label.new()
	name_label.text = "Name"
	name_label.custom_minimum_size.x = 100
	name_row.add_child(name_label)
	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_changed.connect(_on_name_changed)
	name_row.add_child(_name_edit)

	# Style dropdown
	var style_row := HBoxContainer.new()
	style_row.add_theme_constant_override("separation", 8)
	_editor_panel.add_child(style_row)
	var style_label := Label.new()
	style_label.text = "Style"
	style_label.custom_minimum_size.x = 100
	style_row.add_child(style_label)
	_style_option = OptionButton.new()
	_style_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for key in _style_keys:
		var info: Dictionary = STYLES[key]
		_style_option.add_item(info["name"])
	_style_option.item_selected.connect(_on_style_changed)
	style_row.add_child(_style_option)

	# --- Two-column parameter layout ---
	_params_columns = HBoxContainer.new()
	_params_columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_params_columns.add_theme_constant_override("separation", 20)
	_editor_panel.add_child(_params_columns)

	_left_col = VBoxContainer.new()
	_left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_col.add_theme_constant_override("separation", 6)
	_params_columns.add_child(_left_col)

	_right_col = VBoxContainer.new()
	_right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_col.add_theme_constant_override("separation", 6)
	_params_columns.add_child(_right_col)

	_build_appearance_section()
	_build_layers_section()
	_build_storm_section()
	_build_warning_section()
	_build_effects_section()

	# Empty state label
	_empty_label = Label.new()
	_empty_label.text = "No nebulas yet. Click + NEW to get started."
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_editor_panel.add_child(_empty_label)
	_empty_label.visible = false

	_rebuild_list()


func _build_appearance_section() -> void:
	_active_slider_container = _left_col
	var section_header := Label.new()
	section_header.text = "APPEARANCE"
	section_header.name = "AppearanceHeader"
	_active_slider_container.add_child(section_header)

	# Color
	var color_row := HBoxContainer.new()
	color_row.add_theme_constant_override("separation", 8)
	_active_slider_container.add_child(color_row)
	var color_label := Label.new()
	color_label.text = "Color"
	color_label.custom_minimum_size.x = 80
	color_row.add_child(color_label)
	_color_picker = ColorPickerButton.new()
	_color_picker.custom_minimum_size = Vector2(60, 30)
	_color_picker.color = Color(0.3, 0.4, 0.9, 1.0)
	_color_picker.color_changed.connect(_on_color_changed)
	color_row.add_child(_color_picker)

	# Secondary color (dual styles only)
	_color2_row = HBoxContainer.new()
	_color2_row.add_theme_constant_override("separation", 8)
	_active_slider_container.add_child(_color2_row)
	var color2_label := Label.new()
	color2_label.text = "Color 2"
	color2_label.custom_minimum_size.x = 80
	_color2_row.add_child(color2_label)
	_color2_picker = ColorPickerButton.new()
	_color2_picker.custom_minimum_size = Vector2(60, 30)
	_color2_picker.color = Color(1.0, 0.5, 0.2, 1.0)
	_color2_picker.color_changed.connect(_on_color2_changed)
	_color2_row.add_child(_color2_picker)
	_color2_row.visible = false

	_brightness_slider = _add_slider_row("Brightness", 0.5, 4.0, 0.05, 1.5)
	_brightness_slider.value_changed.connect(_on_brightness_changed)

	_speed_slider = _add_slider_row("Anim Speed", 0.0, 3.0, 0.05, 0.5)
	_speed_slider.value_changed.connect(_on_speed_changed)

	_density_slider = _add_slider_row("Density", 0.5, 4.0, 0.05, 1.5)
	_density_slider.value_changed.connect(_on_density_changed)

	_seed_slider = _add_slider_row("Seed", 0.0, 1000.0, 1.0, 0.0)
	_seed_slider.value_changed.connect(_on_seed_changed)

	_spread_slider = _add_slider_row("Spread", 0.05, 1.0, 0.05, 0.2)
	_spread_slider.value_changed.connect(_on_spread_changed)


func _build_layers_section() -> void:
	_active_slider_container = _left_col
	var section_header := Label.new()
	section_header.text = "LAYERS"
	section_header.name = "LayersHeader"
	_active_slider_container.add_child(section_header)

	_bottom_opacity_slider = _add_slider_row("Bottom", 0.0, 1.0, 0.05, 1.0)
	_bottom_opacity_slider.value_changed.connect(_on_bottom_opacity_changed)

	_top_opacity_slider = _add_slider_row("Top Veil", 0.0, 2.0, 0.01, 0.1)
	_top_opacity_slider.value_changed.connect(_on_top_opacity_changed)

	_veil_contrast_slider = _add_slider_row("Veil Edge", 0.0, 1.0, 0.01, 0.5)
	_veil_contrast_slider.value_changed.connect(_on_veil_contrast_changed)

	_wash_opacity_slider = _add_slider_row("Wash", 0.0, 1.0, 0.01, 0.0)
	_wash_opacity_slider.value_changed.connect(_on_wash_opacity_changed)


func _build_storm_section() -> void:
	_active_slider_container = _right_col
	var section_header := Label.new()
	section_header.text = "STORM"
	section_header.name = "StormHeader"
	_active_slider_container.add_child(section_header)

	# Storm enable toggle
	_storm_enabled_check = CheckBox.new()
	_storm_enabled_check.text = "Enable Storm Overlay"
	_storm_enabled_check.toggled.connect(_on_storm_enabled_toggled)
	_active_slider_container.add_child(_storm_enabled_check)

	# Container for storm sliders — disabled when storm is off
	_storm_controls_container = VBoxContainer.new()
	_storm_controls_container.add_theme_constant_override("separation", 8)
	_active_slider_container.add_child(_storm_controls_container)

	# Temporarily point _active_slider_container at the storm controls sub-container
	_active_slider_container = _storm_controls_container

	_storm_frequency_slider = _add_slider_row("Frequency", 0.0, 1.0, 0.05, 0.4)
	_storm_frequency_slider.value_changed.connect(_on_storm_frequency_changed)

	_storm_strike_size_slider = _add_slider_row("Strike Size", 0.02, 0.4, 0.01, 0.12)
	_storm_strike_size_slider.value_changed.connect(_on_storm_strike_size_changed)

	_storm_duration_slider = _add_slider_row("Duration", 0.05, 0.5, 0.01, 0.2)
	_storm_duration_slider.value_changed.connect(_on_storm_duration_changed)

	_storm_glow_slider = _add_slider_row("Glow Size", 0.0, 1.0, 0.01, 0.3)
	_storm_glow_slider.value_changed.connect(_on_storm_glow_changed)

	_storm_controls_container.visible = false  # Hidden until toggled on


func _build_warning_section() -> void:
	_active_slider_container = _right_col
	var panel: VBoxContainer = _right_col

	var section_header := Label.new()
	section_header.text = "WARNING"
	section_header.name = "WarningHeader"
	panel.add_child(section_header)

	# Warning enable toggle
	_warning_enabled_check = CheckBox.new()
	_warning_enabled_check.text = "Show Warning Box"
	_warning_enabled_check.toggled.connect(_on_warning_enabled_toggled)
	panel.add_child(_warning_enabled_check)

	# Container for warning controls — hidden when warning is off
	_warning_controls_container = VBoxContainer.new()
	_warning_controls_container.add_theme_constant_override("separation", 8)
	panel.add_child(_warning_controls_container)

	# Warning text
	var text_row := HBoxContainer.new()
	text_row.add_theme_constant_override("separation", 8)
	_warning_controls_container.add_child(text_row)
	var text_lbl := Label.new()
	text_lbl.text = "Text"
	text_lbl.custom_minimum_size.x = 80
	text_row.add_child(text_lbl)
	_warning_text_edit = LineEdit.new()
	_warning_text_edit.placeholder_text = "WARNING"
	_warning_text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_warning_text_edit.text_changed.connect(_on_warning_text_changed)
	text_row.add_child(_warning_text_edit)

	# Warning color
	var color_row := HBoxContainer.new()
	color_row.add_theme_constant_override("separation", 8)
	_warning_controls_container.add_child(color_row)
	var color_lbl := Label.new()
	color_lbl.text = "Color"
	color_lbl.custom_minimum_size.x = 80
	color_row.add_child(color_lbl)
	_warning_color_picker = ColorPickerButton.new()
	_warning_color_picker.custom_minimum_size = Vector2(60, 30)
	_warning_color_picker.color = Color(1.0, 0.4, 0.1, 1.0)
	_warning_color_picker.color_changed.connect(_on_warning_color_changed)
	color_row.add_child(_warning_color_picker)

	# Alarm SFX dropdown
	var alarm_row := HBoxContainer.new()
	alarm_row.add_theme_constant_override("separation", 8)
	_warning_controls_container.add_child(alarm_row)
	var alarm_lbl := Label.new()
	alarm_lbl.text = "Alarm"
	alarm_lbl.custom_minimum_size.x = 80
	alarm_row.add_child(alarm_lbl)
	_alarm_sfx_option = OptionButton.new()
	_alarm_sfx_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_alarm_sfx_option.add_item("(none)")
	for i in range(NEBULA_ALARM_IDS.size()):
		_alarm_sfx_option.add_item("Nebula Alarm " + str(i + 1))
	_alarm_sfx_option.item_selected.connect(_on_alarm_sfx_selected)
	alarm_row.add_child(_alarm_sfx_option)

	_warning_controls_container.visible = false  # Hidden until toggled on


func _build_effects_section() -> void:
	_active_slider_container = _right_col
	var panel: VBoxContainer = _right_col

	var section_header := Label.new()
	section_header.text = "EFFECTS"
	section_header.name = "EffectsHeader"
	panel.add_child(section_header)

	# Bar effects
	var bar_label := Label.new()
	bar_label.text = "Bar Rates (per second)"
	bar_label.name = "BarRatesLabel"
	panel.add_child(bar_label)

	_bar_effect_spinboxes.clear()
	var bar_names: Array[String] = ["shield", "hull", "thermal", "electric"]
	for bar_name in bar_names:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		panel.add_child(row)

		var lbl := Label.new()
		lbl.text = bar_name.capitalize()
		lbl.custom_minimum_size.x = 80
		row.add_child(lbl)

		var spin := SpinBox.new()
		spin.min_value = -10.0
		spin.max_value = 10.0
		spin.step = 0.5
		spin.value = 0.0
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.value_changed.connect(_on_bar_effect_changed.bind(bar_name))
		row.add_child(spin)

		_bar_effect_spinboxes[bar_name] = spin

	# Special effects
	var special_label := Label.new()
	special_label.text = "Special Effects"
	special_label.name = "SpecialEffectsLabel"
	panel.add_child(special_label)

	_special_effect_checks.clear()
	for effect_id in KNOWN_SPECIAL_EFFECTS:
		var check := CheckBox.new()
		check.text = effect_id.capitalize().replace("_", " ")
		check.toggled.connect(_on_special_effect_toggled.bind(effect_id))
		panel.add_child(check)
		_special_effect_checks[effect_id] = check

	# Key change preset
	var kc_label := Label.new()
	kc_label.text = "Key Change Preset"
	kc_label.name = "KeyChangeLabel"
	panel.add_child(kc_label)

	var kc_row := HBoxContainer.new()
	kc_row.add_theme_constant_override("separation", 8)
	panel.add_child(kc_row)

	var kc_lbl := Label.new()
	kc_lbl.text = "Preset"
	kc_lbl.custom_minimum_size.x = 80
	kc_row.add_child(kc_lbl)

	_key_change_option = OptionButton.new()
	_key_change_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_key_change_option.add_item("(none)")
	_key_change_ids.clear()
	var all_presets: Array[KeyChangeData] = KeyChangeDataManager.load_all()
	for kc in all_presets:
		_key_change_ids.append(kc.id)
		var suffix: String = ""
		if kc.semitones != 0:
			suffix = " (" + (("+" + str(kc.semitones)) if kc.semitones > 0 else str(kc.semitones)) + " st)"
		_key_change_option.add_item(kc.display_name + suffix)
	_key_change_option.item_selected.connect(_on_key_change_selected)
	kc_row.add_child(_key_change_option)

	# Game events — trigger visual/SFX events periodically while in nebula
	var ge_header := Label.new()
	ge_header.text = "Game Events"
	ge_header.name = "GameEventsLabel"
	panel.add_child(ge_header)

	_game_event_checks.clear()
	_game_event_ids = GameEventDataManager.list_ids()
	for event_id in _game_event_ids:
		var event_data: GameEventData = GameEventDataManager.load_by_id(event_id)
		var check := CheckBox.new()
		check.text = event_data.display_name if event_data else event_id
		check.toggled.connect(_on_game_event_toggled.bind(event_id))
		panel.add_child(check)
		_game_event_checks[event_id] = check

	_event_controls_container = VBoxContainer.new()
	_event_controls_container.add_theme_constant_override("separation", 4)
	panel.add_child(_event_controls_container)

	var min_row := HBoxContainer.new()
	min_row.add_theme_constant_override("separation", 8)
	_event_controls_container.add_child(min_row)
	var min_lbl := Label.new()
	min_lbl.text = "Min Interval"
	min_lbl.custom_minimum_size.x = 100
	min_row.add_child(min_lbl)
	_event_interval_min_slider = HSlider.new()
	_event_interval_min_slider.min_value = 1.0
	_event_interval_min_slider.max_value = 30.0
	_event_interval_min_slider.step = 0.5
	_event_interval_min_slider.value = 5.0
	_event_interval_min_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_event_interval_min_slider.value_changed.connect(_on_event_interval_min_changed)
	min_row.add_child(_event_interval_min_slider)
	_event_interval_min_value = Label.new()
	_event_interval_min_value.text = "5.0s"
	_event_interval_min_value.custom_minimum_size.x = 45
	min_row.add_child(_event_interval_min_value)

	var max_row := HBoxContainer.new()
	max_row.add_theme_constant_override("separation", 8)
	_event_controls_container.add_child(max_row)
	var max_lbl := Label.new()
	max_lbl.text = "Max Interval"
	max_lbl.custom_minimum_size.x = 100
	max_row.add_child(max_lbl)
	_event_interval_max_slider = HSlider.new()
	_event_interval_max_slider.min_value = 1.0
	_event_interval_max_slider.max_value = 60.0
	_event_interval_max_slider.step = 0.5
	_event_interval_max_slider.value = 12.0
	_event_interval_max_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_event_interval_max_slider.value_changed.connect(_on_event_interval_max_changed)
	max_row.add_child(_event_interval_max_slider)
	_event_interval_max_value = Label.new()
	_event_interval_max_value.text = "12.0s"
	_event_interval_max_value.custom_minimum_size.x = 45
	max_row.add_child(_event_interval_max_value)


func _add_slider_row(label_text: String, min_val: float, max_val: float, step: float, default_val: float) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_active_slider_container.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 80
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step
	slider.value = default_val
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 100
	row.add_child(slider)

	var value_label := Label.new()
	value_label.text = str(snapped(default_val, step))
	value_label.custom_minimum_size.x = 45
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	# Store value label ref
	match label_text:
		"Brightness": _brightness_value = value_label
		"Anim Speed": _speed_value = value_label
		"Density": _density_value = value_label
		"Seed": _seed_value = value_label
		"Spread": _spread_value = value_label
		"Bottom": _bottom_opacity_value = value_label
		"Top Veil": _top_opacity_value = value_label
		"Veil Edge": _veil_contrast_value = value_label
		"Wash": _wash_opacity_value = value_label
		"Frequency": _storm_frequency_value = value_label
		"Strike Size": _storm_strike_size_value = value_label
		"Duration": _storm_duration_value = value_label
		"Glow Size": _storm_glow_value = value_label

	return slider



# ── List management ───────────────────────────────────────────────────────

func _rebuild_list() -> void:
	for child in _list_container.get_children():
		child.queue_free()

	for nebula in _nebulas:
		var btn := Button.new()
		btn.text = nebula.display_name
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.toggle_mode = true
		btn.button_pressed = (nebula.id == _selected_id)
		btn.pressed.connect(_on_list_item_pressed.bind(nebula.id))
		btn.name = "ListItem_" + nebula.id
		_list_container.add_child(btn)
		ThemeManager.apply_button_style(btn)

	_delete_btn.disabled = (_selected_id == "")


func _show_empty_state() -> void:
	_selected_id = ""
	_editor_panel.visible = true
	_preview_container.visible = false
	_empty_label.visible = true
	_name_edit.get_parent().visible = false
	_style_option.get_parent().visible = false
	_params_columns.visible = false
	_delete_btn.disabled = true


func _show_editor_state() -> void:
	_preview_container.visible = true
	_empty_label.visible = false
	_name_edit.get_parent().visible = true
	_style_option.get_parent().visible = true
	_params_columns.visible = true


# ── Selection + data loading ──────────────────────────────────────────────

func _select_nebula(id: String) -> void:
	_selected_id = id
	_show_editor_state()

	var data: NebulaData = _get_nebula_by_id(id)
	if not data:
		_show_empty_state()
		return

	_suppressing_signals = true

	_name_edit.text = data.display_name

	# Style dropdown
	var style_idx: int = _style_keys.find(data.style_id)
	if style_idx >= 0:
		_style_option.selected = style_idx

	var params: Dictionary = data.shader_params
	var defaults: Dictionary = NebulaData.default_params()

	# Appearance
	var color_arr: Array = params.get("nebula_color", defaults["nebula_color"])
	_color_picker.color = Color(color_arr[0], color_arr[1], color_arr[2], color_arr[3])

	var color2_arr: Array = params.get("secondary_color", defaults["secondary_color"])
	_color2_picker.color = Color(color2_arr[0], color2_arr[1], color2_arr[2], color2_arr[3])

	_set_slider(_brightness_slider, _brightness_value, float(params.get("brightness", defaults["brightness"])), 0.05)
	_set_slider(_speed_slider, _speed_value, float(params.get("animation_speed", defaults["animation_speed"])), 0.05)
	_set_slider(_density_slider, _density_value, float(params.get("density", defaults["density"])), 0.05)
	_set_slider(_seed_slider, _seed_value, float(params.get("seed_offset", defaults["seed_offset"])), 1.0)
	_set_slider(_spread_slider, _spread_value, float(params.get("radial_spread", defaults["radial_spread"])), 0.05)

	# Layers
	_set_slider(_bottom_opacity_slider, _bottom_opacity_value, float(params.get("bottom_opacity", defaults["bottom_opacity"])), 0.05)
	_set_slider(_top_opacity_slider, _top_opacity_value, float(params.get("top_opacity", defaults["top_opacity"])), 0.01)
	_set_slider(_veil_contrast_slider, _veil_contrast_value, float(params.get("veil_contrast", defaults["veil_contrast"])), 0.01)
	_set_slider(_wash_opacity_slider, _wash_opacity_value, float(params.get("wash_opacity", defaults["wash_opacity"])), 0.01)

	# Storm
	var storm_on: bool = bool(params.get("storm_enabled", defaults["storm_enabled"]))
	_storm_enabled_check.button_pressed = storm_on
	_storm_controls_container.visible = storm_on
	_set_slider(_storm_frequency_slider, _storm_frequency_value, float(params.get("storm_frequency", defaults["storm_frequency"])), 0.05)
	_set_slider(_storm_strike_size_slider, _storm_strike_size_value, float(params.get("storm_strike_size", defaults["storm_strike_size"])), 0.01)
	_set_slider(_storm_duration_slider, _storm_duration_value, float(params.get("storm_duration", defaults["storm_duration"])), 0.01)
	_set_slider(_storm_glow_slider, _storm_glow_value, float(params.get("storm_glow_diameter", defaults["storm_glow_diameter"])), 0.01)

	# Effects
	for bar_name in _bar_effect_spinboxes:
		var spin: SpinBox = _bar_effect_spinboxes[bar_name]
		spin.value = float(data.bar_effects.get(bar_name, 0.0))

	for effect_id in _special_effect_checks:
		var check: CheckBox = _special_effect_checks[effect_id]
		check.button_pressed = data.special_effects.has(effect_id)

	if data.key_change_id == "" or data.key_change_id not in _key_change_ids:
		_key_change_option.selected = 0
	else:
		_key_change_option.selected = _key_change_ids.find(data.key_change_id) + 1

	# Game events
	for event_id in _game_event_checks:
		var check: CheckBox = _game_event_checks[event_id]
		check.button_pressed = data.event_ids.has(event_id)
	_event_interval_min_slider.value = data.event_interval_min
	_event_interval_min_value.text = str(snapped(data.event_interval_min, 0.5)) + "s"
	_event_interval_max_slider.value = data.event_interval_max
	_event_interval_max_value.text = str(snapped(data.event_interval_max, 0.5)) + "s"
	var has_events: bool = data.event_ids.size() > 0
	_event_controls_container.visible = has_events

	# Warning
	_warning_enabled_check.button_pressed = data.warning_enabled
	_warning_controls_container.visible = data.warning_enabled
	_warning_text_edit.text = data.warning_text
	var wc: Array = data.warning_color
	if wc.size() >= 4:
		_warning_color_picker.color = Color(float(wc[0]), float(wc[1]), float(wc[2]), float(wc[3]))
	if data.alarm_sfx_id == "" or data.alarm_sfx_id not in NEBULA_ALARM_IDS:
		_alarm_sfx_option.selected = 0
	else:
		_alarm_sfx_option.selected = NEBULA_ALARM_IDS.find(data.alarm_sfx_id) + 1

	_suppressing_signals = false

	# Show/hide secondary color based on style
	var style_info: Dictionary = STYLES.get(data.style_id, {})
	_color2_row.visible = style_info.get("dual", false)

	_update_preview()
	_update_list_selection()


func _set_slider(slider: HSlider, label: Label, val: float, step: float) -> void:
	slider.value = val
	label.text = str(snapped(val, step))


func _update_list_selection() -> void:
	for child in _list_container.get_children():
		if child is Button:
			var btn_id: String = child.name.replace("ListItem_", "")
			child.button_pressed = (btn_id == _selected_id)


# ── Preview rendering ─────────────────────────────────────────────────────

func _update_preview() -> void:
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if not data:
		_preview_bottom.material = null
		_preview_top.material = null
		_preview_storm.material = null
		_preview_storm.visible = false
		return

	var style_info: Dictionary = STYLES.get(data.style_id, {})
	var shader_path: String = style_info.get("shader", "")
	if shader_path == "":
		_preview_bottom.material = null
		_preview_top.material = null
		_preview_storm.material = null
		_preview_storm.visible = false
		return

	var shader_res: Shader = load(shader_path) as Shader
	if not shader_res:
		_preview_bottom.material = null
		_preview_top.material = null
		_preview_storm.material = null
		_preview_storm.visible = false
		return

	var params: Dictionary = data.shader_params
	var defaults: Dictionary = NebulaData.default_params()

	# Build base shader material
	var mat := ShaderMaterial.new()
	mat.shader = shader_res

	var color_arr: Array = params.get("nebula_color", defaults["nebula_color"])
	mat.set_shader_parameter("nebula_color", Color(color_arr[0], color_arr[1], color_arr[2], color_arr[3]))

	if style_info.get("dual", false):
		var color2_arr: Array = params.get("secondary_color", defaults["secondary_color"])
		mat.set_shader_parameter("secondary_color", Color(color2_arr[0], color2_arr[1], color2_arr[2], color2_arr[3]))

	mat.set_shader_parameter("brightness", float(params.get("brightness", defaults["brightness"])))
	mat.set_shader_parameter("animation_speed", float(params.get("animation_speed", defaults["animation_speed"])))
	mat.set_shader_parameter("density", float(params.get("density", defaults["density"])))
	mat.set_shader_parameter("seed_offset", float(params.get("seed_offset", defaults["seed_offset"])))
	mat.set_shader_parameter("radial_spread", float(params.get("radial_spread", defaults["radial_spread"])))


	# Bottom layer
	_preview_bottom.material = mat
	_preview_bottom.modulate.a = float(params.get("bottom_opacity", defaults["bottom_opacity"]))

	# Top veil
	var veil_shader: Shader = load("res://assets/shaders/nebula_veil.gdshader") as Shader
	if veil_shader:
		var top_mat := ShaderMaterial.new()
		top_mat.shader = veil_shader
		top_mat.set_shader_parameter("nebula_color", mat.get_shader_parameter("nebula_color"))
		top_mat.set_shader_parameter("brightness", float(params.get("brightness", defaults["brightness"])))
		top_mat.set_shader_parameter("animation_speed", float(params.get("animation_speed", defaults["animation_speed"])))
		top_mat.set_shader_parameter("density", float(params.get("density", defaults["density"])))
		top_mat.set_shader_parameter("seed_offset", float(params.get("seed_offset", defaults["seed_offset"])))
		top_mat.set_shader_parameter("radial_spread", float(params.get("radial_spread", defaults["radial_spread"])))
		top_mat.set_shader_parameter("veil_contrast", float(params.get("veil_contrast", defaults["veil_contrast"])))
		_preview_top.material = top_mat
	else:
		var top_mat := mat.duplicate() as ShaderMaterial
		_preview_top.material = top_mat
	_preview_top.modulate.a = float(params.get("top_opacity", defaults["top_opacity"]))

	# Wash layer
	var wash_opacity: float = float(params.get("wash_opacity", defaults["wash_opacity"]))
	var wash_shader: Shader = load("res://assets/shaders/nebula_wash.gdshader") as Shader
	if wash_shader:
		var wash_mat := ShaderMaterial.new()
		wash_mat.shader = wash_shader
		var wash_color_arr: Array = params.get("nebula_color", defaults["nebula_color"])
		wash_mat.set_shader_parameter("nebula_color", Color(float(wash_color_arr[0]), float(wash_color_arr[1]), float(wash_color_arr[2]), 1.0))
		wash_mat.set_shader_parameter("radial_spread", float(params.get("radial_spread", defaults["radial_spread"])))
		_preview_wash.material = wash_mat
	else:
		_preview_wash.material = null
	_preview_wash.color = Color.WHITE
	_preview_wash.modulate.a = wash_opacity

	# Storm overlay layer
	var storm_on: bool = bool(params.get("storm_enabled", defaults["storm_enabled"]))
	if storm_on:
		var storm_shader: Shader = load("res://assets/shaders/nebula_storm_overlay.gdshader") as Shader
		if storm_shader:
			var storm_mat := ShaderMaterial.new()
			storm_mat.shader = storm_shader
			storm_mat.set_shader_parameter("nebula_color", mat.get_shader_parameter("nebula_color"))
			storm_mat.set_shader_parameter("animation_speed", float(params.get("animation_speed", defaults["animation_speed"])))
			storm_mat.set_shader_parameter("seed_offset", float(params.get("seed_offset", defaults["seed_offset"])))
			storm_mat.set_shader_parameter("radial_spread", float(params.get("radial_spread", defaults["radial_spread"])))
			storm_mat.set_shader_parameter("brightness", float(params.get("brightness", defaults["brightness"])))
			storm_mat.set_shader_parameter("storm_frequency", float(params.get("storm_frequency", defaults["storm_frequency"])))
			storm_mat.set_shader_parameter("storm_strike_size", float(params.get("storm_strike_size", defaults["storm_strike_size"])))
			storm_mat.set_shader_parameter("storm_duration", float(params.get("storm_duration", defaults["storm_duration"])))
			storm_mat.set_shader_parameter("storm_glow_diameter", float(params.get("storm_glow_diameter", defaults["storm_glow_diameter"])))
			_preview_storm.material = storm_mat
			_preview_storm.visible = true
		else:
			_preview_storm.material = null
			_preview_storm.visible = false
	else:
		_preview_storm.material = null
		_preview_storm.visible = false


func _get_nebula_by_id(id: String) -> NebulaData:
	for n in _nebulas:
		if n.id == id:
			return n
	return null


func _generate_unique_id() -> String:
	var existing: Array[String] = []
	for n in _nebulas:
		existing.append(n.id)
	var counter: int = 1
	while true:
		var candidate: String = "nebula_" + str(counter)
		if candidate not in existing:
			return candidate
		counter += 1
	return "nebula_1"


func _auto_save() -> void:
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if not data:
		return
	if data.id != _selected_id:
		var old_id: String = _selected_id
		NebulaDataManager.rename(old_id, data.id, data)
		_selected_id = data.id
		_rebuild_list()
		_update_list_selection()
	else:
		NebulaDataManager.save(data)


# ── Signal handlers ───────────────────────────────────────────────────────

func _on_create_new() -> void:
	var id: String = _generate_unique_id()
	var counter: int = _nebulas.size() + 1
	var data := NebulaData.new()
	data.id = id
	data.display_name = "Nebula " + str(counter)
	data.style_id = "classic_fbm"
	data.shader_params = NebulaData.default_params()
	NebulaDataManager.save(data)
	_nebulas.append(data)
	_rebuild_list()
	_select_nebula(id)


func _on_delete() -> void:
	if _selected_id == "":
		return
	NebulaDataManager.delete(_selected_id)
	var idx: int = -1
	for i in range(_nebulas.size()):
		if _nebulas[i].id == _selected_id:
			idx = i
			break
	if idx >= 0:
		_nebulas.remove_at(idx)

	if _nebulas.size() > 0:
		var new_idx: int = mini(idx, _nebulas.size() - 1)
		_rebuild_list()
		_select_nebula(_nebulas[new_idx].id)
	else:
		_selected_id = ""
		_rebuild_list()
		_show_empty_state()


func _on_list_item_pressed(id: String) -> void:
	_select_nebula(id)


func _on_name_changed(new_name: String) -> void:
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if data:
		data.display_name = new_name
		_auto_save()
		for child in _list_container.get_children():
			if child is Button and child.name == "ListItem_" + _selected_id:
				child.text = new_name


func _on_style_changed(idx: int) -> void:
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if not data:
		return
	data.style_id = _style_keys[idx]
	var style_info: Dictionary = STYLES[data.style_id]
	_color2_row.visible = style_info.get("dual", false)
	_update_preview()
	_auto_save()


# --- Appearance handlers ---

func _on_color_changed(color: Color) -> void:
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if data:
		data.shader_params["nebula_color"] = [color.r, color.g, color.b, color.a]
		_update_preview()
		_auto_save()


func _on_color2_changed(color: Color) -> void:
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if data:
		data.shader_params["secondary_color"] = [color.r, color.g, color.b, color.a]
		_update_preview()
		_auto_save()


func _on_brightness_changed(val: float) -> void:
	_brightness_value.text = str(snapped(val, 0.05))
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if data:
		data.shader_params["brightness"] = val
		_update_preview()
		_auto_save()


func _on_speed_changed(val: float) -> void:
	_speed_value.text = str(snapped(val, 0.05))
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if data:
		data.shader_params["animation_speed"] = val
		_update_preview()
		_auto_save()


func _on_density_changed(val: float) -> void:
	_density_value.text = str(snapped(val, 0.05))
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if data:
		data.shader_params["density"] = val
		_update_preview()
		_auto_save()


func _on_seed_changed(val: float) -> void:
	_seed_value.text = str(snapped(val, 1.0))
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if data:
		data.shader_params["seed_offset"] = val
		_update_preview()
		_auto_save()


func _on_spread_changed(val: float) -> void:
	_spread_value.text = str(snapped(val, 0.05))
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if data:
		data.shader_params["radial_spread"] = val
		_update_preview()
		_auto_save()


# --- Layers handlers ---

func _on_bottom_opacity_changed(val: float) -> void:
	_bottom_opacity_value.text = str(snapped(val, 0.05))
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if data:
		data.shader_params["bottom_opacity"] = val
		_update_preview()
		_auto_save()


func _on_top_opacity_changed(val: float) -> void:
	_top_opacity_value.text = str(snapped(val, 0.01))
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if data:
		data.shader_params["top_opacity"] = val
		_update_preview()
		_auto_save()


func _on_veil_contrast_changed(val: float) -> void:
	_veil_contrast_value.text = str(snapped(val, 0.01))
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if data:
		data.shader_params["veil_contrast"] = val
		_update_preview()
		_auto_save()


func _on_wash_opacity_changed(val: float) -> void:
	_wash_opacity_value.text = str(snapped(val, 0.01))
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if data:
		data.shader_params["wash_opacity"] = val
		_update_preview()
		_auto_save()


# --- Storm handlers ---

func _on_storm_enabled_toggled(toggled_on: bool) -> void:
	_storm_controls_container.visible = toggled_on
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if data:
		data.shader_params["storm_enabled"] = toggled_on
		_update_preview()
		_auto_save()


func _on_storm_frequency_changed(val: float) -> void:
	_storm_frequency_value.text = str(snapped(val, 0.05))
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if data:
		data.shader_params["storm_frequency"] = val
		_update_preview()
		_auto_save()


func _on_storm_strike_size_changed(val: float) -> void:
	_storm_strike_size_value.text = str(snapped(val, 0.01))
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if data:
		data.shader_params["storm_strike_size"] = val
		_update_preview()
		_auto_save()


func _on_storm_duration_changed(val: float) -> void:
	_storm_duration_value.text = str(snapped(val, 0.01))
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if data:
		data.shader_params["storm_duration"] = val
		_update_preview()
		_auto_save()


func _on_storm_glow_changed(val: float) -> void:
	_storm_glow_value.text = str(snapped(val, 0.01))
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if data:
		data.shader_params["storm_glow_diameter"] = val
		_update_preview()
		_auto_save()


# --- Warning handlers ---

func _on_warning_enabled_toggled(toggled_on: bool) -> void:
	_warning_controls_container.visible = toggled_on
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if data:
		data.warning_enabled = toggled_on
		_auto_save()


func _on_warning_text_changed(new_text: String) -> void:
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if data:
		data.warning_text = new_text
		_auto_save()


func _on_warning_color_changed(color: Color) -> void:
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if data:
		data.warning_color = [color.r, color.g, color.b, color.a]
		_auto_save()


func _on_alarm_sfx_selected(idx: int) -> void:
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if not data:
		return
	if idx <= 0:
		data.alarm_sfx_id = ""
	else:
		data.alarm_sfx_id = NEBULA_ALARM_IDS[idx - 1]
	_auto_save()


# --- Effects handlers ---

func _on_bar_effect_changed(val: float, bar_name: String) -> void:
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if not data:
		return
	if val == 0.0:
		data.bar_effects.erase(bar_name)
	else:
		data.bar_effects[bar_name] = val
	_auto_save()


func _on_special_effect_toggled(toggled_on: bool, effect_id: String) -> void:
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if not data:
		return
	if toggled_on and not data.special_effects.has(effect_id):
		data.special_effects.append(effect_id)
	elif not toggled_on and data.special_effects.has(effect_id):
		data.special_effects.erase(effect_id)
	_auto_save()


func _on_key_change_selected(idx: int) -> void:
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if not data:
		return
	if idx <= 0:
		data.key_change_id = ""
	else:
		data.key_change_id = _key_change_ids[idx - 1]
	_auto_save()


func _on_game_event_toggled(toggled_on: bool, event_id: String) -> void:
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if not data:
		return
	if toggled_on and not data.event_ids.has(event_id):
		data.event_ids.append(event_id)
	elif not toggled_on and data.event_ids.has(event_id):
		data.event_ids.erase(event_id)
	_event_controls_container.visible = data.event_ids.size() > 0
	_auto_save()


func _on_event_interval_min_changed(val: float) -> void:
	_event_interval_min_value.text = str(snapped(val, 0.5)) + "s"
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if data:
		data.event_interval_min = val
		if data.event_interval_max < val:
			data.event_interval_max = val
			_event_interval_max_slider.value = val
			_event_interval_max_value.text = str(snapped(val, 0.5)) + "s"
		_auto_save()


func _on_event_interval_max_changed(val: float) -> void:
	_event_interval_max_value.text = str(snapped(val, 0.5)) + "s"
	if _suppressing_signals:
		return
	var data: NebulaData = _get_nebula_by_id(_selected_id)
	if data:
		data.event_interval_max = val
		if data.event_interval_min > val:
			data.event_interval_min = val
			_event_interval_min_slider.value = val
			_event_interval_min_value.text = str(snapped(val, 0.5)) + "s"
		_auto_save()


# ── Utility ───────────────────────────────────────────────────────────────

func _center_preview_ship() -> void:
	if _preview_ship and _preview_container:
		var sz: Vector2 = _preview_container.size
		_preview_ship.position = Vector2(sz.x * 0.5, sz.y * 0.5)


func _apply_theme() -> void:
	ThemeManager.apply_button_style(_create_btn)
	ThemeManager.apply_button_style(_delete_btn)

	for child in _list_container.get_children():
		if child is Button:
			ThemeManager.apply_button_style(child)

	# Header labels in left panel
	for child in get_children():
		if child is HSplitContainer:
			var left: VBoxContainer = child.get_child(0) as VBoxContainer
			if left:
				for sub in left.get_children():
					if sub is Label:
						ThemeManager.apply_text_glow(sub, "header")

	# Editor labels (name/style rows)
	for child in _editor_panel.get_children():
		if child is Label:
			ThemeManager.apply_text_glow(child, "header")
		elif child is HBoxContainer:
			for sub in child.get_children():
				if sub is Label:
					ThemeManager.apply_text_glow(sub, "body")

	# Both parameter columns
	_apply_theme_to_container(_left_col)
	_apply_theme_to_container(_right_col)

	# Storm sub-container
	_apply_theme_to_container(_storm_controls_container)

	# Warning sub-container
	_apply_theme_to_container(_warning_controls_container)

	ThemeManager.apply_button_style(_storm_enabled_check)
	ThemeManager.apply_button_style(_warning_enabled_check)
	ThemeManager.apply_text_glow(_empty_label, "body")


func _apply_theme_to_container(container: VBoxContainer) -> void:
	for child in container.get_children():
		if child is Label:
			ThemeManager.apply_text_glow(child, "header")
		elif child is HBoxContainer:
			for sub in child.get_children():
				if sub is Label:
					ThemeManager.apply_text_glow(sub, "body")
		elif child is CheckBox:
			ThemeManager.apply_button_style(child)
		elif child is VBoxContainer:
			_apply_theme_to_container(child)
