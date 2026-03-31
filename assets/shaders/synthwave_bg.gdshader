shader_type canvas_item;

// ── Sky ──
uniform vec3 sky_top : source_color = vec3(0.01, 0.0, 0.06);
uniform vec3 sky_mid : source_color = vec3(0.08, 0.0, 0.14);
uniform vec3 sky_low : source_color = vec3(0.18, 0.02, 0.25);
uniform float horizon : hint_range(0.3, 0.65) = 0.50;

// ── Sun ──
uniform float sun_x : hint_range(0.35, 0.85) = 0.63;
uniform float sun_size : hint_range(0.04, 0.22) = 0.11;
uniform vec3 sun_color_top : source_color = vec3(1.0, 0.95, 0.4);
uniform vec3 sun_color_bot : source_color = vec3(1.0, 0.2, 0.08);
uniform float sun_glow : hint_range(0.0, 2.0) = 0.6;

// ── Grid ──
uniform vec3 grid_color : source_color = vec3(1.0, 0.08, 0.52);
uniform float camera_height : hint_range(0.2, 3.0) = 1.2;
uniform float grid_freq : hint_range(0.5, 5.0) = 2.0;
uniform float grid_line_w : hint_range(0.001, 0.03) = 0.008;
uniform float grid_bloom_w : hint_range(0.01, 0.15) = 0.06;
uniform float grid_core_brightness : hint_range(0.5, 12.0) = 6.0;
uniform float grid_core_tint : hint_range(0.0, 1.0) = 0.0;
uniform float grid_bloom_brightness : hint_range(0.5, 8.0) = 3.0;
uniform float scroll_speed : hint_range(0.0, 2.0) = 0.5;

// ── Corridor ──
uniform float corridor_gap : hint_range(0.02, 0.25) = 0.10;
uniform float grid_fade_width : hint_range(0.02, 0.4) = 0.18;

// ── Nebula ──
uniform vec3 accent_color : source_color = vec3(0.1, 0.8, 1.0);
uniform float nebula_intensity : hint_range(0.0, 0.5) = 0.12;
uniform float nebula_scale : hint_range(1.0, 8.0) = 3.5;
uniform float nebula_drift : hint_range(0.0, 0.1) = 0.015;

// ── Stars ──
uniform float star_cutoff : hint_range(0.85, 0.99) = 0.94;

// ── Warp streaks ──
uniform float warp_streak_intensity : hint_range(0.0, 1.5) = 0.5;
uniform float warp_streak_speed : hint_range(0.2, 3.0) = 1.0;
uniform float warp_inner_radius : hint_range(0.05, 0.5) = 0.2;
uniform float warp_fade_width : hint_range(0.02, 0.3) = 0.1;
uniform float warp_max_length : hint_range(0.02, 0.25) = 0.12;
uniform float warp_streak_width : hint_range(0.0005, 0.004) = 0.0015;

// ── Motion lights ──
uniform float light_speed : hint_range(0.05, 2.0) = 0.5;
uniform float light_brightness : hint_range(0.0, 3.0) = 0.5;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += amp * value_noise(p);
		p *= 2.1;
		amp *= 0.45;
	}
	return v;
}

// Grid line intensities for a given distance from horizon
// Returns vec2(core, bloom)
vec2 calc_grid(vec2 uv_in, float v_dist, float ar_in) {
	float persp = camera_height / max(v_dist, 0.001);
	float wx = (uv_in.x - 0.5) * persp;
	float wz = persp + TIME * scroll_speed;

	float gx_w = wx * grid_freq;
	float gz_w = wz * grid_freq;
	float gx = abs(fract(gx_w) - 0.5);
	float gz = abs(fract(gz_w) - 0.5);
	float fwx = fwidth(gx_w);
	float fwz = fwidth(gz_w);

	float core_x = 1.0 - smoothstep(grid_line_w - fwx * 0.5, grid_line_w + fwx * 0.5, gx);
	float core_z = 1.0 - smoothstep(grid_line_w - fwz * 0.5, grid_line_w + fwz * 0.5, gz);
	float core = max(core_x, core_z);

	float bloom_x = 1.0 - smoothstep(grid_line_w, grid_bloom_w + fwx, gx);
	float bloom_z = 1.0 - smoothstep(grid_line_w, grid_bloom_w + fwz, gz);
	float bloom = max(bloom_x, bloom_z);

	// Single unified fade: zero inside corridor_gap, ramps up over grid_fade_width
	float fade = smoothstep(corridor_gap, corridor_gap + grid_fade_width, v_dist);

	return vec2(core * fade, bloom * fade);
}

