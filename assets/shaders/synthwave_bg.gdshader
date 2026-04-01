shader_type canvas_item;

// ── Sky ──
uniform vec3 sky_top : source_color = vec3(0.01, 0.0, 0.06);
uniform vec3 sky_mid : source_color = vec3(0.08, 0.0, 0.14);
uniform vec3 sky_low : source_color = vec3(0.18, 0.02, 0.25);
uniform float horizon : hint_range(0.3, 0.65) = 0.50;

// ── Planet body ──
uniform float planet_x : hint_range(0.35, 0.85) = 0.63;
uniform float planet_radius : hint_range(0.03, 0.2) = 0.08;
uniform vec3 planet_color_top : source_color = vec3(1.0, 0.85, 0.3);
uniform vec3 planet_color_bot : source_color = vec3(0.9, 0.2, 0.08);
uniform float planet_hdr : hint_range(0.5, 4.0) = 1.5;

// ── Planet slices ──
uniform float slice_enabled : hint_range(0.0, 1.0) = 1.0;
uniform float slice_start : hint_range(0.1, 0.6) = 0.32;
uniform float slice_band_h : hint_range(0.02, 0.12) = 0.058;
uniform float slice_gap_base : hint_range(0.002, 0.03) = 0.005;
uniform float slice_gap_grow : hint_range(0.005, 0.04) = 0.015;

// ── Ring ──
uniform float ring_inner : hint_range(0.05, 0.5) = 0.10;
uniform float ring_outer : hint_range(0.1, 1.5) = 1.1;
uniform float ring_tilt : hint_range(0.05, 0.8) = 0.15;
uniform float ring_angle : hint_range(-0.8, 0.8) = 0.35;
uniform vec3 ring_color : source_color = vec3(0.1, 0.8, 1.0);
uniform float ring_hdr : hint_range(0.5, 6.0) = 2.5;
uniform float ring_band_width : hint_range(0.005, 0.08) = 0.018;
uniform float ring_gap_base : hint_range(0.002, 0.05) = 0.010;
uniform float ring_gap_grow : hint_range(0.0, 0.03) = 0.014;

// ── Planet tilt ──
uniform float planet_tilted : hint_range(0.0, 1.0) = 1.0;

// ── Atmosphere ──
uniform float atmo_glow : hint_range(0.0, 2.0) = 0.6;
uniform vec3 atmo_color : source_color = vec3(0.2, 0.6, 1.0);
uniform float ring_glow_size : hint_range(0.0, 0.03) = 0.008;

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
uniform float star_density : hint_range(0.85, 0.99) = 0.94;
uniform float star_size : hint_range(0.001, 0.008) = 0.003;
uniform float star_glow_size : hint_range(0.0, 0.015) = 0.005;
uniform float star_brightness : hint_range(0.5, 5.0) = 2.5;
uniform float star_twinkle : hint_range(0.0, 1.0) = 0.6;
uniform vec3 star_color : source_color = vec3(0.7, 0.85, 1.0);

// ── Warp streaks ──
uniform float warp_streak_intensity : hint_range(0.0, 2.0) = 0.5;
uniform float warp_streak_speed : hint_range(0.1, 5.0) = 1.0;
uniform float warp_streak_count : hint_range(4.0, 40.0) = 20.0;
uniform float warp_inner_radius : hint_range(0.05, 0.5) = 0.2;
uniform float warp_fade_width : hint_range(0.02, 0.3) = 0.1;
uniform float warp_max_length : hint_range(0.02, 0.4) = 0.12;
uniform float warp_streak_width : hint_range(0.0005, 0.006) = 0.0015;

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

	float fade = smoothstep(corridor_gap, corridor_gap + grid_fade_width, v_dist);

	return vec2(core * fade, bloom * fade);
}

