shader_type canvas_item;
// Monolith — Apple-Store white rounded-rect megastation with panel seams,
// running edge lights, interior window glow, radar sweep, and breathing aura.
// Fully man-made, clinical, cool-white.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 3.0;
uniform vec3 bg_color : source_color = vec3(0.005, 0.008, 0.015);
uniform vec3 hull_color : source_color = vec3(0.92, 0.95, 1.0);
uniform vec3 seam_color : source_color = vec3(0.55, 0.62, 0.72);
uniform vec3 accent_color : source_color = vec3(0.55, 0.85, 1.0);
uniform vec3 warn_color : source_color = vec3(1.0, 0.35, 0.25);
uniform float hull_w : hint_range(0.08, 0.35) = 0.22;
uniform float hull_h : hint_range(0.08, 0.35) = 0.14;
uniform float corner_r : hint_range(0.005, 0.08) = 0.025;
uniform float seam_grid : hint_range(4.0, 24.0) = 12.0;
uniform float window_density : hint_range(0.0, 1.0) = 0.55;
uniform float sweep_speed : hint_range(0.0, 2.0) = 0.45;
uniform float aura_strength : hint_range(0.0, 2.0) = 0.8;
uniform float strobe_speed : hint_range(0.5, 6.0) = 2.2;

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

