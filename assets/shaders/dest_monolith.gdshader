shader_type canvas_item;
// Monolith — Upright alien artifact being scanned by nearby ships.
// Pearl-white vertical slab with panel seams and lit windows. Ships orbit
// it casting point-light spotlights; their beams sweep across the surface
// and hotspot where they strike.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 3.0;
uniform vec3 bg_color : source_color = vec3(0.004, 0.007, 0.014);
uniform vec3 hull_color : source_color = vec3(0.92, 0.95, 1.0);
uniform vec3 seam_color : source_color = vec3(0.45, 0.52, 0.62);
uniform vec3 accent_color : source_color = vec3(0.55, 0.85, 1.0);
uniform vec3 ship_color : source_color = vec3(0.8, 0.92, 1.0);
uniform vec3 warm_scanner : source_color = vec3(0.45, 0.78, 1.0);
uniform float hull_w : hint_range(0.03, 0.2) = 0.075;
uniform float hull_h : hint_range(0.15, 0.42) = 0.32;
uniform float corner_r : hint_range(0.005, 0.04) = 0.012;
uniform float seam_grid_x : hint_range(2.0, 14.0) = 5.0;
uniform float seam_grid_y : hint_range(8.0, 40.0) = 22.0;
uniform float window_density : hint_range(0.0, 1.0) = 0.38;
uniform float ship_orbit_speed : hint_range(0.0, 1.0) = 0.07;
uniform float aura_strength : hint_range(0.0, 2.0) = 0.9;
uniform float damage_noise : hint_range(0.0, 1.0) = 0.35;

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

float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * vnoise(p); p *= 2.03; a *= 0.5; }
	return v;
}