void fragment() {
	vec2 uv = UV;
	float ar = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float planet_cy = horizon;

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

	// ════════════════════════════════════════════════════════
	// RINGED PLANET (replaces sun)
	// ════════════════════════════════════════════════════════

	vec2 pd = vec2((uv.x - planet_x) * ar, uv.y - planet_cy);
	float pdist = length(pd);
	bool on_planet = pdist < planet_radius;

	// Rotate into ring plane
	float ca = cos(ring_angle);
	float sa = sin(ring_angle);
	vec2 pd_rot = vec2(pd.x * ca - pd.y * sa, pd.x * sa + pd.y * ca);

	float rdist = length(vec2(pd_rot.x, pd_rot.y / ring_tilt));
	bool in_ring = rdist > ring_inner && rdist < ring_outer;
	bool ring_front = pd_rot.y > 0.0;

	// Ring concentric slices
	float ring_alpha = 0.0;
	if (in_ring) {
		float r_from_inner = rdist - ring_inner;
		ring_alpha = 1.0;
		float r_acc = 0.0;
		for (int i = 0; i < 25; i++) {
			r_acc += ring_band_width;
			float gap = ring_gap_base + float(i) * ring_gap_grow;
			if (r_from_inner >= r_acc && r_from_inner < r_acc + gap) {
				ring_alpha = 0.0;
				break;
			}
			r_acc += gap;
			if (r_acc > ring_outer - ring_inner) break;
		}
		ring_alpha *= smoothstep(ring_inner, ring_inner + 0.003, rdist);
		ring_alpha *= smoothstep(ring_outer, ring_outer - 0.003, rdist);
	}

	// Ring glow
	float ring_glow_val = 0.0;
	if (ring_glow_size > 0.001) {
		float di = abs(rdist - ring_inner);
		float do2 = abs(rdist - ring_outer);
		float closest = in_ring ? 0.0 : min(di, do2);
		ring_glow_val = exp(-closest / ring_glow_size) * 0.4;
		if (on_planet) { ring_glow_val *= 0.2; }
	}

	// Planet gradient
	float grad_y = (planet_tilted > 0.5) ? pd_rot.y : pd.y;
	float ny = (grad_y + planet_radius) / (2.0 * planet_radius);

	// Atmosphere halo (behind everything)
	float atmo = exp(-pdist * 5.5 / planet_radius) * atmo_glow;
	col += atmo_color * atmo;

	// Ring behind planet
	if (in_ring && !ring_front && !on_planet) {
		col = mix(col, ring_color * ring_hdr * 0.5, ring_alpha);
	}
	if (!ring_front && !on_planet) {
		col += ring_color * ring_glow_val * ring_hdr * 0.3;
	}

	// Planet body
	if (on_planet) {
		vec3 pcol = mix(planet_color_top, planet_color_bot, clamp(ny, 0.0, 1.0));

		float shadow = smoothstep(-0.35, 0.45, -pd.x / planet_radius);
		shadow *= smoothstep(0.9, 0.3, ny);
		pcol *= 0.15 + 0.85 * shadow;

		if (slice_enabled > 0.5 && ny > slice_start) {
			float region = (ny - slice_start) / (1.0 - slice_start);
			float y_acc = 0.0;
			for (int i = 0; i < 9; i++) {
				float gap_h = slice_gap_base + float(i) * slice_gap_grow;
				y_acc += slice_band_h;
				if (region >= y_acc && region < y_acc + gap_h) {
					pcol = col; // show background through gap
					break;
				}
				y_acc += gap_h;
				if (y_acc > 1.0) break;
			}
		}

		float rim = smoothstep(0.5, 1.0, pdist / planet_radius);
		pcol += atmo_color * rim * atmo_glow;

		float edge = smoothstep(planet_radius, planet_radius - 0.003, pdist);
		col = mix(col, pcol * planet_hdr, edge);
	}

	// Ring in front
	if (in_ring && ring_front) {
		float front_alpha = ring_alpha;
		if (on_planet) { front_alpha *= 0.85; }
		col = mix(col, ring_color * ring_hdr, front_alpha);
	}
	if (ring_front || !on_planet) {
		col += ring_color * ring_glow_val * ring_hdr * 0.5;
	}

	// ── Stars (full screen) ────────────────────────────────
	{
		// Two density layers for variety
		for (int layer = 0; layer < 2; layer++) {
			float grid_scale = (layer == 0) ? 100.0 : 160.0;
			float layer_offset = float(layer) * 333.0;
			vec2 cell = floor(uv * vec2(grid_scale, grid_scale * 0.5));
			float h = hash(cell + layer_offset);
			float threshold = (layer == 0) ? star_density : star_density + (1.0 - star_density) * 0.4;
			if (h > threshold) {
				vec2 soff = vec2(hash(cell + layer_offset + 111.0), hash(cell + layer_offset + 222.0));
				vec2 sp = (cell + soff) / vec2(grid_scale, grid_scale * 0.5);
				vec2 delta = (uv - sp) * vec2(ar, 1.0);
				float d_star = length(delta);

				// Per-star variation
				float size_var = 0.5 + hash(cell + layer_offset + 333.0) * 0.8;
				float this_size = star_size * size_var;
				float this_glow = star_glow_size * (0.6 + size_var * 0.6);

				// Twinkle (gentle, not a hard pulse)
				float tw_speed = 1.0 + h * 3.0;
				float tw_phase = h * 6.283;
				float tw = sin(TIME * tw_speed + tw_phase);
				float tw_amount = 0.5 + (1.0 - star_twinkle) * 0.5 + star_twinkle * tw * 0.5;

				// Core dot (round, smooth edge)
				float core = smoothstep(this_size, this_size * 0.3, d_star);
				// Soft glow halo
				float glow = exp(-d_star * d_star / max(this_glow * this_glow, 0.000001)) * 0.4;

				float b = (core + glow) * tw_amount;
				b *= 0.6 + uv.x * 0.8;
				// Dim near planet
				float planet_prox = length(vec2((uv.x - planet_x) * ar, uv.y - planet_cy));
				b *= smoothstep(planet_radius * 1.5, planet_radius * 4.0, planet_prox);
				b *= smoothstep(0.0, 0.08, dist_from_horizon);
				col += star_color * b * star_brightness;
			}
		}
	}

	// ── Warp streaks (radial vignette from screen center) ──
	if (warp_streak_intensity > 0.01) {
		vec2 center = vec2(0.5, 0.5);
		vec2 to_center = vec2((uv.x - center.x) * ar, uv.y - center.y);
		float pixel_dist = length(to_center);
		float pixel_angle = atan(to_center.y, to_center.x);

		int streak_count = int(warp_streak_count);
		for (int i = 0; i < 40; i++) {
			if (i >= streak_count) break;
			float fi = float(i);
			float a = hash(vec2(fi, 44.4)) * 6.2832;

			float angle_diff = abs(mod(pixel_angle - a + 3.14159, 6.2832) - 3.14159);
			if (angle_diff > 0.06) { continue; }

			float period = 1.2 + hash(vec2(fi, 55.5)) * 2.0;
			float phase = hash(vec2(fi, 66.6));
			float spd = warp_streak_speed * (0.4 + hash(vec2(fi, 77.7)) * 0.8);
			float cycle = fract(TIME * spd / period + phase);

			float max_reach = 1.2;
			float head_d = warp_inner_radius + cycle * max_reach;
			float dist_ratio = (head_d - warp_inner_radius) / max_reach;
			float trail_len = warp_max_length * (0.15 + dist_ratio * 0.85);
			float tail_d = max(head_d - trail_len, warp_inner_radius);

			if (pixel_dist < tail_d || pixel_dist > head_d) { continue; }

			vec2 streak_dir = vec2(cos(a), sin(a));
			float perp = abs(to_center.x * streak_dir.y - to_center.y * streak_dir.x);

			float w = warp_streak_width + pixel_dist * 0.002;
			if (perp > w) { continue; }

			float along_t = (pixel_dist - tail_d) / max(head_d - tail_d, 0.001);
			float b2 = along_t;
			b2 *= smoothstep(w, w * 0.15, perp);
			b2 *= smoothstep(warp_inner_radius, warp_inner_radius + warp_fade_width, pixel_dist);
			b2 *= warp_streak_intensity;
			col += accent_color * b2 * 5.0;
		}
	}

	// ════════════════════════════════════════════════════════
	// LAYER 2: Grid overlays
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

	// Horizon glow
	float edge_bot = max(v_bot - corridor_gap, 0.0);
	float edge_top = max(v_top - corridor_gap, 0.0);
	float h_glow_bot = exp(-edge_bot * 25.0) * smoothstep(0.0, 0.02, edge_bot) * 0.4;
	float h_glow_top = exp(-edge_top * 25.0) * smoothstep(0.0, 0.02, edge_top) * 0.4;
	col += vec3(0.9, 0.15, 0.45) * (h_glow_bot + h_glow_top) * 3.0;

	// Planet reflection on bottom grid
	if (v_bot > corridor_gap) {
		float refl_x = abs(uv.x - planet_x);
		float refl = exp(-refl_x * 6.0 * ar) * exp(-edge_bot * 8.0) * 0.35;
		col += atmo_color * refl * 2.0;
	}

	// Motion point lights
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
			float d2 = length(ld);
			float sz = 0.005 + 0.018 / lz;
			float g_val = exp(-d2 / sz) * light_brightness / (1.0 + lz * 0.15);
			float fade = smoothstep(0.0, 0.05, py_bot - horizon - corridor_gap);
			col += grid_color * g_val * fade * 2.5;
		}

		float py_top = horizon - corridor_gap - pv;
		if (py_top > 0.0 && px > -0.05 && px < 1.05) {
			vec2 ld = vec2((uv.x - px) * ar, uv.y - py_top);
			float d2 = length(ld);
			float sz = 0.005 + 0.018 / lz;
			float g_val = exp(-d2 / sz) * light_brightness / (1.0 + lz * 0.15);
			float fade = smoothstep(0.0, 0.05, horizon - corridor_gap - py_top);
			col += grid_color * g_val * fade * 2.5;
		}
	}

	COLOR = vec4(col, 1.0);
}
