shader_type canvas_item;
// Monolith verse scrolling background: clinical white panel grid with
// scanner sweep beams crossing the field. Cool blue/white palette.
// Panel seams form an offset brick-like pattern. Some cells have dim
// interior glow. Scanner beams travel diagonally with HDR cores.
// Occasional flicker/pulse waves wash across the surface.

uniform vec4 seam_color : source_color = vec4(0.35, 0.42, 0.55, 0.9);
uniform vec4 panel_color : source_color = vec4(0.06, 0.07, 0.09, 1.0);
uniform vec4 scan_color : source_color = vec4(0.45, 0.78, 1.0, 1.0);
uniform vec4 window_color : source_color = vec4(0.35, 0.65, 0.95, 0.6);

uniform float scroll_speed : hint_range(0.0, 200.0) = 40.0;
uniform float grid_spacing_x : hint_range(30.0, 200.0) = 80.0;
uniform float grid_spacing_y : hint_range(15.0, 120.0) = 45.0;
uniform float seam_width : hint_range(0.3, 3.0) = 1.1;
uniform float seam_glow : hint_range(0.0, 15.0) = 4.0;
uniform float seam_hdr : hint_range(1.0, 8.0) = 2.5;

// Scanner beams
uniform float scan_count : hint_range(1.0, 8.0) = 4.0;
uniform float scan_speed : hint_range(20.0, 400.0) = 180.0;
uniform float scan_width : hint_range(1.0, 8.0) = 2.5;
uniform float scan_glow_size : hint_range(2.0, 40.0) = 18.0;
uniform float scan_hdr : hint_range(1.0, 12.0) = 5.5;
uniform float scan_angle : hint_range(-1.0, 1.0) = 0.35;

// Window glow
uniform float window_density : hint_range(0.0, 1.0) = 0.2;
uniform float window_hdr : hint_range(0.5, 6.0) = 1.8;

