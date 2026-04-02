extends MarginContainer
## Title auditions — shows aggressive 80s chrome title style presets for "SYNTHERION".
## Uses the title_chrome shader for multi-band metallic gradients, bevels, gleam, and shadow.

const TITLE_TEXT: String = "SYNTHERION"
const SHADER_PATH: String = "res://assets/shaders/title_chrome.gdshader"
const VP_W: int = 900
const VP_H: int = 140
const BG_COLOR: Color = Color(0.015, 0.015, 0.03, 1.0)

var _presets: Array[Dictionary] = []
var _scroll: ScrollContainer
var _grid: VBoxContainer


func _ready() -> void:
	_define_presets()
	_build_ui()
	ThemeManager.theme_changed.connect(func(): queue_redraw())


func _define_presets() -> void:
	# ── COLD STEEL ───────────────────────────────────────────────────
	# Classic 80s chrome: dark-bright-dark-bright-dark, cool blue tint,
	# sharp bands, line texture, strong bevel, animated gleam
	_presets.append({
		"name": "COLD STEEL — Orbitron",
		"font": "res://assets/fonts/Orbitron.ttf",
		"size": 72,
		"color": Color(0.7, 0.8, 1.0),
		"params": {
			"chrome_color_top": Color(0.05, 0.08, 0.15),
			"chrome_color_highlight1": Color(0.8, 0.88, 1.0),
			"chrome_color_mid": Color(0.1, 0.14, 0.22),
			"chrome_color_highlight2": Color(0.55, 0.65, 0.9),
			"chrome_color_bottom": Color(0.03, 0.05, 0.1),
			"band1_pos": 0.2, "band2_pos": 0.42, "band3_pos": 0.58, "band4_pos": 0.82,
			"band_sharpness": 15.0,
			"line_density": 90.0, "line_strength": 0.12,
			"bevel_strength": 0.9, "bevel_size": 1.8,
			"shadow_offset_x": 2.5, "shadow_offset_y": 3.5, "shadow_softness": 3.0,
			"shadow_color": Color(0.0, 0.02, 0.08, 0.85),
			"gleam_enabled": 1.0, "gleam_speed": 0.6, "gleam_width": 0.07, "gleam_intensity": 1.8,
			"hdr_boost": 1.3,
		}
	})

	# ── COLD STEEL — Bungee variant ──────────────────────────────────
	_presets.append({
		"name": "COLD STEEL — Bungee",
		"font": "res://assets/fonts/Bungee-Regular.ttf",
		"size": 76,
		"color": Color(0.7, 0.8, 1.0),
		"params": {
			"chrome_color_top": Color(0.05, 0.08, 0.15),
			"chrome_color_highlight1": Color(0.8, 0.88, 1.0),
			"chrome_color_mid": Color(0.1, 0.14, 0.22),
			"chrome_color_highlight2": Color(0.55, 0.65, 0.9),
			"chrome_color_bottom": Color(0.03, 0.05, 0.1),
			"band1_pos": 0.22, "band2_pos": 0.44, "band3_pos": 0.56, "band4_pos": 0.8,
			"band_sharpness": 18.0,
			"line_density": 100.0, "line_strength": 0.1,
			"bevel_strength": 1.0, "bevel_size": 2.0,
			"shadow_offset_x": 3.0, "shadow_offset_y": 4.0, "shadow_softness": 3.5,
			"shadow_color": Color(0.0, 0.02, 0.08, 0.9),
			"gleam_enabled": 1.0, "gleam_speed": 0.5, "gleam_width": 0.06, "gleam_intensity": 2.0,
			"hdr_boost": 1.3,
		}
	})

	# ── COLD STEEL — RussoOne variant ────────────────────────────────
	_presets.append({
		"name": "COLD STEEL — RussoOne",
		"font": "res://assets/fonts/RussoOne-Regular.ttf",
		"size": 72,
		"color": Color(0.7, 0.8, 1.0),
		"params": {
			"chrome_color_top": Color(0.05, 0.08, 0.15),
			"chrome_color_highlight1": Color(0.85, 0.9, 1.0),
			"chrome_color_mid": Color(0.1, 0.14, 0.22),
			"chrome_color_highlight2": Color(0.5, 0.6, 0.85),
			"chrome_color_bottom": Color(0.03, 0.05, 0.1),
			"band1_pos": 0.18, "band2_pos": 0.4, "band3_pos": 0.6, "band4_pos": 0.85,
			"band_sharpness": 14.0,
			"line_density": 80.0, "line_strength": 0.15,
			"bevel_strength": 0.8, "bevel_size": 1.5,
			"shadow_offset_x": 2.0, "shadow_offset_y": 3.0, "shadow_softness": 2.5,
			"shadow_color": Color(0.0, 0.02, 0.08, 0.85),
			"gleam_enabled": 1.0, "gleam_speed": 0.7, "gleam_width": 0.08, "gleam_intensity": 1.6,
			"hdr_boost": 1.25,
		}
	})

	# ── RAZOR EDGE ───────────────────────────────────────────────────
	# Ultra-sharp bands, narrow highlights, max contrast, fast gleam
	_presets.append({
		"name": "RAZOR EDGE — Orbitron",
		"font": "res://assets/fonts/Orbitron.ttf",
		"size": 72,
		"color": Color(0.6, 0.7, 1.0),
		"params": {
			"chrome_color_top": Color(0.02, 0.03, 0.08),
			"chrome_color_highlight1": Color(1.0, 1.0, 1.0),
			"chrome_color_mid": Color(0.04, 0.06, 0.12),
			"chrome_color_highlight2": Color(0.7, 0.78, 1.0),
			"chrome_color_bottom": Color(0.01, 0.02, 0.05),
			"band1_pos": 0.25, "band2_pos": 0.35, "band3_pos": 0.65, "band4_pos": 0.75,
			"band_sharpness": 30.0,
			"line_density": 120.0, "line_strength": 0.08,
			"bevel_strength": 1.2, "bevel_size": 1.5,
			"bevel_light_color": Color(0.8, 0.9, 1.0),
			"shadow_offset_x": 2.0, "shadow_offset_y": 3.0, "shadow_softness": 2.0,
			"shadow_color": Color(0.0, 0.0, 0.1, 0.9),
			"gleam_enabled": 1.0, "gleam_speed": 1.2, "gleam_width": 0.05, "gleam_intensity": 2.5,
			"hdr_boost": 1.4,
		}
	})

	# ── RAZOR EDGE — Bungee variant ──────────────────────────────────
	_presets.append({
		"name": "RAZOR EDGE — Bungee",
		"font": "res://assets/fonts/Bungee-Regular.ttf",
		"size": 76,
		"color": Color(0.6, 0.7, 1.0),
		"params": {
			"chrome_color_top": Color(0.02, 0.03, 0.08),
			"chrome_color_highlight1": Color(1.0, 1.0, 1.0),
			"chrome_color_mid": Color(0.04, 0.06, 0.12),
			"chrome_color_highlight2": Color(0.7, 0.78, 1.0),
			"chrome_color_bottom": Color(0.01, 0.02, 0.05),
			"band1_pos": 0.25, "band2_pos": 0.35, "band3_pos": 0.65, "band4_pos": 0.75,
			"band_sharpness": 30.0,
			"line_density": 110.0, "line_strength": 0.1,
			"bevel_strength": 1.3, "bevel_size": 2.0,
			"bevel_light_color": Color(0.8, 0.9, 1.0),
			"shadow_offset_x": 3.0, "shadow_offset_y": 4.0, "shadow_softness": 2.5,
			"shadow_color": Color(0.0, 0.0, 0.1, 0.9),
			"gleam_enabled": 1.0, "gleam_speed": 1.0, "gleam_width": 0.06, "gleam_intensity": 2.2,
			"hdr_boost": 1.4,
		}
	})

	# ── STAMPED PLATE ────────────────────────────────────────────────
	# Heavy bevel, muted chrome, industrial feel, no gleam — raw stamped metal
	_presets.append({
		"name": "STAMPED PLATE — RussoOne",
		"font": "res://assets/fonts/RussoOne-Regular.ttf",
		"size": 76,
		"color": Color(0.65, 0.7, 0.78),
		"params": {
			"chrome_color_top": Color(0.12, 0.13, 0.16),
			"chrome_color_highlight1": Color(0.6, 0.63, 0.7),
			"chrome_color_mid": Color(0.2, 0.22, 0.26),
			"chrome_color_highlight2": Color(0.5, 0.52, 0.58),
			"chrome_color_bottom": Color(0.08, 0.09, 0.12),
			"band1_pos": 0.15, "band2_pos": 0.4, "band3_pos": 0.6, "band4_pos": 0.85,
			"band_sharpness": 8.0,
			"line_density": 60.0, "line_strength": 0.2,
			"bevel_strength": 1.8, "bevel_size": 2.5,
			"bevel_light_color": Color(0.9, 0.92, 0.95),
			"bevel_shadow_color": Color(0.0, 0.0, 0.02),
			"shadow_offset_x": 3.0, "shadow_offset_y": 4.0, "shadow_softness": 4.0,
			"shadow_color": Color(0.0, 0.0, 0.05, 0.9),
			"gleam_enabled": 0.0,
			"hdr_boost": 1.1,
		}
	})

	# ── STAMPED PLATE — Bungee variant ───────────────────────────────
	_presets.append({
		"name": "STAMPED PLATE — Bungee",
		"font": "res://assets/fonts/Bungee-Regular.ttf",
		"size": 76,
		"color": Color(0.65, 0.7, 0.78),
		"params": {
			"chrome_color_top": Color(0.12, 0.13, 0.16),
			"chrome_color_highlight1": Color(0.6, 0.63, 0.7),
			"chrome_color_mid": Color(0.2, 0.22, 0.26),
			"chrome_color_highlight2": Color(0.5, 0.52, 0.58),
			"chrome_color_bottom": Color(0.08, 0.09, 0.12),
			"band1_pos": 0.15, "band2_pos": 0.4, "band3_pos": 0.6, "band4_pos": 0.85,
			"band_sharpness": 8.0,
			"line_density": 50.0, "line_strength": 0.22,
			"bevel_strength": 2.0, "bevel_size": 2.5,
			"bevel_light_color": Color(0.9, 0.92, 0.95),
			"bevel_shadow_color": Color(0.0, 0.0, 0.02),
			"shadow_offset_x": 3.5, "shadow_offset_y": 4.5, "shadow_softness": 4.0,
			"shadow_color": Color(0.0, 0.0, 0.05, 0.9),
			"gleam_enabled": 0.0,
			"hdr_boost": 1.1,
		}
	})

	# ── MIDNIGHT ICE ─────────────────────────────────────────────────
	# Deep dark blue chrome, very dark base, icy highlights, slow dramatic gleam
	_presets.append({
		"name": "MIDNIGHT ICE — Orbitron",
		"font": "res://assets/fonts/Orbitron.ttf",
		"size": 72,
		"color": Color(0.4, 0.65, 1.0),
		"params": {
			"chrome_color_top": Color(0.01, 0.03, 0.1),
			"chrome_color_highlight1": Color(0.5, 0.75, 1.0),
			"chrome_color_mid": Color(0.03, 0.06, 0.15),
			"chrome_color_highlight2": Color(0.35, 0.55, 0.85),
			"chrome_color_bottom": Color(0.01, 0.02, 0.06),
			"band1_pos": 0.2, "band2_pos": 0.45, "band3_pos": 0.55, "band4_pos": 0.8,
			"band_sharpness": 20.0,
			"line_density": 70.0, "line_strength": 0.18,
			"bevel_strength": 0.7, "bevel_size": 1.5,
			"bevel_light_color": Color(0.5, 0.7, 1.0),
			"shadow_offset_x": 2.0, "shadow_offset_y": 3.0, "shadow_softness": 3.0,
			"shadow_color": Color(0.0, 0.0, 0.15, 0.85),
			"gleam_enabled": 1.0, "gleam_speed": 0.4, "gleam_width": 0.1, "gleam_intensity": 2.0,
			"hdr_boost": 1.5,
		}
	})

	# ── MIDNIGHT ICE — Audiowide variant ─────────────────────────────
	_presets.append({
		"name": "MIDNIGHT ICE — Audiowide",
		"font": "res://assets/fonts/Audiowide-Regular.ttf",
		"size": 72,
		"color": Color(0.4, 0.65, 1.0),
		"params": {
			"chrome_color_top": Color(0.01, 0.03, 0.1),
			"chrome_color_highlight1": Color(0.5, 0.75, 1.0),
			"chrome_color_mid": Color(0.03, 0.06, 0.15),
			"chrome_color_highlight2": Color(0.35, 0.55, 0.85),
			"chrome_color_bottom": Color(0.01, 0.02, 0.06),
			"band1_pos": 0.22, "band2_pos": 0.45, "band3_pos": 0.55, "band4_pos": 0.78,
			"band_sharpness": 20.0,
			"line_density": 75.0, "line_strength": 0.16,
			"bevel_strength": 0.6, "bevel_size": 1.5,
			"bevel_light_color": Color(0.5, 0.7, 1.0),
			"shadow_offset_x": 2.0, "shadow_offset_y": 3.0, "shadow_softness": 2.5,
			"shadow_color": Color(0.0, 0.0, 0.15, 0.85),
			"gleam_enabled": 1.0, "gleam_speed": 0.4, "gleam_width": 0.1, "gleam_intensity": 1.8,
			"hdr_boost": 1.5,
		}
	})

	# ── FURNACE ──────────────────────────────────────────────────────
	# Hot white highlights, cold blue shadows — extreme thermal contrast
	_presets.append({
		"name": "FURNACE — Bungee",
		"font": "res://assets/fonts/Bungee-Regular.ttf",
		"size": 76,
		"color": Color(0.8, 0.85, 1.0),
		"params": {
			"chrome_color_top": Color(0.03, 0.04, 0.1),
			"chrome_color_highlight1": Color(1.0, 0.98, 0.95),
			"chrome_color_mid": Color(0.06, 0.08, 0.18),
			"chrome_color_highlight2": Color(0.9, 0.92, 1.0),
			"chrome_color_bottom": Color(0.02, 0.03, 0.08),
			"band1_pos": 0.22, "band2_pos": 0.38, "band3_pos": 0.62, "band4_pos": 0.78,
			"band_sharpness": 25.0,
			"line_density": 100.0, "line_strength": 0.06,
			"bevel_strength": 1.0, "bevel_size": 1.8,
			"shadow_offset_x": 2.5, "shadow_offset_y": 3.5, "shadow_softness": 2.0,
			"shadow_color": Color(0.0, 0.0, 0.1, 0.9),
			"gleam_enabled": 1.0, "gleam_speed": 0.8, "gleam_width": 0.04, "gleam_intensity": 2.5,
			"hdr_boost": 1.6,
		}
	})

	# ── FURNACE — Orbitron variant ───────────────────────────────────
	_presets.append({
		"name": "FURNACE — Orbitron",
		"font": "res://assets/fonts/Orbitron.ttf",
		"size": 72,
		"color": Color(0.8, 0.85, 1.0),
		"params": {
			"chrome_color_top": Color(0.03, 0.04, 0.1),
			"chrome_color_highlight1": Color(1.0, 0.98, 0.95),
			"chrome_color_mid": Color(0.06, 0.08, 0.18),
			"chrome_color_highlight2": Color(0.9, 0.92, 1.0),
			"chrome_color_bottom": Color(0.02, 0.03, 0.08),
			"band1_pos": 0.2, "band2_pos": 0.36, "band3_pos": 0.64, "band4_pos": 0.8,
			"band_sharpness": 22.0,
			"line_density": 90.0, "line_strength": 0.08,
			"bevel_strength": 0.9, "bevel_size": 1.5,
			"shadow_offset_x": 2.0, "shadow_offset_y": 3.0, "shadow_softness": 2.0,
			"shadow_color": Color(0.0, 0.0, 0.1, 0.9),
			"gleam_enabled": 1.0, "gleam_speed": 0.9, "gleam_width": 0.05, "gleam_intensity": 2.2,
			"hdr_boost": 1.5,
		}
	})

	# ── GUNMETAL ─────────────────────────────────────────────────────
	# Dark, desaturated, heavy — like brushed gun barrel
	_presets.append({
		"name": "GUNMETAL — RussoOne",
		"font": "res://assets/fonts/RussoOne-Regular.ttf",
		"size": 76,
		"color": Color(0.55, 0.58, 0.65),
		"params": {
			"chrome_color_top": Color(0.06, 0.07, 0.09),
			"chrome_color_highlight1": Color(0.45, 0.48, 0.55),
			"chrome_color_mid": Color(0.12, 0.13, 0.16),
			"chrome_color_highlight2": Color(0.35, 0.38, 0.44),
			"chrome_color_bottom": Color(0.04, 0.05, 0.07),
			"band1_pos": 0.18, "band2_pos": 0.42, "band3_pos": 0.58, "band4_pos": 0.82,
			"band_sharpness": 10.0,
			"line_density": 140.0, "line_strength": 0.2,
			"bevel_strength": 1.5, "bevel_size": 2.0,
			"bevel_light_color": Color(0.6, 0.62, 0.68),
			"shadow_offset_x": 3.0, "shadow_offset_y": 4.0, "shadow_softness": 3.5,
			"shadow_color": Color(0.0, 0.0, 0.03, 0.9),
			"gleam_enabled": 1.0, "gleam_speed": 0.3, "gleam_width": 0.12, "gleam_intensity": 1.2,
			"hdr_boost": 1.1,
		}
	})

	# ── NEON CHROME ──────────────────────────────────────────────────
	# Chrome base with neon-blue highlights bleeding through — cyberpunk edge
	_presets.append({
		"name": "NEON CHROME — Orbitron",
		"font": "res://assets/fonts/Orbitron.ttf",
		"size": 72,
		"color": Color(0.3, 0.6, 1.0),
		"params": {
			"chrome_color_top": Color(0.02, 0.04, 0.12),
			"chrome_color_highlight1": Color(0.3, 0.7, 1.0),
			"chrome_color_mid": Color(0.08, 0.1, 0.2),
			"chrome_color_highlight2": Color(0.2, 0.5, 0.9),
			"chrome_color_bottom": Color(0.01, 0.02, 0.08),
			"band1_pos": 0.22, "band2_pos": 0.4, "band3_pos": 0.6, "band4_pos": 0.78,
			"band_sharpness": 18.0,
			"line_density": 60.0, "line_strength": 0.1,
			"bevel_strength": 0.6, "bevel_size": 1.5,
			"bevel_light_color": Color(0.3, 0.6, 1.0),
			"shadow_offset_x": 2.0, "shadow_offset_y": 3.0, "shadow_softness": 3.0,
			"shadow_color": Color(0.0, 0.05, 0.2, 0.8),
			"gleam_enabled": 1.0, "gleam_speed": 0.7, "gleam_width": 0.06, "gleam_intensity": 2.0,
			"hdr_boost": 1.8,
		}
	})

	# ── MIRROR FINISH ────────────────────────────────────────────────
	# Very tight highlight, almost all dark except one blinding band, no lines
	_presets.append({
		"name": "MIRROR FINISH — Audiowide",
		"font": "res://assets/fonts/Audiowide-Regular.ttf",
		"size": 72,
		"color": Color(0.75, 0.82, 1.0),
		"params": {
			"chrome_color_top": Color(0.02, 0.03, 0.06),
			"chrome_color_highlight1": Color(1.0, 1.0, 1.0),
			"chrome_color_mid": Color(0.03, 0.04, 0.08),
			"chrome_color_highlight2": Color(0.4, 0.5, 0.7),
			"chrome_color_bottom": Color(0.01, 0.02, 0.04),
			"band1_pos": 0.3, "band2_pos": 0.38, "band3_pos": 0.7, "band4_pos": 0.78,
			"band_sharpness": 35.0,
			"line_density": 0.0, "line_strength": 0.0,
			"bevel_strength": 0.5, "bevel_size": 1.2,
			"shadow_offset_x": 2.0, "shadow_offset_y": 3.0, "shadow_softness": 2.0,
			"shadow_color": Color(0.0, 0.0, 0.08, 0.85),
			"gleam_enabled": 1.0, "gleam_speed": 0.5, "gleam_width": 0.03, "gleam_intensity": 3.0,
			"hdr_boost": 1.5,
		}
	})

	# ── MIRROR FINISH — Bungee variant ───────────────────────────────
	_presets.append({
		"name": "MIRROR FINISH — Bungee",
		"font": "res://assets/fonts/Bungee-Regular.ttf",
		"size": 76,
		"color": Color(0.75, 0.82, 1.0),
		"params": {
			"chrome_color_top": Color(0.02, 0.03, 0.06),
			"chrome_color_highlight1": Color(1.0, 1.0, 1.0),
			"chrome_color_mid": Color(0.03, 0.04, 0.08),
			"chrome_color_highlight2": Color(0.4, 0.5, 0.7),
			"chrome_color_bottom": Color(0.01, 0.02, 0.04),
			"band1_pos": 0.3, "band2_pos": 0.38, "band3_pos": 0.7, "band4_pos": 0.78,
			"band_sharpness": 35.0,
			"line_density": 0.0, "line_strength": 0.0,
			"bevel_strength": 0.7, "bevel_size": 1.5,
			"shadow_offset_x": 2.5, "shadow_offset_y": 3.5, "shadow_softness": 2.5,
			"shadow_color": Color(0.0, 0.0, 0.08, 0.85),
			"gleam_enabled": 1.0, "gleam_speed": 0.5, "gleam_width": 0.04, "gleam_intensity": 2.8,
			"hdr_boost": 1.5,
		}
	})

	# ── NO GLEAM variants ────────────────────────────────────────────
	# Same chrome quality but static — for users who don't want animation

	_presets.append({
		"name": "STATIC CHROME — Orbitron (no gleam)",
		"font": "res://assets/fonts/Orbitron.ttf",
		"size": 72,
		"color": Color(0.7, 0.8, 1.0),
		"params": {
			"chrome_color_top": Color(0.05, 0.08, 0.15),
			"chrome_color_highlight1": Color(0.85, 0.9, 1.0),
			"chrome_color_mid": Color(0.1, 0.14, 0.22),
			"chrome_color_highlight2": Color(0.6, 0.68, 0.92),
			"chrome_color_bottom": Color(0.03, 0.05, 0.1),
			"band1_pos": 0.2, "band2_pos": 0.42, "band3_pos": 0.58, "band4_pos": 0.82,
			"band_sharpness": 16.0,
			"line_density": 85.0, "line_strength": 0.14,
			"bevel_strength": 1.0, "bevel_size": 1.8,
			"shadow_offset_x": 2.5, "shadow_offset_y": 3.5, "shadow_softness": 3.0,
			"shadow_color": Color(0.0, 0.02, 0.08, 0.85),
			"gleam_enabled": 0.0,
			"hdr_boost": 1.3,
		}
	})

	_presets.append({
		"name": "STATIC CHROME — Bungee (no gleam)",
		"font": "res://assets/fonts/Bungee-Regular.ttf",
		"size": 76,
		"color": Color(0.7, 0.8, 1.0),
		"params": {
			"chrome_color_top": Color(0.05, 0.08, 0.15),
			"chrome_color_highlight1": Color(0.85, 0.9, 1.0),
			"chrome_color_mid": Color(0.1, 0.14, 0.22),
			"chrome_color_highlight2": Color(0.6, 0.68, 0.92),
			"chrome_color_bottom": Color(0.03, 0.05, 0.1),
			"band1_pos": 0.22, "band2_pos": 0.44, "band3_pos": 0.56, "band4_pos": 0.8,
			"band_sharpness": 18.0,
			"line_density": 95.0, "line_strength": 0.12,
			"bevel_strength": 1.1, "bevel_size": 2.0,
			"shadow_offset_x": 3.0, "shadow_offset_y": 4.0, "shadow_softness": 3.5,
			"shadow_color": Color(0.0, 0.02, 0.08, 0.88),
			"gleam_enabled": 0.0,
			"hdr_boost": 1.3,
		}
	})


