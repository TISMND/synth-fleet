class_name FieldEmittersTab
extends DeviceTabBase
## Field Emitters tab — editor for field-type devices (force fields, shields, auras).

# Visual subtab controls
var _field_style_button: OptionButton

# Active envelope (per-trigger field visibility)
var _active_always_on_toggle: CheckButton
var _active_total_dur_slider: HSlider
var _active_total_dur_label: Label
var _active_fade_in_slider: HSlider
var _active_fade_in_label: Label
var _active_fade_out_slider: HSlider
var _active_fade_out_label: Label
var _active_envelope_active: bool = false
var _active_envelope_elapsed: float = 0.0

# Cosmetic pulse lane + envelope
var _visual_pulse_lane: BarEffectLane
var _pulse_total_dur_slider: HSlider
var _pulse_total_dur_label: Label
var _pulse_fade_up_slider: HSlider
var _pulse_fade_up_label: Label
var _pulse_fade_out_slider: HSlider
var _pulse_fade_out_label: Label
var _visual_pulse_active: bool = false
var _visual_pulse_elapsed: float = 0.0

# Preview
var _preview_field_sprite: Sprite2D = null
var _preview_field_material: ShaderMaterial = null


func _get_visual_mode() -> String:
	return "field"

func _get_type_label() -> String:
	return "FIELD EMITTER"

func _get_id_prefix() -> String:
	return "fem_"

func _get_bar_effect_range() -> Vector2:
	return Vector2(-50.0, 50.0)

func _get_passive_effect_range() -> Vector2:
	return Vector2(-50.0, 50.0)

func _save_data(id: String, data: Dictionary) -> void:
	FieldEmitterDataManager.save(id, data)

func _rename_data(old_id: String, new_id: String, data: Dictionary) -> void:
	FieldEmitterDataManager.rename(old_id, new_id, data)

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

	return scroll