// Pulse overlay
uniform float pulse_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float pulse_hdr : hint_range(1.0, 12.0) = 3.0;
uniform float pulse_speed : hint_range(0.0, 5.0) = 2.5;
uniform float pulse_scale : hint_range(0.1, 8.0) = 1.2;
uniform float pulse_threshold : hint_range(0.0, 1.0) = 0.65;
uniform float pulse_softness : hint_range(0.01, 1.0) = 0.2;

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
	float scroll_offset = TIME * scroll_speed;
	vec2 scrolled = px + vec2(0.0, scroll_offset);

	vec3 col = panel_color.rgb;

	// ══════════════════════════════════════════════
	// PANEL GRID — offset brick pattern with seam lines
	// ══════════════════════════════════════════════
	// Row index determines horizontal offset (brick stagger)
	float row_idx = floor(scrolled.y / grid_spacing_y);
	float row_offset = mod(row_idx, 2.0) * grid_spacing_x * 0.5;
	float col_adj_x = scrolled.x + row_offset;
	float col_idx = floor(col_adj_x / grid_spacing_x);
	vec2 cell_id = vec2(col_idx, row_idx);

	// Position within cell (0..1)
	float fx = fract(col_adj_x / grid_spacing_x);
	float fy = fract(scrolled.y / grid_spacing_y);

	// Seam distance (min distance to cell edge)
	float dx_seam = min(fx, 1.0 - fx) * grid_spacing_x;
	float dy_seam = min(fy, 1.0 - fy) * grid_spacing_y;
	float seam_dist = min(dx_seam, dy_seam);

	// Seam core (bright line)
	float seam_core = smoothstep(seam_width * 1.2, seam_width * 0.2, seam_dist);
	// Seam glow (wider, dimmer)
	float seam_bloom = exp(-seam_dist * seam_dist / (seam_glow * seam_glow));

	// Irregular seam brightness per cell edge
	float edge_hash = hash(cell_id);
	float seam_bright = 0.5 + 0.5 * edge_hash;

	col += seam_color.rgb * seam_core * seam_bright * seam_hdr * seam_color.a;
	col += seam_color.rgb * seam_bloom * seam_bright * 0.15 * seam_color.a;

	// ── Cell interior surface variation ──
	// Slight per-cell shade differences (some panels lighter, some darker)
	float cell_shade = 0.85 + hash(cell_id + 17.0) * 0.3;
	// Only inside, not on seams
	float inside = smoothstep(seam_width * 1.5, seam_width * 3.0, seam_dist);
	col *= mix(1.0, cell_shade, inside);

	// Sub-panel detail: faint hairline at cell center
	float mid_x = abs(fx - 0.5) * grid_spacing_x;
	float mid_y = abs(fy - 0.5) * grid_spacing_y;
	float sub_seam_x = smoothstep(0.8, 0.0, mid_x) * inside;
	float sub_seam_y = smoothstep(0.8, 0.0, mid_y) * inside;
	col += seam_color.rgb * max(sub_seam_x, sub_seam_y) * 0.12;

	// ── Glyph marks / rivets in some cells ──
	float glyph_chance = hash(cell_id + 7.0);
	if (glyph_chance > 0.85) {
		vec2 glyph_center = vec2(0.5, 0.5);
		float glyph_dist = length(vec2(fx, fy) - glyph_center) * min(grid_spacing_x, grid_spacing_y);
		float glyph = smoothstep(4.0, 2.0, glyph_dist) * inside;
		col += seam_color.rgb * glyph * 0.2;
	}

	// ══════════════════════════════════════════════
	// WINDOW GLOW — some cells have dim interior light
	// ══════════════════════════════════════════════
	float win_hash = hash(cell_id + 3.0);
	if (win_hash > (1.0 - window_density)) {
		float win_mask = inside;
		// Window is inset from edges
		float inset_x = smoothstep(0.15, 0.25, fx) * smoothstep(0.85, 0.75, fx);
		float inset_y = smoothstep(0.15, 0.25, fy) * smoothstep(0.85, 0.75, fy);
		float win_shape = inset_x * inset_y * win_mask;
		// Gentle flicker
		float flick = 0.7 + 0.3 * sin(TIME * (0.3 + win_hash * 1.5) + win_hash * 10.0);
		col += window_color.rgb * win_shape * flick * window_hdr * window_color.a;
	}

	// ══════════════════════════════════════════════
	// SCANNER BEAMS — diagonal lines sweeping across
	// ══════════════════════════════════════════════
	int sc = int(scan_count);
	for (int i = 0; i < 8; i++) {
		if (i >= sc) break;
		float fi = float(i);
		// Each scanner moves at its own speed along perpendicular to scan_angle
		float sp = scan_speed * (0.7 + hash(vec2(fi, 5.0)) * 0.6);
		// Direction of scanner travel (perpendicular to beam line)
		float sp_sign = (hash(vec2(fi, 9.0)) > 0.5) ? 1.0 : -1.0;
		// Beam is a line at angle scan_angle; scanner moves perpendicular
		// Project pixel onto perpendicular axis
		vec2 beam_dir = normalize(vec2(1.0, scan_angle));
		vec2 perp = vec2(-beam_dir.y, beam_dir.x);
		float offset = dot(scrolled, perp);
		// Scanner position on perp axis: scrolls over time
		float scan_phase = hash(vec2(fi, 13.0)) * 2000.0;
		float scan_pos = mod(TIME * sp * sp_sign + scan_phase, 3000.0) - 1500.0;
		float dist_to_beam = abs(offset - scan_pos);

		// Core line
		float core = smoothstep(scan_width * 1.5, scan_width * 0.2, dist_to_beam);
		// Glow halo
		float glow = exp(-dist_to_beam * dist_to_beam / (scan_glow_size * scan_glow_size));

		// Sparkle: irregular brightness along beam
		float along_beam = dot(scrolled, beam_dir);
		float sparkle = 0.6 + 0.4 * vnoise(vec2(along_beam * 0.008, fi * 7.0 + TIME * 0.5));

		col += scan_color.rgb * core * scan_hdr * sparkle * scan_color.a;
		col += scan_color.rgb * glow * 0.25 * sparkle * scan_color.a;
	}

	// ══════════════════════════════════════════════
	// PULSE WAVES — scrolling HDR washes
	// ══════════════════════════════════════════════
	if (pulse_intensity > 0.001) {
		float pulse_y = scrolled.y * 0.001 * pulse_scale - TIME * pulse_speed;
		float wave = vnoise(vec2(pulse_y, scrolled.x * 0.0005));
		float pulse_val = smoothstep(pulse_threshold, pulse_threshold + pulse_softness, wave);
		// Extra wobble
		float wobble = vnoise(vec2(pulse_y * 2.0, scrolled.x * 0.001 + TIME * 0.3));
		pulse_val *= (0.7 + wobble * 0.6);
		col += scan_color.rgb * pulse_val * pulse_intensity * pulse_hdr;
	}

	// ══════════════════════════════════════════════
	// SUBTLE NOISE WEATHERING
	// ══════════════════════════════════════════════
	float grime = vnoise(scrolled * 0.012);
	col *= (0.92 + grime * 0.16);

	COLOR = vec4(col, panel_color.a * modulate_alpha);
}
