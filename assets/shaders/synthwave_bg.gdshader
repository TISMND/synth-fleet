shader_type canvas_item;

// ── Sky ──
uniform vec3 sky_top : source_color = vec3(0.01, 0.0, 0.06);
uniform vec3 sky_mid : source_color = vec3(0.08, 0.0, 0.14);
uniform vec3 sky_low : source_color = vec3(0.18, 0.02, 0.25);
uniform float horizon : hint_range(0.3, 0.65) = 0.50;

// ── Sun ──
uniform float sun_x : hint_range(0.35, 0.85) = 0.63;
uniform float sun_size : hint_range(0.04, 0.22) = 0.13;
uniform vec3 sun_color_top : source_color = vec3(1.0, 0.95, 0.4);
uniform vec3 sun_color_bot : source_color = vec3(1.0, 0.2, 0.08);
uniform float sun_glow : hint_range(0.0, 2.0) = 0.6;

// ── Grid ──
uniform vec3 grid_color : source_color = vec3(1.0, 0.08, 0.52);
uniform float camera_height : hint_range(0.2, 3.0) = 1.2;
uniform float grid_freq : hint_range(0.5, 5.0) = 2.0;
uniform float grid_line_w : hint_range(0.001, 0.03) = 0.008;
uniform float grid_bloom_w : hint_range(0.01, 0.15) = 0.06;
uniform float grid_core_brightness : hint_range(1.0, 12.0) = 6.0;
uniform float grid_bloom_brightness : hint_range(0.5, 8.0) = 3.0;
uniform float scroll_speed : hint_range(0.0, 2.0) = 0.5;
uniform vec3 ground_col : source_color = vec3(0.01, 0.0, 0.03);

// ── Nebula ──
uniform vec3 accent_color : source_color = vec3(0.1, 0.8, 1.0);
uniform float nebula_intensity : hint_range(0.0, 0.5) = 0.12;
uniform float nebula_scale : hint_range(1.0, 8.0) = 3.5;
uniform float nebula_drift : hint_range(0.0, 0.1) = 0.015;

// ── Stars ──
uniform float star_cutoff : hint_range(0.85, 0.99) = 0.94;

// ── Shooting stars ──
uniform float shooting_star_rate : hint_range(0.0, 1.0) = 0.4;

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

