shader_type canvas_item;
// Monolith Surface — Player flies along the face of a massive white hull.
// THX 1138 / Apple Store: predominantly white panels, thin dark recessed
// seams. Some seam segments randomly promoted to "major" (deeper/darker),
// creating irregular zig-zag boundaries through the surface. Unified vents
// with a slider controlling what fraction glow blue. Flush-mounted light
// fixtures with metal bezels. HDR pulse wave only affects lights + active vents.

// Panel surface
uniform vec4 panel_bright : source_color = vec4(0.82, 0.84, 0.88, 1.0);
uniform vec4 panel_dim : source_color = vec4(0.72, 0.74, 0.78, 1.0);
uniform vec4 seam_dark : source_color = vec4(0.22, 0.24, 0.28, 1.0);
uniform vec4 vent_color : source_color = vec4(0.12, 0.13, 0.16, 1.0);

// Accent lighting
uniform vec4 warm_tint : source_color = vec4(1.0, 0.92, 0.78, 1.0);
uniform vec4 light_color : source_color = vec4(1.0, 0.98, 0.95, 1.0);
uniform vec4 active_vent_color : source_color = vec4(0.3, 0.65, 1.0, 1.0);

// scroll_speed is for audition preview only; game uses manual_scroll + scroll_offset
uniform float scroll_speed : hint_range(0.0, 200.0) = 45.0;
uniform bool manual_scroll = false;
uniform float scroll_offset : hint_range(0.0, 100000.0) = 0.0;
uniform float grid_spacing_x : hint_range(40.0, 250.0) = 120.0;
uniform float grid_spacing_y : hint_range(20.0, 140.0) = 66.0;
uniform float seam_width : hint_range(0.5, 4.0) = 2.0;
uniform float seam_depth : hint_range(0.0, 1.0) = 0.76;

// Major seams — randomly promoted small-grid seam segments
uniform float major_seam_chance : hint_range(0.0, 1.0) = 0.24;
uniform float major_seam_extra_width : hint_range(0.0, 6.0) = 2.5;
uniform float major_seam_depth : hint_range(0.0, 1.0) = 0.8;

// Sub-panel detail
uniform float sub_panel_density : hint_range(0.0, 1.0) = 0.96;
uniform float vent_density : hint_range(0.0, 0.5) = 0.04;
uniform float vent_active_ratio : hint_range(0.0, 1.0) = 0.48;
uniform float active_vent_glow : hint_range(0.0, 2.0) = 1.75;
uniform float marking_density : hint_range(0.0, 0.5) = 0.22;

// Flush-mounted light fixtures
uniform float light_density : hint_range(0.0, 0.6) = 0.1;
uniform float light_hdr : hint_range(1.0, 12.0) = 5.3;
uniform float light_rim_width : hint_range(0.5, 4.0) = 1.9;
uniform float light_ambient : hint_range(0.0, 1.0) = 0.48;
uniform float light_bezel : hint_range(0.0, 3.0) = 0.7;