func _build_ui() -> void:
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 8)
	add_child(main)

	var header := Label.new()
	header.text = "TITLE STYLES"
	ThemeManager.apply_text_glow(header, "header")
	main.add_child(header)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(_scroll)

	_grid = VBoxContainer.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("separation", 24)
	_scroll.add_child(_grid)

	for i in _presets.size():
		_build_preset_cell(_presets[i])


func _build_preset_cell(preset: Dictionary) -> void:
	var cell := VBoxContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_theme_constant_override("separation", 4)
	_grid.add_child(cell)

	# Preset name label
	var name_label := Label.new()
	name_label.text = str(preset["name"])
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(0.45, 0.5, 0.6))
	cell.add_child(name_label)

	# SubViewport for rendering the title with shader
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(VP_W, VP_H)
	svc.size = Vector2(VP_W, VP_H)
	svc.stretch = true
	cell.add_child(svc)

	var svp := SubViewport.new()
	svp.size = Vector2i(VP_W, VP_H)
	svp.transparent_bg = false
	svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(svp)

	# Dark background inside viewport
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	svp.add_child(bg)

	# Title label
	var title := Label.new()
	title.text = TITLE_TEXT
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_FULL_RECT)

	var font_path: String = str(preset["font"])
	var font_res: Font = load(font_path)
	if font_res:
		title.add_theme_font_override("font", font_res)
	var font_size: int = int(preset["size"])
	title.add_theme_font_size_override("font_size", font_size)

	var color: Color = preset["color"] as Color
	title.add_theme_color_override("font_color", color)

	# Apply title chrome shader
	var shader: Shader = load(SHADER_PATH)
	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		var params: Dictionary = preset.get("params", {}) as Dictionary
		for key in params:
			mat.set_shader_parameter(key, params[key])
		title.material = mat

	svp.add_child(title)

	# Add bloom to the viewport
	VFXFactory.add_bloom_to_viewport(svp)

	# Thin separator line
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 1)
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(0.12, 0.15, 0.22, 0.4)
	sep_style.set_content_margin_all(0)
	sep.add_theme_stylebox_override("separator", sep_style)
	cell.add_child(sep)