// Signed distance to rounded rectangle
float sd_rrect(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 uv = UV;
	float ar = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 center = vec2(0.5, 0.48);
	vec2 d = vec2((uv.x - center.x) * ar, uv.y - center.y);
	float dist = length(d);
	vec3 col = bg_color;

	vec2 half_size = vec2(hull_w, hull_h);
	float sd = sd_rrect(d, half_size, corner_r);

	// ── Outer aura / cool-white wash ──
	float aura = exp(-max(sd, 0.0) * 9.0);
	col += hull_color * aura * hdr_intensity * 0.12 * aura_strength;
	float aura_soft = exp(-max(sd, 0.0) * 2.5);
	col += accent_color * aura_soft * hdr_intensity * 0.04 * aura_strength;

	// ── Hull interior ──
	if (sd < 0.0) {
		// Base pearl white with subtle vertical sheen
		float vertical_sheen = 0.88 + 0.12 * smoothstep(-hull_h, hull_h, d.y);
		vec3 hull = hull_color * vertical_sheen;

		// ── Panel seam grid (thin darker lines) ──
		vec2 panel_uv = (d + half_size) * seam_grid;
		vec2 panel_f = fract(panel_uv);
		vec2 panel_id = floor(panel_uv);
		float seam_w = 0.04;
		float seam_x = smoothstep(seam_w, seam_w * 0.25, min(panel_f.x, 1.0 - panel_f.x));
		float seam_y = smoothstep(seam_w, seam_w * 0.25, min(panel_f.y, 1.0 - panel_f.y));
		float seam = max(seam_x, seam_y);
		// Fade seams near hull edges so they don't break silhouette
		float inner_fade = smoothstep(-0.002, -0.012, sd);
		hull = mix(hull, seam_color, seam * 0.35 * inner_fade);

		// ── Lit interior windows ──
		// Each seam-cell has a chance of being lit; gentle independent flicker
		float cell_hash = hash(panel_id + 3.0);
		float lit = step(1.0 - window_density, cell_hash);
		float window_mask = 1.0
			- smoothstep(0.12, 0.08, min(panel_f.x, 1.0 - panel_f.x))
			- smoothstep(0.12, 0.08, min(panel_f.y, 1.0 - panel_f.y));
		window_mask = clamp(window_mask, 0.0, 1.0);
		float window_flick = 0.75 + 0.25 * sin(TIME * (0.4 + cell_hash * 2.0) + cell_hash * 12.0);
		// Occasional hard-off windows
		window_flick *= step(0.08, cell_hash + 0.92 * sin(TIME * 0.15 + cell_hash * 20.0) * 0.5 + 0.5);
		hull += accent_color * window_mask * lit * window_flick * inner_fade * 0.25 * hdr_intensity;

		col = hull;
	}

	// ── Edge rim (bright silver line around hull) ──
	float rim_w = 0.0035;
	float rim = smoothstep(rim_w, rim_w * 0.2, abs(sd));
	col += hull_color * rim * hdr_intensity * 0.55;
	// Soft outer glow on the rim
	float rim_glow = exp(-abs(sd) * 180.0);
	col += hull_color * rim_glow * hdr_intensity * 0.25;

	// ── Running edge lights (travel around perimeter) ──
	// Compute arc-length parameter along rounded rect perimeter using angle
	float perim_angle = atan(d.y, d.x);
	float perim_t = (perim_angle + 3.14159) / 6.2832; // 0..1
	float light_band = smoothstep(0.002, 0.0, abs(sd));
	int light_count = 3;
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float lt = fract(TIME * sweep_speed * 0.12 + fi / 3.0);
		float dtt = abs(fract(perim_t - lt + 0.5) - 0.5);
		float glow = exp(-dtt * dtt * 900.0);
		col += accent_color * glow * light_band * hdr_intensity * 1.1;
	}

	// ── Corner strobes (warning lights at 4 corners) ──
	vec2 corners[4] = vec2[4](
		vec2(-hull_w, -hull_h), vec2(hull_w, -hull_h),
		vec2(-hull_w, hull_h), vec2(hull_w, hull_h)
	);
	for (int c = 0; c < 4; c++) {
		vec2 cp = corners[c];
		float cd = length(d - cp);
		float phase = float(c) * 1.3;
		float strobe = pow(max(sin(TIME * strobe_speed + phase), 0.0), 10.0);
		float dot_glow = exp(-cd * cd / 0.00003);
		float soft_glow = exp(-cd * cd / 0.0015);
		col += warn_color * dot_glow * strobe * hdr_intensity * 2.5;
		col += warn_color * soft_glow * strobe * hdr_intensity * 0.35;
	}

	// ── Comm array spires (thin verticals from top center) ──
	for (int s = 0; s < 3; s++) {
		float fs = float(s);
		float spire_x = (fs - 1.0) * 0.06;
		float spire_h = 0.05 + fs * 0.01;
		vec2 base_pt = vec2(spire_x, -hull_h);
		vec2 tip_pt = vec2(spire_x, -hull_h - spire_h);
		// Distance to vertical segment
		float t_param = clamp((d.y - tip_pt.y) / (base_pt.y - tip_pt.y), 0.0, 1.0);
		vec2 closest = mix(tip_pt, base_pt, t_param);
		float spd = length(d - closest);
		float spire_line = smoothstep(0.0015, 0.0005, spd);
		col += seam_color * spire_line * hdr_intensity * 0.6;
		// Red blinker at spire tip
		float tip_dist = length(d - tip_pt);
		float tip_blink = 0.3 + 0.7 * pow(max(sin(TIME * 1.8 + fs * 2.0), 0.0), 4.0);
		col += warn_color * exp(-tip_dist * tip_dist / 0.00001) * tip_blink * hdr_intensity * 2.0;
		col += warn_color * exp(-tip_dist * tip_dist / 0.0008) * tip_blink * hdr_intensity * 0.25;
	}

	// ── Radar sweep (rotating thin cone from top center) ──
	vec2 sweep_origin = vec2(0.0, -hull_h - 0.055);
	vec2 from_sweep = d - sweep_origin;
	float sweep_ang = atan(from_sweep.y, from_sweep.x);
	float sweep_t = TIME * sweep_speed;
	float target_ang = -1.5708 + sin(sweep_t) * 1.4; // sweep arc above
	float ang_diff = abs(mod(sweep_ang - target_ang + 3.14159, 6.2832) - 3.14159);
	float sweep_wedge = smoothstep(0.08, 0.0, ang_diff);
	float sweep_reach = smoothstep(0.38, 0.0, length(from_sweep)) * step(0.0, -from_sweep.y + 0.0);
	// Only show above the hull
	float above_hull = smoothstep(-hull_h - 0.05, -hull_h - 0.06, d.y);
	col += accent_color * sweep_wedge * sweep_reach * above_hull * hdr_intensity * 0.35;

	// ── Ambient ground scatter below station ──
	float below_glow = smoothstep(hull_h, hull_h + 0.15, d.y);
	float below_mask = smoothstep(hull_w * 2.5, 0.0, abs(d.x));
	col += hull_color * below_glow * below_mask * 0.08 * hdr_intensity;

	// ── Drift nebula haze (very subtle, cool-tinted) ──
	vec2 haze_uv = uv * 3.0 + vec2(TIME * 0.01, TIME * 0.005);
	float haze = vnoise(haze_uv) * vnoise(haze_uv * 1.7 + 3.0);
	float haze_mask = smoothstep(0.6, 0.1, dist);
	col += accent_color * haze * haze_mask * 0.04 * hdr_intensity;

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
			// Only show outside station
			star *= smoothstep(0.0, 0.04, sd);
			col += vec3(0.85, 0.9, 1.0) * star * 1.4;
		}
	}

	COLOR = vec4(col, 1.0);
}
