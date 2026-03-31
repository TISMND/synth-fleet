extends MarginContainer
## Currency tab — vertical list of all currency items with value, HDR, and scale controls.

var _items: Array[ItemData] = []
var _rows_container: VBoxContainer
var _shard_scale_spin: SpinBox
var _coin_scale_spin: SpinBox


func _ready() -> void:
	_build_ui()
	ThemeManager.theme_changed.connect(_apply_theme)
	call_deferred("_apply_theme")
	call_deferred("_rebuild_rows")


func _build_ui() -> void:
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 10)
	add_child(main)

	# Scale controls
	var scale_row := HBoxContainer.new()
	scale_row.add_theme_constant_override("separation", 16)
	main.add_child(scale_row)

	var header := Label.new()
	header.text = "CURRENCY"
	header.name = "CurrencyHeader"
	scale_row.add_child(header)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale_row.add_child(spacer)

	var cfg: Dictionary = CurrencyConfigManager.load_config()

	var shard_label := Label.new()
	shard_label.text = "Shard Scale:"
	scale_row.add_child(shard_label)

	_shard_scale_spin = SpinBox.new()
	_shard_scale_spin.min_value = 8.0
	_shard_scale_spin.max_value = 96.0
	_shard_scale_spin.step = 2.0
	_shard_scale_spin.value = float(cfg.get("shard_scale", 32.0))
	_shard_scale_spin.value_changed.connect(_on_scale_changed)
	scale_row.add_child(_shard_scale_spin)

	var coin_label := Label.new()
	coin_label.text = "Coin Scale:"
	scale_row.add_child(coin_label)

	_coin_scale_spin = SpinBox.new()
	_coin_scale_spin.min_value = 8.0
	_coin_scale_spin.max_value = 96.0
	_coin_scale_spin.step = 2.0
	_coin_scale_spin.value = float(cfg.get("coin_scale", 32.0))
	_coin_scale_spin.value_changed.connect(_on_scale_changed)
	scale_row.add_child(_coin_scale_spin)

	# Scrollable item rows
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(scroll)

	_rows_container = VBoxContainer.new()
	_rows_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_container.add_theme_constant_override("separation", 6)
	scroll.add_child(_rows_container)


func _rebuild_rows() -> void:
	for child in _rows_container.get_children():
		child.queue_free()

	var all_items: Array[ItemData] = ItemDataManager.load_all()
	_items.clear()
	for item in all_items:
		if item.category == "money":
			_items.append(item)

	for item in _items:
		_add_item_row(item)


func _add_item_row(item: ItemData) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_container.add_child(row)

	# Live preview
	var cell_px: float = 56.0
	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.custom_minimum_size = Vector2(cell_px, cell_px)
	row.add_child(vpc)

	var vp := SubViewport.new()
	vp.transparent_bg = false
	vp.size = Vector2i(int(cell_px), int(cell_px))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vpc.add_child(vp)
	VFXFactory.add_bloom_to_viewport(vp)

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.07, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(bg)

	var renderer := ItemRenderer.new()
	renderer.position = Vector2(cell_px / 2.0, cell_px / 2.0)
	var render_scale: float = CurrencyConfigManager.get_scale_for_item(item)
	renderer.setup(item, render_scale * 0.45)
	vp.add_child(renderer)

	# Name
	var name_label := Label.new()
	name_label.text = item.display_name
	name_label.custom_minimum_size.x = 140
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ThemeManager.apply_text_glow(name_label, "body")
	row.add_child(name_label)

	# Value
	var val_label := Label.new()
	val_label.text = "Value:"
	val_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(val_label)

	var val_spin := SpinBox.new()
	val_spin.min_value = 0.0
	val_spin.max_value = 10000.0
	val_spin.step = 5.0
	val_spin.value = item.value
	val_spin.custom_minimum_size.x = 80
	val_spin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	val_spin.value_changed.connect(func(v: float) -> void:
		item.value = v
		ItemDataManager.save(item)
	)
	row.add_child(val_spin)

	# HDR
	var hdr_label := Label.new()
	hdr_label.text = "HDR:"
	hdr_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(hdr_label)

	var hdr_spin := SpinBox.new()
	hdr_spin.min_value = 0.5
	hdr_spin.max_value = 4.0
	hdr_spin.step = 0.1
	hdr_spin.value = item.hdr_intensity
	hdr_spin.custom_minimum_size.x = 70
	hdr_spin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hdr_spin.value_changed.connect(func(v: float) -> void:
		item.hdr_intensity = v
		ItemDataManager.save(item)
		renderer.queue_redraw()
	)
	row.add_child(hdr_spin)


func _on_scale_changed(_val: float) -> void:
	var cfg := {
		"shard_scale": _shard_scale_spin.value,
		"coin_scale": _coin_scale_spin.value,
	}
	CurrencyConfigManager.save_config(cfg)
	_rebuild_rows()


func _apply_theme() -> void:
	for child in _rows_container.get_children():
		if child is HBoxContainer:
			for sub in child.get_children():
				if sub is Label:
					ThemeManager.apply_text_glow(sub, "body")
