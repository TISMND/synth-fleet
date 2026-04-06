shader_type canvas_item;
// Monolith Surface — Player flies along the face of a massive white hull.
// THX 1138 / Apple Store: predominantly white panels, thin dark recessed
// seams, clinical and sterile. Two-tier grid: macro sections (raised/sunken
// zones) containing smaller brick panels. Flush-mounted light fixtures with
// metal bezels bloom when an invisible HDR pulse wave sweeps across.

// Panel surface
uniform vec4 panel_bright : source_color = vec4(0.82, 0.84, 0.88, 1.0);
uniform vec4 panel_dim : source_color = vec4(0.72, 0.74, 0.78, 1.0);
uniform vec4 seam_dark : source_color = vec4(0.22, 0.24, 0.28, 1.0);
uniform vec4 vent_color : source_color = vec4(0.12, 0.13, 0.16, 1.0);

// Accent lighting
uniform vec4 warm_tint : source_color = vec4(1.0, 0.92, 0.78, 1.0);
uniform vec4 light_color : source_color = vec4(1.0, 0.98, 0.95, 1.0);

// scroll_speed is for audition preview only; game uses manual_scroll + scroll_offset
uniform float scroll_speed : hint_range(0.0, 200.0) = 45.0;
uniform bool manual_scroll = false;
uniform float scroll_offset : hint_range(0.0, 100000.0) = 0.0;
uniform float grid_spacing_x : hint_range(40.0, 250.0) = 110.0;
uniform float grid_spacing_y : hint_range(20.0, 140.0) = 62.0;
uniform float seam_width : hint_range(0.5, 4.0) = 2.0;
uniform float seam_depth : hint_range(0.0, 1.0) = 0.76;

// Macro grid (large sections containing small panels)
uniform float macro_cells_x : hint_range(2.0, 8.0) = 4.0;
uniform float macro_cells_y : hint_range(2.0, 8.0) = 4.0;
uniform float macro_seam_width : hint_range(1.0, 8.0) = 3.5;
uniform float macro_depth : hint_range(0.0, 1.0) = 0.44;

// Sub-panel detail
uniform float sub_panel_density : hint_range(0.0, 1.0) = 0.96;
uniform float vent_density : hint_range(0.0, 0.5) = 0.14;
uniform float marking_density : hint_range(0.0, 0.5) = 0.22;

// Flush-mounted light fixtures
uniform float light_density : hint_range(0.0, 0.6) = 0.22;
uniform float light_hdr : hint_range(1.0, 12.0) = 5.3;
uniform float light_rim_width : hint_range(0.5, 4.0) = 1.9;
uniform float light_ambient : hint_range(0.0, 1.0) = 0.5;
uniform float light_bezel : hint_range(0.0, 3.0) = 0.7;

// HDR pulse wave (only affects light fixtures, invisible on hull)
uniform float pulse_intensity : hint_range(0.0, 1.0) = 0.38;
uniform float pulse_hdr : hint_range(1.0, 20.0) = 9.2;
uniform float pulse_speed : hint_range(0.0, 5.0) = 1.3;
uniform float pulse_scale : hint_range(0.1, 8.0) = 7.1;
uniform float pulse_threshold : hint_range(0.0, 1.0) = 0.22;
uniform float pulse_softness : hint_range(0.01, 1.0) = 1.0;
uniform float pulse_wobble : hint_range(0.0, 3.0) = 3.0;