// HDR pulse wave (only affects light fixtures + active vents, invisible on hull)
uniform float pulse_intensity : hint_range(0.0, 1.0) = 0.66;
uniform float pulse_hdr : hint_range(1.0, 20.0) = 10.5;
uniform float pulse_speed : hint_range(0.0, 5.0) = 1.0;
uniform float pulse_scale : hint_range(0.1, 8.0) = 2.2;
uniform float pulse_threshold : hint_range(0.0, 1.0) = 0.12;
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
	float effective_scroll = manual_scroll ? -scroll_offset : -TIME * scroll_speed;
	vec2 scrolled = px + vec2(0.0, effective_scroll);

	// ══════════════════════════════════════════════
	// SMALL PANEL GRID — offset brick pattern
	// ══════════════════════════════════════════════
	float row_idx = floor(scrolled.y / grid_spacing_y);
	float row_offset = mod(row_idx, 2.0) * grid_spacing_x * 0.5;
	float row_jitter = (hash(vec2(row_idx, 0.0)) - 0.5) * grid_spacing_x * 0.08;
	float col_adj_x = scrolled.x + row_offset + row_jitter;
	float col_idx = floor(col_adj_x / grid_spacing_x);
	vec2 cell_id = vec2(col_idx, row_idx);

	float fx = fract(col_adj_x / grid_spacing_x);
	float fy = fract(scrolled.y / grid_spacing_y);

	// ── Seam distances ──
	float dx_seam = min(fx, 1.0 - fx) * grid_spacing_x;
	float dy_seam = min(fy, 1.0 - fy) * grid_spacing_y;
	float seam_dist = min(dx_seam, dy_seam);

	// ══════════════════════════════════════════════
	// MAJOR SEAM PROMOTION — per-segment along existing grid lines
	// Each horizontal seam segment (between row r and r+1, at column c)
	// and each vertical seam segment independently hashed to determine
	// if it's "major". Creates irregular zig-zag dark boundaries.
	// ══════════════════════════════════════════════
	// Which seam boundary are we near?
	// Horizontal: top edge (fy < 0.5 → row boundary = row_idx) or bottom (row_idx + 1)
	float h_boundary_row = (fy < 0.5) ? row_idx : row_idx + 1.0;
	// Vertical: left edge (fx < 0.5 → col boundary = col_idx) or right (col_idx + 1)
	float v_boundary_col = (fx < 0.5) ? col_idx : col_idx + 1.0;

	// Hash per seam segment: h_seam identified by (col_idx, boundary_row)
	float h_seg_hash = hash(vec2(col_idx, h_boundary_row) + 201.0);
	float v_seg_hash = hash(vec2(v_boundary_col, row_idx) + 307.0);

	bool h_is_major = h_seg_hash < major_seam_chance;
	bool v_is_major = v_seg_hash < major_seam_chance;

	// Effective seam width: wider if this segment is major
	float h_eff_width = seam_width + (h_is_major ? major_seam_extra_width : 0.0);
	float v_eff_width = seam_width + (v_is_major ? major_seam_extra_width : 0.0);

	// Effective depth: deeper if major
	float h_eff_depth = h_is_major ? max(seam_depth, major_seam_depth) : seam_depth;
	float v_eff_depth = v_is_major ? max(seam_depth, major_seam_depth) : seam_depth;

	// Compute seam contributions separately for h and v
	float h_seam_core = smoothstep(h_eff_width * 1.3, h_eff_width * 0.3, dy_seam);
	float v_seam_core = smoothstep(v_eff_width * 1.3, v_eff_width * 0.3, dx_seam);

	float bevel_h = smoothstep(h_eff_width * 3.0, h_eff_width * 1.3, dy_seam);
	float bevel_v = smoothstep(v_eff_width * 3.0, v_eff_width * 1.3, dx_seam);

	// ── Base panel color ──
	float cell_hash = hash(cell_id);
	float shade_t = cell_hash * 0.6 + 0.4;
	vec3 panel_base = mix(panel_dim.rgb, panel_bright.rgb, shade_t);

	// Bevel shadow near seams
	float bevel = max(bevel_h, bevel_v);
	panel_base *= mix(1.0, 0.92, bevel);

	// Seam fill — take the stronger of h/v seam at this pixel
	vec3 col = panel_base;
	// Major seams use darker color
	vec3 h_seam_col = h_is_major ? seam_dark.rgb * 0.65 : seam_dark.rgb;
	vec3 v_seam_col = v_is_major ? seam_dark.rgb * 0.65 : seam_dark.rgb;
	col = mix(col, h_seam_col, h_seam_core * h_eff_depth);
	col = mix(col, v_seam_col, v_seam_core * v_eff_depth);

	float inside = smoothstep(seam_width * 1.5, seam_width * 3.5, seam_dist);
	// Suppress detail near major seams too
	float major_near = 0.0;
	if (h_is_major) major_near = max(major_near, smoothstep(h_eff_width * 3.5, h_eff_width * 1.5, dy_seam));
	if (v_is_major) major_near = max(major_near, smoothstep(v_eff_width * 3.5, v_eff_width * 1.5, dx_seam));
	float detail_mask = inside * (1.0 - major_near * 0.7);

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
	// VENTS — unified pool, vent_active_ratio controls how many glow
	// ══════════════════════════════════════════════
	float active_vent_val = 0.0;
	float vent_hash = hash(cell_id + 37.0);
	if (vent_hash < vent_density) {
		float vent_y = 0.4 + hash(cell_id + 41.0) * 0.2;
		float vent_h = 0.03 + hash(cell_id + 43.0) * 0.04;
		float vent_x_start = 0.15 + hash(cell_id + 45.0) * 0.15;
		float vent_x_end = 0.7 + hash(cell_id + 47.0) * 0.15;
		float in_vent_y = smoothstep(vent_h, vent_h * 0.3, abs(fy - vent_y));
		float in_vent_x = step(vent_x_start, fx) * step(fx, vent_x_end);
		float vent = in_vent_y * in_vent_x * detail_mask;

		// Dark slot body (all vents)
		col = mix(col, vent_color.rgb, vent * 0.85);

		// Is this vent active? Hash determines per-vent, ratio sets the threshold
		float active_hash = hash(cell_id + 149.0);
		bool is_active = active_hash < vent_active_ratio;

		if (is_active) {
			// Blue interior glow
			float av_inner = smoothstep(vent_h, 0.0, abs(fy - vent_y));
			active_vent_val = av_inner * in_vent_x * detail_mask;
			float av_flick = 0.8 + 0.2 * sin(TIME * 1.2 + cell_hash * 8.0);
			col += active_vent_color.rgb * active_vent_val * active_vent_glow * av_flick;
		} else {
			// Inactive: subtle warm glow only
			float vent_flick = 0.3 + 0.7 * (0.5 + 0.5 * sin(TIME * 0.8 + cell_hash * 10.0));
			col += warm_tint.rgb * vent * 0.04 * vent_flick;
		}
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
	if (fixture_hash < light_density && vent_hash >= vent_density) {
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

		// ── Metal bezel frame ──
		float bezel_outer = smoothstep(light_bezel * 1.5, light_bezel * 0.3, fix_dist);
		float bezel_inner = smoothstep(-light_bezel * 0.3, -light_bezel * 1.0, fix_dist);
		float bezel_ring = bezel_outer * bezel_inner;
		col = mix(col, seam_dark.rgb * 0.8, bezel_ring * 0.9 * detail_mask);
		float bezel_highlight = smoothstep(light_bezel * 2.0, light_bezel * 1.2, fix_dist)
		                      - smoothstep(light_bezel * 1.2, light_bezel * 0.6, fix_dist);
		bezel_highlight = max(bezel_highlight, 0.0);
		col += panel_bright.rgb * bezel_highlight * 0.12 * detail_mask;

		// ── Light emitting surface ──
		float rim = exp(-fix_dist * fix_dist / (light_rim_width * light_rim_width));
		float fill = smoothstep(0.5, -2.0, fix_dist);
		light_val = (fill * 0.85 + rim * 0.5) * detail_mask;
		col += light_color.rgb * light_val * light_ambient;
	}

	// ══════════════════════════════════════════════
	// HDR PULSE WAVE — invisible sweep that blooms lights + active vents
	// ══════════════════════════════════════════════
	float pulse_val = 0.0;
	if (pulse_intensity > 0.001) {
		float py = scrolled.y * 0.001 * pulse_scale - TIME * pulse_speed;
		float wobble = vnoise(vec2(py * 2.0 + 3.0, scrolled.x * 0.0008)) * pulse_wobble;
		float wave = vnoise(vec2(py + wobble, scrolled.x * 0.0004));
		pulse_val = smoothstep(pulse_threshold, pulse_threshold + pulse_softness, wave);
		float wave2 = vnoise(vec2(py * 1.7 + 7.0, scrolled.x * 0.0012 + TIME * 0.1));
		pulse_val *= (0.6 + wave2 * 0.8);

		// Light fixtures + active vents flare into HDR when pulse passes
		col += light_color.rgb * light_val * pulse_val * pulse_intensity * pulse_hdr;
		col += active_vent_color.rgb * active_vent_val * pulse_val * pulse_intensity * pulse_hdr * 0.6;
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