func _setup_visual_preview(viewport: SubViewport) -> void:
	var field_node := Node2D.new()
	field_node.position = Vector2(150, 150)
	viewport.add_child(field_node)

	_preview_field_sprite = Sprite2D.new()
	_preview_field_sprite.z_index = 1
	var img := Image.create(200, 200, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_preview_field_sprite.texture = ImageTexture.create_from_image(img)
	field_node.add_child(_preview_field_sprite)


func _update_visual_preview() -> void:
	if not _ui_ready or not _preview_field_sprite or not _field_style_button:
		return

	var style_idx: int = _field_style_button.selected
	if style_idx <= 0:
		var shader: Shader = VFXFactory.get_field_shader("force_bubble")
		if shader:
			_preview_field_material = ShaderMaterial.new()
			_preview_field_material.shader = shader
			_preview_field_material.set_shader_parameter("field_color", Color.WHITE)
			_preview_field_material.set_shader_parameter("brightness", 1.0)
			_preview_field_material.set_shader_parameter("opacity", 0.0)
			_preview_field_material.set_shader_parameter("pulse_intensity", 0.0)
			_preview_field_sprite.material = _preview_field_material
		return

	var style_id: String = _field_style_button.get_item_text(style_idx)
	var style: FieldStyle = FieldStyleManager.load_by_id(style_id)
	if not style:
		return

	_preview_field_material = VFXFactory.create_field_material(style, 100.0)
	# Start invisible — active envelope will drive opacity when triggers fire
	_preview_field_material.set_shader_parameter("opacity", 0.0)
	_preview_field_sprite.material = _preview_field_material
	var vp: Viewport = _preview_field_sprite.get_viewport()
	var vp_size: String = str(vp.size) if vp else "null"
	print("[FIELD-PREVIEW] shader=%s brightness=%.2f color=%s viewport=%s" % [style.field_shader, style.glow_intensity, str(style.color), vp_size])


func _on_auto_pulse() -> void:
	# Auto-pulse only affects bars (handled by base class).
	# Field envelopes are driven exclusively by trigger crossings during loop playback.
	pass


func _on_trigger_crossed() -> void:
	# Functional triggers → field visual appears (active envelope) + bar effects (base class)
	# In always-on mode, field is permanently visible — triggers just fire bar effects
	if not _active_always_on_toggle or not _active_always_on_toggle.button_pressed:
		_active_envelope_active = true
		_active_envelope_elapsed = 0.0
	if not _preview_field_material:
		_update_visual_preview()


func _on_visual_pulse_crossed() -> void:
	# Cosmetic triggers → field shader pulse
	_visual_pulse_active = true
	_visual_pulse_elapsed = 0.0


func _get_visual_pulse_triggers() -> Array:
	if _visual_pulse_lane:
		var lane_trigs: Array = _visual_pulse_lane.get_triggers()
		var times: Array = []
		for trig in lane_trigs:
			var d: Dictionary = trig as Dictionary
			times.append(float(d.get("time", 0.0)))
		return times
	return []


func _on_snap_mode_updated(mode: int) -> void:
	if _visual_pulse_lane:
		_visual_pulse_lane.set_snap_mode(mode)


func _on_bars_updated(bars: int) -> void:
	if _visual_pulse_lane:
		_visual_pulse_lane.set_loop_length_bars(bars)


func _build_post_waveform_content(parent: VBoxContainer) -> void:
	# Active envelope — per-trigger field visibility (fade in → sustain → fade out)
	_add_section_header(parent, "ACTIVE ENVELOPE")

	_active_always_on_toggle = CheckButton.new()
	_active_always_on_toggle.text = "Always On"
	_active_always_on_toggle.toggled.connect(func(pressed: bool) -> void:
		var dim: float = 0.3 if pressed else 1.0
		_active_total_dur_slider.editable = not pressed
		_active_total_dur_slider.modulate = Color(1, 1, 1, dim)
		_active_fade_out_slider.editable = not pressed
		_active_fade_out_slider.modulate = Color(1, 1, 1, dim)
		if pressed:
			_active_envelope_active = true
			_active_envelope_elapsed = 0.0
			if _preview_field_material:
				_preview_field_material.set_shader_parameter("opacity", 1.0)
		_mark_dirty()
	)
	parent.add_child(_active_always_on_toggle)

	var atd_row: Array = _add_slider_row(parent, "Total Dur:", 0.0, 10.0, 1.0, 0.05)
	_active_total_dur_slider = atd_row[0]
	_active_total_dur_label = atd_row[1]

	var afi_row: Array = _add_slider_row(parent, "Fade In:", 0.0, 2.0, 0.2, 0.01)
	_active_fade_in_slider = afi_row[0]
	_active_fade_in_label = afi_row[1]

	var afo_row: Array = _add_slider_row(parent, "Fade Out:", 0.0, 2.0, 0.5, 0.01)
	_active_fade_out_slider = afo_row[0]
	_active_fade_out_label = afo_row[1]

	_add_separator(parent)

	# Cosmetic pulse lane
	_visual_pulse_lane = BarEffectLane.new()
	_visual_pulse_lane.setup("visual_pulse", "PULSE", Color(0.5, 0.8, 1.0), 1.0)
	_visual_pulse_lane.set_waveform_ref(_waveform_editor)
	_visual_pulse_lane.triggers_changed.connect(func(_t: Array) -> void: _mark_dirty())
	parent.add_child(_visual_pulse_lane)

	# Pulse envelope sliders
	_add_section_header(parent, "PULSE ENVELOPE")

	var ptd_row: Array = _add_slider_row(parent, "Total Dur:", 0.1, 2.0, 0.5, 0.05)
	_pulse_total_dur_slider = ptd_row[0]
	_pulse_total_dur_label = ptd_row[1]

	var pfu_row: Array = _add_slider_row(parent, "Fade Up:", 0.01, 1.0, 0.05, 0.01)
	_pulse_fade_up_slider = pfu_row[0]
	_pulse_fade_up_label = pfu_row[1]

	var pfo_row: Array = _add_slider_row(parent, "Fade Out:", 0.01, 2.0, 0.4, 0.01)
	_pulse_fade_out_slider = pfo_row[0]
	_pulse_fade_out_label = pfo_row[1]


func _update_visual_preview_frame(delta: float) -> void:
	# Ensure material exists — create on demand if style is selected but material is missing
	if not _preview_field_material:
		_update_visual_preview()
	if not _preview_field_material:
		return
	# Ensure sprite still has our material (guards against external overwrite)
	if _preview_field_sprite and _preview_field_sprite.material != _preview_field_material:
		_preview_field_sprite.material = _preview_field_material

	# ── Always-on mode: field permanently visible ──
	var is_always_on: bool = _active_always_on_toggle and _active_always_on_toggle.button_pressed
	if is_always_on:
		_preview_field_material.set_shader_parameter("opacity", 1.0)
	# ── Active envelope: drives field opacity (fade in → sustain → fade out) ──
	elif _active_envelope_active:
		var total_dur: float = _active_total_dur_slider.value if _active_total_dur_slider else 1.0
		var fade_in: float = _active_fade_in_slider.value if _active_fade_in_slider else 0.2
		var fade_out: float = _active_fade_out_slider.value if _active_fade_out_slider else 0.5
		if fade_in + fade_out > total_dur:
			var ratio: float = total_dur / maxf(fade_in + fade_out, 0.001)
			fade_in *= ratio
			fade_out *= ratio
		_active_envelope_elapsed += delta
		if _active_envelope_elapsed >= total_dur:
			_active_envelope_active = false
			_preview_field_material.set_shader_parameter("opacity", 0.0)
		else:
			var fade_out_start: float = total_dur - fade_out
			var envelope: float
			if _active_envelope_elapsed < fade_in:
				envelope = _active_envelope_elapsed / maxf(fade_in, 0.001)
			elif _active_envelope_elapsed < fade_out_start:
				envelope = 1.0
			else:
				var remaining: float = total_dur - _active_envelope_elapsed
				envelope = remaining / maxf(fade_out, 0.001)
			_preview_field_material.set_shader_parameter("opacity", clampf(envelope, 0.0, 1.0))

	# ── Pulse envelope: drives pulse_intensity on top of active visibility ──
	if _visual_pulse_active:
		var total_dur: float = _pulse_total_dur_slider.value if _pulse_total_dur_slider else 0.5
		var fade_up: float = _pulse_fade_up_slider.value if _pulse_fade_up_slider else 0.05
		var fade_out: float = _pulse_fade_out_slider.value if _pulse_fade_out_slider else 0.4
		if fade_up + fade_out > total_dur:
			var ratio: float = total_dur / maxf(fade_up + fade_out, 0.001)
			fade_up *= ratio
			fade_out *= ratio
		_visual_pulse_elapsed += delta
		if _visual_pulse_elapsed >= total_dur:
			_visual_pulse_active = false
			_preview_field_material.set_shader_parameter("pulse_intensity", 0.0)
		else:
			var fade_out_start: float = total_dur - fade_out
			var envelope: float
			if _visual_pulse_elapsed < fade_up:
				envelope = _visual_pulse_elapsed / maxf(fade_up, 0.001)
			elif _visual_pulse_elapsed < fade_out_start:
				envelope = 1.0
			else:
				var remaining: float = total_dur - _visual_pulse_elapsed
				envelope = remaining / maxf(fade_out, 0.001)
			var pulse_bright: float = 2.0
			if _field_style_button and _field_style_button.selected > 0:
				var style_id: String = _field_style_button.get_item_text(_field_style_button.selected)
				var style: FieldStyle = FieldStyleManager.load_by_id(style_id)
				if style:
					pulse_bright = style.pulse_brightness
			_preview_field_material.set_shader_parameter("pulse_intensity", clampf(envelope * pulse_bright, 0.0, pulse_bright))

	# Ship modulation: HDR brightness + color tint from field style
	if _preview_ship_renderer:
		var active_opacity: float = 0.0
		if _preview_field_material:
			active_opacity = float(_preview_field_material.get_shader_parameter("opacity"))
		var pulse_val: float = 0.0
		if _preview_field_material:
			pulse_val = float(_preview_field_material.get_shader_parameter("pulse_intensity"))
		# Read ship effect params from loaded field style
		var tint_strength: float = 0.15
		var active_hdr: float = 0.2
		var pulse_hdr: float = 0.5
		var field_col: Color = Color.WHITE
		if _field_style_button and _field_style_button.selected > 0:
			var sid: String = _field_style_button.get_item_text(_field_style_button.selected)
			var st: FieldStyle = FieldStyleManager.load_by_id(sid)
			if st:
				tint_strength = st.ship_tint_strength
				active_hdr = st.ship_active_hdr
				pulse_hdr = st.ship_pulse_hdr
				field_col = st.color
		var bright: float = 1.0 + active_opacity * active_hdr + pulse_val * pulse_hdr
		var tint_scaled: float = tint_strength * active_opacity
		var r: float = lerpf(bright, field_col.r * bright * 1.5, tint_scaled)
		var g: float = lerpf(bright, field_col.g * bright * 1.5, tint_scaled)
		var b: float = lerpf(bright, field_col.b * bright * 1.5, tint_scaled)
		_preview_ship_renderer.modulate = Color(r, g, b, 1.0)


func _collect_visual_data(data: Dictionary) -> void:
	data["radius"] = 100.0
	data["field_style_id"] = ""
	if _field_style_button.selected > 0:
		data["field_style_id"] = _field_style_button.get_item_text(_field_style_button.selected)
	data["orbiter_style_id"] = ""
	data["orbiter_lifetime"] = 4.0
	# Active envelope
	data["active_always_on"] = _active_always_on_toggle.button_pressed if _active_always_on_toggle else false
	data["active_total_duration"] = _active_total_dur_slider.value if _active_total_dur_slider else 1.0
	data["active_fade_in"] = _active_fade_in_slider.value if _active_fade_in_slider else 0.2
	data["active_fade_out"] = _active_fade_out_slider.value if _active_fade_out_slider else 0.5
	# Cosmetic pulse data
	data["visual_pulse_triggers"] = _collect_visual_pulse_times()
	data["pulse_total_duration"] = _pulse_total_dur_slider.value if _pulse_total_dur_slider else 0.5
	data["pulse_fade_up"] = _pulse_fade_up_slider.value if _pulse_fade_up_slider else 0.05
	data["pulse_fade_out"] = _pulse_fade_out_slider.value if _pulse_fade_out_slider else 0.4


func _populate_visual_fields(device: DeviceData) -> void:
	_refresh_field_style_list()
	if device.field_style_id != "":
		for i in _field_style_button.get_item_count():
			if _field_style_button.get_item_text(i) == device.field_style_id:
				_field_style_button.selected = i
				break

	# Active envelope
	if _active_always_on_toggle:
		_active_always_on_toggle.button_pressed = device.active_always_on
	if _active_total_dur_slider:
		_active_total_dur_slider.value = device.active_total_duration
	if _active_fade_in_slider:
		_active_fade_in_slider.value = device.active_fade_in
	if _active_fade_out_slider:
		_active_fade_out_slider.value = device.active_fade_out

	# Cosmetic pulse lane + envelope
	if _visual_pulse_lane:
		_visual_pulse_lane.set_triggers(_times_to_lane_triggers(device.visual_pulse_triggers))
	if _pulse_total_dur_slider:
		_pulse_total_dur_slider.value = device.pulse_total_duration
	if _pulse_fade_up_slider:
		_pulse_fade_up_slider.value = device.pulse_fade_up
	if _pulse_fade_out_slider:
		_pulse_fade_out_slider.value = device.pulse_fade_out


func _reset_visual_defaults() -> void:
	_field_style_button.selected = 0
	if _active_always_on_toggle:
		_active_always_on_toggle.button_pressed = false
	if _active_total_dur_slider:
		_active_total_dur_slider.value = 1.0
	if _active_fade_in_slider:
		_active_fade_in_slider.value = 0.2
	if _active_fade_out_slider:
		_active_fade_out_slider.value = 0.5
	if _visual_pulse_lane:
		_visual_pulse_lane.clear_triggers()
	if _pulse_total_dur_slider:
		_pulse_total_dur_slider.value = 0.5
	if _pulse_fade_up_slider:
		_pulse_fade_up_slider.value = 0.05
	if _pulse_fade_out_slider:
		_pulse_fade_out_slider.value = 0.4


func _refresh_field_style_list() -> void:
	var current_sel: int = _field_style_button.selected if _field_style_button.get_item_count() > 0 else 0
	_field_style_button.clear()
	_field_style_button.add_item("(none)")
	var ids: Array[String] = FieldStyleManager.list_ids()
	for id in ids:
		_field_style_button.add_item(id)
	if current_sel < _field_style_button.get_item_count():
		_field_style_button.selected = current_sel


func _collect_visual_pulse_times() -> Array:
	if not _visual_pulse_lane:
		return []
	var lane_trigs: Array = _visual_pulse_lane.get_triggers()
	var times: Array = []
	for trig in lane_trigs:
		var d: Dictionary = trig as Dictionary
		times.append(float(d.get("time", 0.0)))
	times.sort()
	return times


func _times_to_lane_triggers(times: Array) -> Array:
	var lane_trigs: Array = []
	for t in times:
		lane_trigs.append({"time": float(t), "type": "visual_pulse", "value": 1.0})
	return lane_trigs