// Subtle surface imperfection
uniform float weathering : hint_range(0.0, 1.0) = 1.0;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
	           mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	float modulate_alpha = COLOR.a;
	vec2 px = FRAGCOORD.xy;
	float effective_scroll = manual_scroll ? scroll_offset : TIME * scroll_speed;
	vec2 scrolled = px + vec2(0.0, effective_scroll);

	// ══════════════════════════════════════════════
	// MACRO GRID — large sections, aligned to small grid
	// Each macro cell spans macro_cells_x * macro_cells_y small panels.
	// Some sections are raised (brighter), some sunken (darker).
	// ══════════════════════════════════════════════
	float macro_sx = grid_spacing_x * macro_cells_x;
	float macro_sy = grid_spacing_y * macro_cells_y;
	float macro_row = floor(scrolled.y / macro_sy);
	float macro_col = floor(scrolled.x / macro_sx);
	vec2 macro_id = vec2(macro_col, macro_row);
	float macro_fx = fract(scrolled.x / macro_sx);
	float macro_fy = fract(scrolled.y / macro_sy);

	// Macro seam distance
	float macro_dx = min(macro_fx, 1.0 - macro_fx) * macro_sx;
	float macro_dy = min(macro_fy, 1.0 - macro_fy) * macro_sy;
	float macro_seam_dist = min(macro_dx, macro_dy);

	// Per-section raised/sunken variation
	float macro_hash = hash(macro_id + 101.0);
	float macro_shade = mix(0.88, 1.05, macro_hash); // sunken=darker, raised=brighter

	// ══════════════════════════════════════════════
	// SMALL PANEL GRID — offset brick pattern within macro sections
	// ══════════════════════════════════════════════
	float row_idx = floor(scrolled.y / grid_spacing_y);
	float row_offset = mod(row_idx, 2.0) * grid_spacing_x * 0.5;
	float row_jitter = (hash(vec2(row_idx, 0.0)) - 0.5) * grid_spacing_x * 0.08;
	float col_adj_x = scrolled.x + row_offset + row_jitter;
	float col_idx = floor(col_adj_x / grid_spacing_x);
	vec2 cell_id = vec2(col_idx, row_idx);

	float fx = fract(col_adj_x / grid_spacing_x);
	float fy = fract(scrolled.y / grid_spacing_y);

	// ── Small seam distance ──
	float dx_seam = min(fx, 1.0 - fx) * grid_spacing_x;
	float dy_seam = min(fy, 1.0 - fy) * grid_spacing_y;
	float seam_dist = min(dx_seam, dy_seam);

	float seam_core = smoothstep(seam_width * 1.3, seam_width * 0.3, seam_dist);
	float bevel = smoothstep(seam_width * 3.0, seam_width * 1.3, seam_dist);

	// ── Base panel color ──
	float cell_hash = hash(cell_id);
	float shade_t = cell_hash * 0.6 + 0.4;
	vec3 panel_base = mix(panel_dim.rgb, panel_bright.rgb, shade_t);

	// Apply macro section shading (raised/sunken)
	panel_base *= macro_shade;

	// Bevel shadow near small seams
	panel_base *= mix(1.0, 0.92, bevel);

	// Small seam fill
	vec3 col = mix(panel_base, seam_dark.rgb, seam_core * seam_depth);

	// ── Macro seam (deeper, wider groove over small grid) ──
	float macro_seam_core = smoothstep(macro_seam_width * 1.4, macro_seam_width * 0.3, macro_seam_dist);
	float macro_bevel = smoothstep(macro_seam_width * 4.0, macro_seam_width * 1.5, macro_seam_dist);
	// Darken for macro seams on top of whatever small-grid produced
	col = mix(col, seam_dark.rgb * 0.7, macro_seam_core * macro_depth);
	// Bevel shadow along macro edges
	col *= mix(1.0, 0.88, macro_bevel * macro_depth * 0.5);

	float inside = smoothstep(seam_width * 1.5, seam_width * 3.5, seam_dist);
	// Also suppress detail near macro seams
	float inside_macro = smoothstep(macro_seam_width * 1.5, macro_seam_width * 4.0, macro_seam_dist);
	float detail_mask = inside * inside_macro;

	// ══════════════════════════════════════════════
	// SUB-PANEL DETAIL — secondary seam dividing some panels
	// ══════════════════════════════════════════════
	float sub_hash = hash(cell_id + 11.0);
	if (sub_hash < sub_panel_density) {
		float split_type = hash(cell_id + 17.0);
		float sub_seam;
		if (split_type > 0.5) {
			float split_y = 0.35 + hash(cell_id + 23.0) * 0.3;
			sub_seam = smoothstep(0.8, 0.0, abs(fy - split_y) * grid_spacing_y);
		} else {
			float split_x = 0.35 + hash(cell_id + 29.0) * 0.3;
			sub_seam = smoothstep(0.8, 0.0, abs(fx - split_x) * grid_spacing_x);
		}
		col = mix(col, seam_dark.rgb, sub_seam * seam_depth * 0.7 * detail_mask);
	}

	// ══════════════════════════════════════════════
	// RECESSED VENTS — dark thin slots in some panels
	// ══════════════════════════════════════════════
	float vent_hash = hash(cell_id + 37.0);
	if (vent_hash < vent_density) {
		float vent_y = 0.4 + hash(cell_id + 41.0) * 0.2;
		float vent_h = 0.03 + hash(cell_id + 43.0) * 0.04;
		float vent_x_start = 0.15 + hash(cell_id + 45.0) * 0.15;
		float vent_x_end = 0.7 + hash(cell_id + 47.0) * 0.15;
		float in_vent_y = smoothstep(vent_h, vent_h * 0.3, abs(fy - vent_y));
		float in_vent_x = step(vent_x_start, fx) * step(fx, vent_x_end);
		float vent = in_vent_y * in_vent_x * detail_mask;
		col = mix(col, vent_color.rgb, vent * 0.85);
		float vent_flick = 0.3 + 0.7 * (0.5 + 0.5 * sin(TIME * 0.8 + cell_hash * 10.0));
		col += warm_tint.rgb * vent * 0.04 * vent_flick;
	}

	// ══════════════════════════════════════════════
	// ACCESS PORTS — small circular recesses
	// ══════════════════════════════════════════════
	float port_hash = hash(cell_id + 51.0);
	if (port_hash > 0.82) {
		vec2 port_center = vec2(
			0.2 + hash(cell_id + 53.0) * 0.6,
			0.2 + hash(cell_id + 55.0) * 0.6
		);
		float port_r_px = 2.5 + hash(cell_id + 57.0) * 2.0;
		float port_dist = length(vec2((fx - port_center.x) * grid_spacing_x,
		                              (fy - port_center.y) * grid_spacing_y));
		float port = smoothstep(port_r_px + 0.5, port_r_px - 0.5, port_dist) * detail_mask;
		col = mix(col, seam_dark.rgb, port * seam_depth * 0.8);
		float port_rim = smoothstep(port_r_px + 1.5, port_r_px + 0.5, port_dist)
		               - smoothstep(port_r_px + 0.5, port_r_px - 0.5, port_dist);
		port_rim = max(port_rim, 0.0);
		col += panel_bright.rgb * port_rim * 0.15 * detail_mask;
	}

	// ══════════════════════════════════════════════
	// ALIGNMENT MARKS — tiny engraved cross marks
	// ══════════════════════════════════════════════
	float mark_hash = hash(cell_id + 61.0);
	if (mark_hash < marking_density) {
		float corner_pick = hash(cell_id + 63.0);
		vec2 mark_origin;
		if (corner_pick < 0.25) mark_origin = vec2(0.12, 0.12);
		else if (corner_pick < 0.5) mark_origin = vec2(0.88, 0.12);
		else if (corner_pick < 0.75) mark_origin = vec2(0.12, 0.88);
		else mark_origin = vec2(0.88, 0.88);
		float dx_m = abs(fx - mark_origin.x) * grid_spacing_x;
		float dy_m = abs(fy - mark_origin.y) * grid_spacing_y;
		float arm_len = 4.0;
		float h_line = step(dy_m, 0.4) * step(dx_m, arm_len);
		float v_line = step(dx_m, 0.4) * step(dy_m, arm_len);
		float cross = max(h_line, v_line) * detail_mask;
		col = mix(col, col * 0.88, cross);
	}

	// ══════════════════════════════════════════════
	// ENGRAVED DOT ROWS — tiny rivet dots
	// ══════════════════════════════════════════════
	float dot_hash = hash(cell_id + 71.0);
	if (dot_hash > 0.75 && dot_hash < 0.85) {
		float dot_y = 0.85;
		float dy_dot = abs(fy - dot_y) * grid_spacing_y;
		int dot_count = 3 + int(hash(cell_id + 73.0) * 3.0);
		for (int dd = 0; dd < 5; dd++) {
			if (dd >= dot_count) break;
			float dot_x = 0.2 + float(dd) * 0.15;
			float dx_dot = abs(fx - dot_x) * grid_spacing_x;
			float dot_dist = length(vec2(dx_dot, dy_dot));
			float dot = smoothstep(1.5, 0.5, dot_dist) * detail_mask;
			col = mix(col, col * 0.85, dot);
		}
	}

	// ══════════════════════════════════════════════
	// FLUSH-MOUNTED LIGHT FIXTURES with metal bezel frames
	// ══════════════════════════════════════════════
	float light_val = 0.0;
	float fixture_hash = hash(cell_id + 81.0);
	if (fixture_hash < light_density) {
		float shape_pick = hash(cell_id + 83.0);
		vec2 fix_center = vec2(
			0.3 + hash(cell_id + 85.0) * 0.4,
			0.3 + hash(cell_id + 87.0) * 0.4
		);
		vec2 fix_px = vec2((fx - fix_center.x) * grid_spacing_x,
		                   (fy - fix_center.y) * grid_spacing_y);

		float fix_dist;
		if (shape_pick < 0.4) {
			float radius = 3.5 + hash(cell_id + 89.0) * 4.0;
			fix_dist = length(fix_px) - radius;
		} else if (shape_pick < 0.7) {
			float half_s = 3.0 + hash(cell_id + 89.0) * 3.5;
			vec2 q = abs(fix_px) - vec2(half_s);
			fix_dist = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
		} else {
			float hw = 5.0 + hash(cell_id + 89.0) * 5.0;
			float hh = 2.0 + hash(cell_id + 91.0) * 2.0;
			vec2 q = abs(fix_px) - vec2(hw, hh);
			fix_dist = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
		}

		// ── Metal bezel frame (dark border around the light) ──
		// The bezel sits at fix_dist ≈ 0 (the boundary between light and panel)
		float bezel_outer = smoothstep(light_bezel * 1.5, light_bezel * 0.3, fix_dist);
		float bezel_inner = smoothstep(-light_bezel * 0.3, -light_bezel * 1.0, fix_dist);
		float bezel_ring = bezel_outer * bezel_inner;
		// Dark metal frame
		col = mix(col, seam_dark.rgb * 0.8, bezel_ring * 0.9 * detail_mask);
		// Highlight catch on outer lip of bezel
		float bezel_highlight = smoothstep(light_bezel * 2.0, light_bezel * 1.2, fix_dist)
		                      - smoothstep(light_bezel * 1.2, light_bezel * 0.6, fix_dist);
		bezel_highlight = max(bezel_highlight, 0.0);
		col += panel_bright.rgb * bezel_highlight * 0.12 * detail_mask;

		// ── Light emitting surface (inside the bezel) ──
		// Raised rim glow at the inner edge
		float rim = exp(-fix_dist * fix_dist / (light_rim_width * light_rim_width));
		// Bright fill
		float fill = smoothstep(0.5, -2.0, fix_dist);

		light_val = (fill * 0.85 + rim * 0.5) * detail_mask;
		col += light_color.rgb * light_val * light_ambient;
	}

	// ══════════════════════════════════════════════
	// HDR PULSE WAVE — invisible sweep that blooms lights
	// ══════════════════════════════════════════════
	float pulse_val = 0.0;
	if (pulse_intensity > 0.001) {
		float py = scrolled.y * 0.001 * pulse_scale - TIME * pulse_speed;
		float wobble = vnoise(vec2(py * 2.0 + 3.0, scrolled.x * 0.0008)) * pulse_wobble;
		float wave = vnoise(vec2(py + wobble, scrolled.x * 0.0004));
		pulse_val = smoothstep(pulse_threshold, pulse_threshold + pulse_softness, wave);
		float wave2 = vnoise(vec2(py * 1.7 + 7.0, scrolled.x * 0.0012 + TIME * 0.1));
		pulse_val *= (0.6 + wave2 * 0.8);

		// Light fixtures flare into HDR when pulse passes (hull stays unaffected)
		col += light_color.rgb * light_val * pulse_val * pulse_intensity * pulse_hdr;
	}

	// ══════════════════════════════════════════════
	// SURFACE WEATHERING — subtle grime/variation
	// ══════════════════════════════════════════════
	if (weathering > 0.001) {
		float grime = vnoise(scrolled * 0.005);
		float grime2 = vnoise(scrolled * 0.018 + 300.0);
		float combined = grime * 0.6 + grime2 * 0.4;
		col *= mix(1.0, 0.88 + combined * 0.24, weathering);

		float streak = vnoise(vec2(scrolled.x * 0.0005, scrolled.y * 0.03));
		streak = smoothstep(0.7, 0.9, streak);
		col *= mix(1.0, 0.95, streak * weathering * 0.5);
	}

	COLOR = vec4(col, panel_bright.a * modulate_alpha);
}