void fragment() {
	vec2 uv = UV;
	float ar = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float sun_cy = horizon;

	// ════════════════════════════════════════════════════════
	// LAYER 1: Full-screen space background
	// ════════════════════════════════════════════════════════

	float dist_from_horizon = abs(uv.y - horizon) / max(horizon, 1.0 - horizon);
	float t = 1.0 - dist_from_horizon;
	vec3 col = (t > 0.5)
		? mix(sky_mid, sky_low, (t - 0.5) * 2.0)
		: mix(sky_top, sky_mid, t * 2.0);

	col += vec3(0.04, 0.0, 0.06) * smoothstep(0.3, 0.9, uv.x) * t;

	// ── Nebula wisps ───────────────────────────────────────
	if (nebula_intensity > 0.001) {
		vec2 neb_uv = uv * nebula_scale + vec2(TIME * nebula_drift, TIME * nebula_drift * 0.6);
		float neb = fbm(neb_uv) * fbm(neb_uv * 1.4 + 5.3);
		neb = smoothstep(0.12, 0.45, neb) * nebula_intensity;
		neb *= smoothstep(0.05, 0.6, uv.x);
		neb *= smoothstep(0.0, 0.15, dist_from_horizon);
		col += accent_color * neb * 2.0;

		vec2 neb_uv2 = uv * nebula_scale * 0.7 + vec2(-TIME * nebula_drift * 0.8, TIME * nebula_drift * 0.3) + 20.0;
		float neb2 = fbm(neb_uv2) * fbm(neb_uv2 * 1.2 + 8.1);
		neb2 = smoothstep(0.18, 0.5, neb2) * nebula_intensity * 0.5;
		neb2 *= smoothstep(0.2, 0.8, uv.x);
		neb2 *= smoothstep(0.0, 0.2, dist_from_horizon);
		col += vec3(0.6, 0.1, 0.8) * neb2 * 1.5;
	}

	// ── Sun ────────────────────────────────────────────────
	vec2 sd = vec2((uv.x - sun_x) * ar, uv.y - sun_cy);
	float sun_dist = length(sd);

	float haze = exp(-sun_dist * 5.5 / sun_size) * sun_glow;
	col += vec3(1.0, 0.45, 0.18) * haze * 3.0;

	if (sun_dist < sun_size) {
		float ny = (uv.y - (sun_cy - sun_size)) / (2.0 * sun_size);
		vec3 sc = mix(sun_color_top, sun_color_bot, clamp(ny, 0.0, 1.0));
		float edge = smoothstep(sun_size, sun_size - 0.005, sun_dist);

		float slice_mask = 1.0;
		float cut_start = 0.32;
		if (ny > cut_start) {
			float region = (ny - cut_start) / (1.0 - cut_start);
			float y_acc = 0.0;
			for (int i = 0; i < 9; i++) {
				float band  = 0.058;
				float gap_h = 0.006 + float(i) * 0.016;
				y_acc += band;
				if (region >= y_acc && region < y_acc + gap_h) {
					slice_mask = 0.0;
					break;
				}
				y_acc += gap_h;
				if (y_acc > 1.0) break;
			}
		}
		col = mix(col, sc * 3.0, edge * slice_mask);
	}

	// ── Stars (full screen) ────────────────────────────────
	{
		vec2 cell = floor(uv * vec2(140.0, 70.0));
		float h = hash(cell);
		if (h > star_cutoff) {
			vec2 soff = vec2(hash(cell + 111.0), hash(cell + 222.0));
			vec2 sp   = (cell + soff) / vec2(140.0, 70.0);
			float sd2  = length((uv - sp) * vec2(ar, 1.0));
			float twinkle = sin(TIME * (1.5 + h * 4.0) + h * 6.283) * 0.5 + 0.5;
			float b = smoothstep(0.003, 0.0, sd2) * (0.2 + 0.8 * twinkle);
			b *= 0.6 + uv.x * 0.8;
			float sun_prox = length(vec2((uv.x - sun_x) * ar, uv.y - sun_cy));
			b *= smoothstep(sun_size * 1.5, sun_size * 3.0, sun_prox);
			b *= smoothstep(0.0, 0.08, dist_from_horizon);
			col += vec3(0.85, 0.85, 1.05) * b * 2.5;
		}
	}

	// ── Warp streaks (radial vignette from screen center) ──
	if (warp_streak_intensity > 0.01) {
		vec2 center = vec2(0.5, 0.5);
		// Pixel distance from center (aspect-corrected so circle not ellipse)
		vec2 to_center = vec2((uv.x - center.x) * ar, uv.y - center.y);
		float pixel_dist = length(to_center);
		float pixel_angle = atan(to_center.y, to_center.x);

		for (int i = 0; i < 20; i++) {
			float fi = float(i);
			float a = hash(vec2(fi, 44.4)) * 6.2832;

			// How close is this pixel's angle to the streak's angle?
			float angle_diff = abs(mod(pixel_angle - a + 3.14159, 6.2832) - 3.14159);
			// Early-out: skip if angle is way off
			if (angle_diff > 0.06) { continue; }

			float period = 1.2 + hash(vec2(fi, 55.5)) * 2.0;
			float phase = hash(vec2(fi, 66.6));
			float spd = warp_streak_speed * (0.4 + hash(vec2(fi, 77.7)) * 0.8);
			float cycle = fract(TIME * spd / period + phase);

			// Streak travels from inner radius to well past screen edge
			// Screen diagonal (aspect-corrected) is ~sqrt((0.5*ar)^2+0.5^2) ≈ 1.0
			float max_reach = 1.2;
			float head_d = warp_inner_radius + cycle * max_reach;
			// Trail grows longer the further from center (parallax)
			float dist_ratio = (head_d - warp_inner_radius) / max_reach;
			float trail_len = warp_max_length * (0.15 + dist_ratio * 0.85);
			float tail_d = max(head_d - trail_len, warp_inner_radius);

			// Is the pixel on this streak's radial line, between tail and head?
			if (pixel_dist < tail_d || pixel_dist > head_d) { continue; }

			// Perpendicular distance from the radial line
			vec2 streak_dir = vec2(cos(a), sin(a));
			float perp = abs(to_center.x * streak_dir.y - to_center.y * streak_dir.x);

			float w = warp_streak_width + pixel_dist * 0.002; // slightly wider at edges
			if (perp > w) { continue; }

			// Brightness: ramps toward head, fades at tail
			float along_t = (pixel_dist - tail_d) / max(head_d - tail_d, 0.001);
			float b = along_t; // brighter at the head
			b *= smoothstep(w, w * 0.15, perp); // soft edges
			// Vignette fade-in: invisible inside inner radius, fading in over fade_width
			b *= smoothstep(warp_inner_radius, warp_inner_radius + warp_fade_width, pixel_dist);
			b *= warp_streak_intensity;
			col += accent_color * b * 5.0; // HDR
		}
	}

	// ════════════════════════════════════════════════════════
	// LAYER 2: Grid overlays (transparent cells, lines only)
	// ════════════════════════════════════════════════════════

	vec3 core_col = mix(vec3(1.0, 0.9, 0.95), grid_color * 1.5, grid_core_tint);

	float v_bot = uv.y - horizon;
	if (v_bot > 0.0) {
		vec2 g = calc_grid(uv, v_bot, ar);
		col += grid_color * g.y * grid_bloom_brightness;
		col += core_col * g.x * grid_core_brightness;
	}

	float v_top = horizon - uv.y;
	if (v_top > 0.0) {
		vec2 g = calc_grid(uv, v_top, ar);
		col += grid_color * g.y * grid_bloom_brightness;
		col += core_col * g.x * grid_core_brightness;
	}

	// ── Horizon glow (at corridor edges) ───────────────────
	float edge_bot = max(v_bot - corridor_gap, 0.0);
	float edge_top = max(v_top - corridor_gap, 0.0);
	float h_glow_bot = exp(-edge_bot * 25.0) * smoothstep(0.0, 0.02, edge_bot) * 0.4;
	float h_glow_top = exp(-edge_top * 25.0) * smoothstep(0.0, 0.02, edge_top) * 0.4;
	col += vec3(0.9, 0.15, 0.45) * (h_glow_bot + h_glow_top) * 3.0;

	// ── Sun reflection on bottom grid ──────────────────────
	if (v_bot > corridor_gap) {
		float refl_x = abs(uv.x - sun_x);
		float refl = exp(-refl_x * 6.0 * ar) * exp(-edge_bot * 8.0) * 0.35;
		col += vec3(1.0, 0.5, 0.2) * refl * 2.0;
	}

	// ── Motion point lights (both grids, toward viewer) ────
	for (int i = 0; i < 8; i++) {
		float fi = float(i);
		float lane = (hash(vec2(fi * 7.13, 42.7)) - 0.2) * 5.0;
		float phase = hash(vec2(fi * 3.31, 99.1));
		float spd = light_speed * (0.35 + hash(vec2(fi * 5.17, 77.3)) * 0.9);
		float cycle = fract(phase - TIME * spd * 0.08);
		float lz = 0.5 + cycle * 14.0;

		float pv = camera_height / lz;
		float px = 0.5 + lane / lz;

		float py_bot = horizon + corridor_gap + pv;
		if (py_bot < 1.0 && px > -0.05 && px < 1.05) {
			vec2 ld = vec2((uv.x - px) * ar, uv.y - py_bot);
			float d = length(ld);
			float sz = 0.005 + 0.018 / lz;
			float g_val = exp(-d / sz) * light_brightness / (1.0 + lz * 0.15);
			float fade = smoothstep(0.0, 0.05, py_bot - horizon - corridor_gap);
			col += grid_color * g_val * fade * 2.5;
		}

		float py_top = horizon - corridor_gap - pv;
		if (py_top > 0.0 && px > -0.05 && px < 1.05) {
			vec2 ld = vec2((uv.x - px) * ar, uv.y - py_top);
			float d = length(ld);
			float sz = 0.005 + 0.018 / lz;
			float g_val = exp(-d / sz) * light_brightness / (1.0 + lz * 0.15);
			float fade = smoothstep(0.0, 0.05, horizon - corridor_gap - py_top);
			col += grid_color * g_val * fade * 2.5;
		}
	}

	COLOR = vec4(col, 1.0);
}
