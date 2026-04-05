shader_type canvas_item;
// Spire City — Forest of vertical spires rising from below. Varied heights
// and widths, lit windows in stripes, top blinkers, atmospheric haze at
// base, searchlight beams from tallest spires.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 3.0;
uniform vec3 sky_color_top : source_color = vec3(0.01, 0.008, 0.025);
uniform vec3 sky_color_horizon : source_color = vec3(0.08, 0.04, 0.12);
uniform vec3 spire_color : source_color = vec3(0.1, 0.12, 0.16);
uniform vec3 spire_rim : source_color = vec3(0.55, 0.65, 0.85);
uniform vec3 window_color : source_color = vec3(1.0, 0.88, 0.55);
uniform vec3 top_blink : source_color = vec3(1.0, 0.3, 0.22);
uniform vec3 search_color : source_color = vec3(0.75, 0.9, 1.0);
uniform float atmosphere : hint_range(0.0, 2.0) = 1.0;
uniform float search_speed : hint_range(0.0, 1.5) = 0.35;

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

void fragment() {
	vec2 uv = UV;
	float ar = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	// Full-frame coordinates — no centering; we want a horizon
	vec3 col = mix(sky_color_top, sky_color_horizon, smoothstep(0.0, 1.0, uv.y));

	// ── Faint distant stars/satellites ──
	for (int layer = 0; layer < 1; layer++) {
		float gs = 120.0;
		vec2 cell_s = floor(uv * vec2(gs, gs * 0.5));
		float h = hash(cell_s);
		if (h > 0.95) {
			vec2 soff = vec2(hash(cell_s + 111.0), hash(cell_s + 222.0));
			vec2 sp = (cell_s + soff) / vec2(gs, gs * 0.5);
			float d_star = length((uv - sp) * vec2(ar, 1.0));
			float tw = 0.7 + 0.3 * sin(TIME * (1.0 + h * 3.0) + h * 6.28);
			float star = exp(-d_star * d_star / 0.000004) * tw;
			// Only visible above horizon
			star *= smoothstep(0.5, 0.3, uv.y);
			col += vec3(0.8, 0.85, 1.0) * star * 1.3;
		}
	}

	// ══════════════════════════════════════════════
	// SPIRES — ~14 vertical rectangles at varied positions
	// ══════════════════════════════════════════════
	// Hardcoded spires: {center_x, width, top_y (smaller = taller)}
	float spire_x[14] = float[14](
		0.06, 0.14, 0.22, 0.31, 0.40, 0.48, 0.55,
		0.63, 0.71, 0.78, 0.85, 0.92, 0.35, 0.68
	);
	float spire_w[14] = float[14](
		0.025, 0.015, 0.022, 0.018, 0.028, 0.012, 0.020,
		0.017, 0.023, 0.014, 0.026, 0.019, 0.010, 0.011
	);
	float spire_top[14] = float[14](
		0.45, 0.35, 0.22, 0.40, 0.15, 0.50, 0.30,
		0.42, 0.25, 0.38, 0.10, 0.45, 0.55, 0.52
	);
	float spire_base_y = 0.95;

	for (int s = 0; s < 14; s++) {
		float fs = float(s);
		float cx = spire_x[s];
		float half_w = spire_w[s];
		float top_y = spire_top[s];
		// Parallax: further spires (taller top_y value = shorter = "further") drift less
		float depth = 0.5 + top_y; // 0.6..1.5
		float rim_w = 0.002;

		float dx = abs(uv.x - cx);
		bool in_x = dx < half_w;
		bool in_y = uv.y > top_y && uv.y < spire_base_y;

		// Soft vertical edge for rim
		float edge_dist_x = dx - half_w;

		if (in_y && in_x) {
			// Inside spire body
			// Depth-based base color (further = hazier/lighter toward horizon)
			float haze_mix = smoothstep(1.3, 0.55, depth);
			vec3 base = mix(sky_color_horizon * 1.3, spire_color, haze_mix);
			// Vertical panel banding (horizontal stripes of lit windows)
			float band_period = 0.012 + depth * 0.005;
			float band_f = fract(uv.y / band_period);
			float band_lit = step(0.35, band_f) * step(band_f, 0.65);
			// Per-band random lit chance
			float band_id = floor(uv.y / band_period);
			float wh = hash(vec2(band_id, fs * 3.0));
			float band_active = step(0.45, wh);
			// Horizontal segmentation within band
			float col_period = half_w * 0.45;
			float col_f = fract(uv.x / col_period);
			float col_lit = step(0.25, col_f) * step(col_f, 0.75);
			float col_id = floor(uv.x / col_period);
			float ch = hash(vec2(col_id, band_id + fs * 17.0));
			float window_lit = band_active * col_lit * band_lit * step(0.4, ch);

			// Flicker
			float flick = 0.75 + 0.25 * sin(TIME * (0.4 + ch * 2.0) + ch * 15.0);
			flick *= step(0.08, ch + sin(TIME * 0.15 + ch * 18.0) * 0.5 + 0.5);

			vec3 spire_lit = base;
			spire_lit += window_color * window_lit * flick * 0.5 * hdr_intensity * haze_mix;

			// Depth haze overlay — atmospheric perspective
			float atm_amount = (1.0 - haze_mix) * atmosphere * 0.7;
			spire_lit = mix(spire_lit, sky_color_horizon * 2.2, atm_amount);

			col = spire_lit;
		}

		// Rim glow at edges (spire silhouette)
		if (in_y && edge_dist_x > -rim_w && edge_dist_x < rim_w) {
			float rim = 1.0 - abs(edge_dist_x) / rim_w;
			float haze_mix = smoothstep(1.3, 0.55, depth);
			col += spire_rim * rim * hdr_intensity * 0.35 * haze_mix;
		}

		// Top blinker
		vec2 top_point = vec2(cx, top_y);
		float td = length((uv - top_point) * vec2(ar, 1.0));
		float blink = 0.3 + 0.7 * pow(max(sin(TIME * 1.7 + fs * 0.8), 0.0), 5.0);
		col += top_blink * exp(-td * td / 0.000007) * blink * hdr_intensity * 2.5;
		col += top_blink * exp(-td * td / 0.0005) * blink * hdr_intensity * 0.25;
	}

	// ══════════════════════════════════════════════
	// SEARCHLIGHTS — 2 beams sweeping from tallest spires
	// ══════════════════════════════════════════════
	for (int sl = 0; sl < 2; sl++) {
		float fsl = float(sl);
		// Tallest spires indices: 10 (top 0.10), 4 (top 0.15)
		int idx = (sl == 0) ? 10 : 4;
		vec2 origin = vec2(spire_x[idx], spire_top[idx]);
		// Sweep angle
		float sweep_a = -1.5708 + sin(TIME * search_speed + fsl * 1.7) * 1.2;
		vec2 beam_dir = vec2(cos(sweep_a), sin(sweep_a));
		vec2 from_origin = (uv - origin) * vec2(ar, 1.0);
		float along = dot(from_origin, beam_dir);
		if (along < 0.0 || along > 0.7) continue;
		vec2 perp_v = from_origin - beam_dir * along;
		float perp_d = length(perp_v);
		float half_w_beam = mix(0.002, 0.035, along / 0.7);
		float wedge = smoothstep(half_w_beam, half_w_beam * 0.3, perp_d);
		float dist_fade = 1.0 / (1.0 + along * along * 8.0);
		float beam_flk = 0.9 + 0.1 * sin(TIME * 9.0 + fsl * 3.0);
		col += search_color * wedge * dist_fade * beam_flk * hdr_intensity * 0.18;
	}

	// ══════════════════════════════════════════════
	// ATMOSPHERIC HAZE at base
	// ══════════════════════════════════════════════
	float base_haze = smoothstep(0.55, spire_base_y, uv.y);
	vec2 haze_uv = uv * vec2(8.0, 4.0) + vec2(TIME * 0.02, 0.0);
	float haze_noise = fbm(haze_uv);
	col += sky_color_horizon * 2.2 * base_haze * (0.5 + haze_noise * 0.5) * atmosphere;

	// Horizon ground glow
	float ground_glow = smoothstep(0.85, spire_base_y, uv.y);
	col += window_color * ground_glow * 0.08 * atmosphere * hdr_intensity;

	// Overall fog tint
	float fog = smoothstep(0.3, 0.95, uv.y) * atmosphere * 0.12;
	col = mix(col, sky_color_horizon * 1.5, fog);

	COLOR = vec4(col, 1.0);
}