void fragment() {
	vec2 uv = UV;
	float ar = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec3 col = vec3(0.0);

	float sun_cy = horizon - sun_size * 0.82;

	if (uv.y <= horizon) {
		// ════════════════════════ SKY ════════════════════════
		float t = uv.y / horizon;
		col = (t < 0.5)
			? mix(sky_top, sky_mid, t * 2.0)
			: mix(sky_mid, sky_low, (t - 0.5) * 2.0);

		col += vec3(0.04, 0.0, 0.06) * smoothstep(0.3, 0.9, uv.x) * t;

		// ── Nebula wisps ───────────────────────────────────
		if (nebula_intensity > 0.001) {
			vec2 neb_uv = uv * nebula_scale + vec2(TIME * nebula_drift, TIME * nebula_drift * 0.6);
			float neb = fbm(neb_uv) * fbm(neb_uv * 1.4 + 5.3);
			neb = smoothstep(0.12, 0.45, neb) * nebula_intensity;
			neb *= smoothstep(0.05, 0.6, uv.x);
			neb *= smoothstep(horizon * 0.95, horizon * 0.5, uv.y);
			col += accent_color * neb * 2.0;

			vec2 neb_uv2 = uv * nebula_scale * 0.7 + vec2(-TIME * nebula_drift * 0.8, TIME * nebula_drift * 0.3) + 20.0;
			float neb2 = fbm(neb_uv2) * fbm(neb_uv2 * 1.2 + 8.1);
			neb2 = smoothstep(0.18, 0.5, neb2) * nebula_intensity * 0.5;
			neb2 *= smoothstep(0.2, 0.8, uv.x);
			neb2 *= smoothstep(horizon * 0.9, horizon * 0.4, uv.y);
			col += vec3(0.6, 0.1, 0.8) * neb2 * 1.5;
		}

		// ── Sun ────────────────────────────────────────────
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

		// ── Stars ──────────────────────────────────────────
		if (uv.y < horizon * 0.88) {
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
				col += vec3(0.85, 0.85, 1.05) * b * 2.5;
			}
		}

		// ── Shooting stars ─────────────────────────────────
		if (shooting_star_rate > 0.01) {
			for (int i = 0; i < 4; i++) {
				float fi = float(i);
				float period = 3.5 + fi * 2.7;
				float phase = hash(vec2(fi, 33.3));
				float cycle_t = fract(TIME / period + phase);
				float visible_window = 0.06 + shooting_star_rate * 0.06;
				if (cycle_t < visible_window) {
					float streak_t = cycle_t / visible_window;
					float cycle_id = floor(TIME / period + phase);
					float sx = hash(vec2(fi + cycle_id, 10.5)) * 0.5 + 0.35;
					float sy = hash(vec2(fi + cycle_id, 20.5)) * horizon * 0.5 + 0.02;
					vec2 start = vec2(sx, sy);
					// Downward-biased angle
					float angle = hash(vec2(fi + cycle_id, 30.5)) * 0.8 + 1.0;
					vec2 dir = vec2(cos(angle), sin(angle));
					vec2 head = start + dir * streak_t * 0.25;
					vec2 d_to = uv - head;
					float along = dot(d_to, dir);
					float perp = length(d_to - dir * along) * ar;
					float trail = 0.05 + shooting_star_rate * 0.04;
					if (along > -trail && along < 0.003 && perp < 0.002) {
						float bright = (1.0 - streak_t) * smoothstep(-trail, 0.0, along);
						col += vec3(1.0, 1.0, 1.2) * bright * 5.0;
					}
				}
			}
		}

	} else {
		// ════════════════════════ GROUND ════════════════════
		float v = uv.y - horizon;
		float persp = camera_height / max(v, 0.001);

		float wx = (uv.x - 0.5) * persp;
		float wz = persp + TIME * scroll_speed;

		float gx_w = wx * grid_freq;
		float gz_w = wz * grid_freq;
		float gx = abs(fract(gx_w) - 0.5);
		float gz = abs(fract(gz_w) - 0.5);
		float fwx = fwidth(gx_w);
		float fwz = fwidth(gz_w);

		// ── Slim white-hot core ──
		float core_x = 1.0 - smoothstep(grid_line_w - fwx * 0.5, grid_line_w + fwx * 0.5, gx);
		float core_z = 1.0 - smoothstep(grid_line_w - fwz * 0.5, grid_line_w + fwz * 0.5, gz);
		float core = max(core_x, core_z);

		// ── Wider pink bloom around lines ──
		float bloom_x = 1.0 - smoothstep(grid_line_w, grid_bloom_w + fwx, gx);
		float bloom_z = 1.0 - smoothstep(grid_line_w, grid_bloom_w + fwz, gz);
		float bloom = max(bloom_x, bloom_z);

		float fade = smoothstep(0.0, 0.05, v);

		col = ground_col;
		// Pink HDR bloom (wider, saturated)
		col += grid_color * bloom * grid_bloom_brightness * fade;
		// White-hot core on top (slim, bright)
		col += vec3(1.0, 0.9, 0.95) * core * grid_core_brightness * fade;

		// Horizon glow — pink
		float h_glow = exp(-v * 30.0) * 0.4;
		col += vec3(0.9, 0.15, 0.45) * h_glow * 3.0;

		// Sun reflection on ground
		float refl_x = abs(uv.x - sun_x);
		float refl = exp(-refl_x * 6.0 * ar) * exp(-v * 8.0) * 0.35;
		col += vec3(1.0, 0.5, 0.2) * refl * 2.0;

		// ── Motion point lights (toward viewer) ──────────
		for (int i = 0; i < 8; i++) {
			float fi = float(i);
			float lane = (hash(vec2(fi * 7.13, 42.7)) - 0.2) * 5.0;
			float phase = hash(vec2(fi * 3.31, 99.1));
			float spd = light_speed * (0.35 + hash(vec2(fi * 5.17, 77.3)) * 0.9);
			float cycle = fract(phase - TIME * spd * 0.08);
			float lz = 0.5 + cycle * 14.0;

			float pv = camera_height / lz;
			float py = horizon + pv;
			float px = 0.5 + lane / lz;

			if (py > horizon && py < 1.0 && px > -0.05 && px < 1.05) {
				vec2 ld = vec2((uv.x - px) * ar, uv.y - py);
				float d = length(ld);
				float sz = 0.005 + 0.018 / lz;
				float g = exp(-d / sz) * light_brightness / (1.0 + lz * 0.15);
				col += grid_color * g * fade * 2.5;
			}
		}
	}

	COLOR = vec4(col, 1.0);
}
