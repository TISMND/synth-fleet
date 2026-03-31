shader_type canvas_item;

// ── Sky ──
uniform vec3 sky_top : source_color = vec3(0.01, 0.0, 0.06);
uniform vec3 sky_mid : source_color = vec3(0.08, 0.0, 0.14);
uniform vec3 sky_low : source_color = vec3(0.18, 0.02, 0.25);
uniform float horizon : hint_range(0.2, 0.55) = 0.38;

// ── Sun ──
uniform float sun_x : hint_range(0.35, 0.85) = 0.63;
uniform float sun_size : hint_range(0.04, 0.22) = 0.13;
uniform vec3 sun_color_top : source_color = vec3(1.0, 0.95, 0.4);
uniform vec3 sun_color_bot : source_color = vec3(1.0, 0.2, 0.08);
uniform float sun_glow : hint_range(0.0, 1.5) = 0.6;

// ── Grid ──
uniform vec3 grid_color : source_color = vec3(1.0, 0.08, 0.52);
uniform float camera_height : hint_range(0.2, 3.0) = 1.2;
uniform float grid_freq : hint_range(0.5, 5.0) = 2.0;
uniform float grid_line_w : hint_range(0.005, 0.08) = 0.028;
uniform float grid_brightness : hint_range(0.5, 6.0) = 2.5;
uniform float scroll_speed : hint_range(0.0, 2.0) = 0.5;
uniform vec3 ground_col : source_color = vec3(0.01, 0.0, 0.03);

// ── Stars ──
uniform float star_cutoff : hint_range(0.9, 0.99) = 0.94;

// ── Motion lights ──
uniform float light_speed : hint_range(0.05, 2.0) = 0.5;
uniform float light_brightness : hint_range(0.0, 2.0) = 0.5;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = UV;
	// width / height  (e.g. 1.78 for 16:9)
	float ar = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec3 col = vec3(0.0);

	// Sun centre sits so the bottom edge roughly touches the horizon
	float sun_cy = horizon - sun_size * 0.82;

	if (uv.y <= horizon) {
		// ════════════════════════ SKY ════════════════════════
		float t = uv.y / horizon;
		col = (t < 0.5)
			? mix(sky_top, sky_mid, t * 2.0)
			: mix(sky_mid, sky_low, (t - 0.5) * 2.0);

		// Subtle right-side ambient
		col += vec3(0.04, 0.0, 0.06) * smoothstep(0.3, 0.9, uv.x) * t;

		// ── Sun ────────────────────────────────────────────
		vec2 sd = vec2((uv.x - sun_x) * ar, uv.y - sun_cy);
		float sun_dist = length(sd);

		// Outer haze (always)
		float haze = exp(-sun_dist * 5.5 / sun_size) * sun_glow;
		col += vec3(1.0, 0.45, 0.18) * haze;

		if (sun_dist < sun_size) {
			float ny = (uv.y - (sun_cy - sun_size)) / (2.0 * sun_size); // 0 top, 1 bottom
			vec3 sc = mix(sun_color_top, sun_color_bot, clamp(ny, 0.0, 1.0));
			float edge = smoothstep(sun_size, sun_size - 0.005, sun_dist);

			// Horizontal slices — gaps widen toward bottom
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
			col = mix(col, sc * 1.6, edge * slice_mask);
		}

		// ── Stars ──────────────────────────────────────────
		if (uv.y < horizon * 0.82) {
			vec2 cell = floor(uv * vec2(140.0, 70.0));
			float h = hash(cell);
			if (h > star_cutoff) {
				vec2 soff = vec2(hash(cell + 111.0), hash(cell + 222.0));
				vec2 sp   = (cell + soff) / vec2(140.0, 70.0);
				float sd2  = length((uv - sp) * vec2(ar, 1.0));
				float twinkle = sin(TIME * (1.5 + h * 4.0) + h * 6.283) * 0.5 + 0.5;
				float b = smoothstep(0.003, 0.0, sd2) * (0.2 + 0.8 * twinkle);
				// Brighter on right side
				b *= 0.6 + uv.x * 0.8;
				// Dim near sun
				float sun_prox = length(vec2((uv.x - sun_x) * ar, uv.y - sun_cy));
				b *= smoothstep(sun_size * 1.5, sun_size * 3.0, sun_prox);
				col += vec3(0.85, 0.85, 1.05) * b;
			}
		}

	} else {
		// ════════════════════════ GROUND ════════════════════
		float v = uv.y - horizon;
		float persp = camera_height / max(v, 0.001);

		float wx = (uv.x - 0.5) * persp;
		float wz = persp + TIME * scroll_speed;

		// Grid lines with perspective-aware antialiasing
		float gx_w = wx * grid_freq;
		float gz_w = wz * grid_freq;
		float gx = abs(fract(gx_w) - 0.5);
		float gz = abs(fract(gz_w) - 0.5);
		float fwx = fwidth(gx_w) * 1.0;
		float fwz = fwidth(gz_w) * 1.0;
		float lx = 1.0 - smoothstep(grid_line_w - fwx, grid_line_w + fwx, gx);
		float lz = 1.0 - smoothstep(grid_line_w - fwz, grid_line_w + fwz, gz);
		float grid_val = max(lx, lz);

		// Fade near horizon (prevent aliasing) and at very bottom
		float fade = smoothstep(0.0, 0.05, v);

		col = ground_col;
		col += grid_color * grid_val * grid_brightness * fade;

		// Horizon glow band
		float h_glow = exp(-v * 30.0) * 0.4;
		col += vec3(0.8, 0.2, 0.5) * h_glow;

		// Sun reflection on ground
		float refl_x = abs(uv.x - sun_x);
		float refl = exp(-refl_x * 6.0 * ar) * exp(-v * 8.0) * 0.35;
		col += vec3(1.0, 0.5, 0.2) * refl;

		// ── Motion point lights ───────────────────────────
		for (int i = 0; i < 8; i++) {
			float fi = float(i);
			// Lanes biased to the right
			float lane = (hash(vec2(fi * 7.13, 42.7)) - 0.2) * 5.0;
			float phase = hash(vec2(fi * 3.31, 99.1));
			float spd = light_speed * (0.35 + hash(vec2(fi * 5.17, 77.3)) * 0.9);
			float cycle = fract(phase + TIME * spd * 0.08);
			float lz = 0.5 + cycle * 14.0;

			float pv = camera_height / lz;
			float py = horizon + pv;
			float px = 0.5 + lane / lz;

			if (py > horizon && py < 1.0 && px > -0.05 && px < 1.05) {
				vec2 ld = vec2((uv.x - px) * ar, uv.y - py);
				float d = length(ld);
				float sz = 0.005 + 0.018 / lz;
				float g = exp(-d / sz) * light_brightness / (1.0 + lz * 0.15);
				vec3 lc = mix(grid_color, vec3(0.25, 0.55, 1.0), hash(vec2(fi, 55.5)));
				col += lc * g * fade;
			}
		}
	}

	COLOR = vec4(col, 1.0);
}