float sd_rrect(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// Soft cone / beam from point A aimed at B, with half-width at target.
// Returns intensity at point p.
float beam(vec2 p, vec2 a, vec2 b, float half_width_at_target, float falloff) {
	vec2 axis = b - a;
	float len = length(axis);
	if (len < 0.0001) return 0.0;
	vec2 n = axis / len;
	vec2 from_a = p - a;
	float along = dot(from_a, n);
	if (along < 0.0 || along > len * 1.05) return 0.0;
	vec2 perp_v = from_a - n * along;
	float perp_d = length(perp_v);
	float t = along / len;
	float half_w = mix(0.004, half_width_at_target, t);
	float edge = smoothstep(half_w, half_w * 0.35, perp_d);
	// Taper along length: fade at source, fade toward target, hard zero past target
	float near_source = smoothstep(0.0, 0.08, t);
	float near_target = smoothstep(1.05, 0.75, t);
	float length_taper = near_source * near_target;
	float dist_fade = 1.0 / (1.0 + along * along * falloff);
	return edge * dist_fade * length_taper;
}

void fragment() {
	vec2 uv = UV;
	float ar = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 center = vec2(0.5, 0.5);
	vec2 d = vec2((uv.x - center.x) * ar, uv.y - center.y);
	vec3 col = bg_color;

	vec2 half_size = vec2(hull_w, hull_h);
	float sd = sd_rrect(d, half_size, corner_r);
	bool inside = sd < 0.0;

	// ── Ship scanner positions (orbit slowly around monolith) ──
	const int SHIP_COUNT = 4;
	vec2 ships[4];
	for (int s = 0; s < SHIP_COUNT; s++) {
		float fs = float(s);
		float orbit_phase = fs * 1.5708 + TIME * ship_orbit_speed * (1.0 + fs * 0.07);
		float orbit_r = 0.28 + fs * 0.025 + sin(TIME * 0.3 + fs) * 0.015;
		float orbit_y_bias = -0.08 + fs * 0.05;
		ships[s] = vec2(cos(orbit_phase) * orbit_r, sin(orbit_phase) * orbit_r * 0.55 + orbit_y_bias);
	}

	// ── Outer aura / cool-white wash around monolith ──
	float aura = exp(-max(sd, 0.0) * 10.0);
	col += hull_color * aura * hdr_intensity * 0.08 * aura_strength;
	float aura_soft = exp(-max(sd, 0.0) * 2.8);
	col += accent_color * aura_soft * hdr_intensity * 0.03 * aura_strength;

	// ── Volumetric scanner beams (in space, before hitting surface) ──
	// Aim each ship at a slightly-moving point on the monolith
	for (int s = 0; s < SHIP_COUNT; s++) {
		float fs = float(s);
		// Target moves across monolith surface
		float tgt_y = sin(TIME * 0.35 + fs * 1.7) * hull_h * 0.7;
		float tgt_x = sin(TIME * 0.22 + fs * 0.9) * hull_w * 0.5;
		vec2 target = vec2(tgt_x, tgt_y);
		vec2 sp = ships[s];
		// Only render volumetric beam in empty space (not inside hull)
		if (!inside) {
			float b = beam(d, sp, target, 0.025, 18.0);
			float flicker = 0.9 + 0.1 * sin(TIME * 7.0 + fs * 3.0);
			col += warm_scanner * b * 0.35 * flicker * hdr_intensity;
		}
	}

	// ══════════════════════════════════════════════
	// HULL INTERIOR
	// ══════════════════════════════════════════════
	if (inside) {
		// Base pearl white with subtle vertical sheen
		float vertical_sheen = 0.82 + 0.18 * smoothstep(hull_h, -hull_h, d.y);
		vec3 hull = hull_color * vertical_sheen;

		// ── Panel seams: tall vertical slab needs irregular grid ──
		// Horizontal seams (bands) packed denser than vertical
		vec2 panel_uv = (d + half_size) * vec2(seam_grid_x, seam_grid_y);
		vec2 panel_f = fract(panel_uv);
		vec2 panel_id = floor(panel_uv);
		// Irregularity: some rows slightly offset horizontally
		float row_offset = hash(vec2(panel_id.y, 7.0)) * 0.4 - 0.2;
		panel_f.x = fract(panel_uv.x + row_offset);

		float seam_w = 0.06;
		float seam_x = smoothstep(seam_w, seam_w * 0.25, min(panel_f.x, 1.0 - panel_f.x));
		float seam_y = smoothstep(seam_w, seam_w * 0.25, min(panel_f.y, 1.0 - panel_f.y));
		float seam = max(seam_x, seam_y);
		float inner_fade = smoothstep(-0.002, -0.010, sd);
		hull = mix(hull, seam_color, seam * 0.45 * inner_fade);

		// ── Irregular dark streaks / weathering ──
		float streaks = fbm(d * vec2(8.0, 35.0) + vec2(0.0, 2.0));
		streaks = smoothstep(0.4, 0.8, streaks);
		hull = mix(hull, hull * 0.78, streaks * damage_noise * inner_fade);

		// ── Hairline scratches ──
		float scratch = fbm(d * vec2(120.0, 4.0));
		scratch = smoothstep(0.55, 0.75, scratch);
		hull = mix(hull, hull * 0.88, scratch * damage_noise * 0.6 * inner_fade);

		// ── Random glyph marks / rivet clusters ──
		// One glyph per panel cell, sparse
		float cell_hash = hash(panel_id + 11.0);
		if (cell_hash > 0.82) {
			// Small dot inside cell
			vec2 glyph_uv = panel_f - 0.5;
			float glyph_d = length(glyph_uv);
			float glyph = smoothstep(0.08, 0.04, glyph_d);
			hull = mix(hull, seam_color * 0.5, glyph * 0.7 * inner_fade);
		}

		// ── Lit interior windows (rare, dim amber) ──
		float wc_hash = hash(panel_id + 3.0);
		float lit = step(1.0 - window_density, wc_hash);
		float window_mask = 1.0
			- smoothstep(0.22, 0.14, min(panel_f.x, 1.0 - panel_f.x))
			- smoothstep(0.22, 0.14, min(panel_f.y, 1.0 - panel_f.y));
		window_mask = clamp(window_mask, 0.0, 1.0);
		float window_flick = 0.7 + 0.3 * sin(TIME * (0.3 + wc_hash * 1.8) + wc_hash * 12.0);
		window_flick *= step(0.1, wc_hash + sin(TIME * 0.12 + wc_hash * 18.0) * 0.5 + 0.5);
		hull += warm_scanner * window_mask * lit * window_flick * inner_fade * 0.18 * hdr_intensity;

		// ── Scanner hotspots where beams strike surface ──
		// Compute ambient scanner illumination as a sum of gaussian spots
		for (int s = 0; s < SHIP_COUNT; s++) {
			float fs = float(s);
			float tgt_y = sin(TIME * 0.35 + fs * 1.7) * hull_h * 0.7;
			float tgt_x = sin(TIME * 0.22 + fs * 0.9) * hull_w * 0.5;
			vec2 target = vec2(tgt_x, tgt_y);
			// On the slab surface, the "hit point" is the target
			vec2 diff_hit = d - target;
			// Stretch hotspot vertically (angled impact from side ships)
			diff_hit.x *= 1.5;
			float hit_dist = length(diff_hit);
			float hot_tight = exp(-hit_dist * hit_dist / 0.00025);
			float hot_wide = exp(-hit_dist * hit_dist / 0.006);
			float flicker = 0.88 + 0.12 * sin(TIME * 9.0 + fs * 4.0);
			hull += warm_scanner * hot_tight * 0.8 * hdr_intensity * flicker * inner_fade;
			hull += warm_scanner * hot_wide * 0.15 * hdr_intensity * flicker * inner_fade;
		}

		col = hull;
	}

	// ── Edge rim (bright silver line) ──
	float rim_w = 0.003;
	float rim = smoothstep(rim_w, rim_w * 0.2, abs(sd));
	col += hull_color * rim * hdr_intensity * 0.5;
	float rim_glow = exp(-abs(sd) * 200.0);
	col += hull_color * rim_glow * hdr_intensity * 0.22;

	// ── Ships: tiny silhouettes with running lights ──
	for (int s = 0; s < SHIP_COUNT; s++) {
		float fs = float(s);
		vec2 sp = ships[s];
		// Small dark body
		vec2 ship_diff = d - sp;
		// Orient ship toward monolith (stretch along axis)
		vec2 to_mono = normalize(-sp);
		float axial = dot(ship_diff, to_mono);
		vec2 perp_axis = vec2(-to_mono.y, to_mono.x);
		float lateral = dot(ship_diff, perp_axis);
		vec2 ship_local = vec2(axial, lateral);
		// Small elongated hull
		float ship_sd = sd_rrect(ship_local, vec2(0.012, 0.004), 0.003);
		if (ship_sd < 0.0) {
			col = vec3(0.05, 0.06, 0.08);
		}
		// Ship rim glow
		float ship_rim = exp(-abs(ship_sd) * 400.0);
		col += ship_color * ship_rim * hdr_intensity * 0.18;
		// Bright scanner emitter (main point light at ship nose)
		vec2 nose_pos = sp + to_mono * 0.013;
		float nose_dist = length(d - nose_pos);
		float emitter = exp(-nose_dist * nose_dist / 0.000015);
		float emitter_glow = exp(-nose_dist * nose_dist / 0.0006);
		col += warm_scanner * emitter * hdr_intensity * 4.0;
		col += warm_scanner * emitter_glow * hdr_intensity * 0.4;
		// Small red running light at tail
		vec2 tail_pos = sp - to_mono * 0.012;
		float tail_dist = length(d - tail_pos);
		float tail_blink = 0.3 + 0.7 * pow(max(sin(TIME * 2.1 + fs * 1.3), 0.0), 6.0);
		col += vec3(1.0, 0.25, 0.2) * exp(-tail_dist * tail_dist / 0.000008) * tail_blink * hdr_intensity * 2.5;
	}

	// ── Drift haze ──
	vec2 haze_uv = uv * 3.2 + vec2(TIME * 0.01, TIME * 0.006);
	float haze = vnoise(haze_uv) * vnoise(haze_uv * 1.7 + 3.0);
	float haze_mask = smoothstep(0.6, 0.08, length(d));
	col += accent_color * haze * haze_mask * 0.03 * hdr_intensity;

	// ── Stars ──
	for (int layer = 0; layer < 2; layer++) {
		float gs = (layer == 0) ? 90.0 : 140.0;
		float lo = float(layer) * 300.0;
		vec2 cell_s = floor(uv * vec2(gs, gs * 0.5));
		float h = hash(cell_s + lo);
		if (h > 0.94) {
			vec2 soff = vec2(hash(cell_s + lo + 111.0), hash(cell_s + lo + 222.0));
			vec2 sp = (cell_s + soff) / vec2(gs, gs * 0.5);
			float d_star = length((uv - sp) * vec2(ar, 1.0));
			float tw = 0.7 + 0.3 * sin(TIME * (1.0 + h * 3.0) + h * 6.28);
			float star = exp(-d_star * d_star / 0.000004) * tw;
			star *= smoothstep(0.0, 0.04, sd);
			col += vec3(0.85, 0.9, 1.0) * star * 1.3;
		}
	}

	COLOR = vec4(col, 1.0);
}
