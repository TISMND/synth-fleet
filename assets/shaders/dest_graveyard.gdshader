shader_type canvas_item;
// Graveyard — Dark wreckage field. 7 drifting ship silhouettes at
// different scales and rotations against a dim nebula. Occasional
// emergency lights blink on some hulks, a few have venting plasma.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 3.0;
uniform vec3 bg_color : source_color = vec3(0.008, 0.005, 0.012);
uniform vec3 neb_color : source_color = vec3(0.25, 0.15, 0.35);
uniform vec3 hulk_color : source_color = vec3(0.08, 0.09, 0.11);
uniform vec3 rim_color : source_color = vec3(0.3, 0.25, 0.4);
uniform vec3 emergency_color : source_color = vec3(1.0, 0.35, 0.2);
uniform vec3 vent_color : source_color = vec3(0.55, 0.85, 1.0);
uniform float drift_speed : hint_range(0.0, 0.4) = 0.04;
uniform float neb_intensity : hint_range(0.0, 2.0) = 0.75;

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
	for (int i = 0; i < 5; i++) { v += a * vnoise(p); p *= 2.07; a *= 0.5; }
	return v;
}

float sd_rrect(vec2 p, vec2 hs, float r) {
	vec2 q = abs(p) - hs + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

vec2 rot(vec2 p, float a) {
	float c = cos(a), s = sin(a);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

void fragment() {
	vec2 uv = UV;
	float ar = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 cen = vec2(0.5, 0.5);
	vec2 d = vec2((uv.x - cen.x) * ar, uv.y - cen.y);
	vec3 col = bg_color;

	// ── Background nebula (dim purple/magenta) ──
	vec2 neb_uv = uv * 2.8 + vec2(TIME * drift_speed * 0.5, TIME * drift_speed * 0.3);
	float neb1 = fbm(neb_uv);
	float neb2 = fbm(neb_uv * 1.8 + vec2(5.0, 3.0));
	float neb = neb1 * 0.7 + neb2 * 0.3;
	neb = smoothstep(0.2, 0.8, neb);
	col += neb_color * neb * neb_intensity * 0.5 * hdr_intensity;

	// Brighter pockets
	float hot = pow(neb, 4.0);
	col += vec3(0.6, 0.4, 0.8) * hot * neb_intensity * 0.25 * hdr_intensity;

	// ══════════════════════════════════════════════
	// HULKS — 7 drifting wrecks
	// ══════════════════════════════════════════════
	// Hardcoded arrangement for composition control
	vec2 positions[7] = vec2[7](
		vec2(-0.33, -0.18),
		vec2(0.28, 0.22),
		vec2(-0.12, 0.32),
		vec2(0.35, -0.28),
		vec2(-0.42, 0.15),
		vec2(0.08, -0.08),
		vec2(-0.05, -0.38)
	);
	float rotations[7] = float[7](0.3, -0.7, 1.1, -0.4, 0.6, 1.9, -0.2);
	vec2 sizes[7] = vec2[7](
		vec2(0.08, 0.022),
		vec2(0.055, 0.016),
		vec2(0.07, 0.02),
		vec2(0.045, 0.014),
		vec2(0.09, 0.028),
		vec2(0.035, 0.012),
		vec2(0.06, 0.018)
	);

	for (int i = 0; i < 7; i++) {
		float fi = float(i);
		// Slow drift
		vec2 drift = vec2(sin(TIME * drift_speed + fi * 1.3), cos(TIME * drift_speed * 0.8 + fi * 0.7)) * 0.01;
		vec2 slow_rot = vec2(TIME * drift_speed * 0.15 * (hash(vec2(fi, 3.0)) > 0.5 ? 1.0 : -1.0));
		vec2 pos = positions[i] + drift;
		float rot_a = rotations[i] + slow_rot.x;
		vec2 local = rot(d - pos, -rot_a);
		vec2 hs = sizes[i];

		// Main hull (elongated capsule)
		float hull_sd = sd_rrect(local, hs, hs.y * 0.8);

		// Add a secondary bulge (bridge/module) off one end
		vec2 bulge_off = vec2(hs.x * 0.3, -hs.y * 0.8);
		float bulge_sd = sd_rrect(local - bulge_off, vec2(hs.x * 0.25, hs.y * 0.6), hs.y * 0.3);
		float combined_sd = min(hull_sd, bulge_sd);

		// Break it: carve off a chunk from midsection (damage)
		vec2 break_off = vec2(-hs.x * 0.2, hs.y * 0.4);
		float break_sd = sd_rrect(local - break_off, vec2(hs.x * 0.2, hs.y * 0.9), hs.y * 0.3);
		// Only some ships broken (50%)
		if (hash(vec2(fi, 17.0)) > 0.5) {
			combined_sd = max(combined_sd, -break_sd);
		}

		if (combined_sd < 0.0) {
			// Dark silhouette with subtle vertical gradient (dust light from top)
			float light_grad = 0.6 + 0.4 * smoothstep(hs.y, -hs.y, local.y);
			col = hulk_color * light_grad;
			// Panel detail lines
			float panel_x = step(0.5, fract(local.x * 180.0));
			float panel_y = step(0.5, fract(local.y * 300.0));
			col *= (0.85 + panel_x * 0.15 + panel_y * 0.08);
			// Grime noise
			col *= (0.8 + vnoise(local * 150.0) * 0.4);
		}

		// Rim light (dim, lit by nebula)
		float rim_w = 0.0018;
		float rim = smoothstep(rim_w, rim_w * 0.2, abs(combined_sd));
		// Nebula-lit side (top-ish)
		float lit_side = 0.4 + 0.6 * smoothstep(hs.y, -hs.y, local.y);
		col += rim_color * rim * lit_side * hdr_intensity * 0.55;
		float rim_halo = exp(-abs(combined_sd) * 300.0);
		col += rim_color * rim_halo * lit_side * hdr_intensity * 0.12;

		// Emergency light on some hulks
		if (hash(vec2(fi, 21.0)) > 0.35) {
			vec2 light_local = vec2(hs.x * 0.6, 0.0);
			vec2 light_pos = pos + rot(light_local, rot_a);
			float ld = length(d - light_pos);
			float blink = step(0.7, sin(TIME * (1.5 + fi * 0.3) + fi * 2.0) * 0.5 + 0.5);
			blink *= pow(max(sin(TIME * 4.0 + fi * 1.1), 0.0), 6.0);
			col += emergency_color * exp(-ld * ld / 0.0000055) * blink * hdr_intensity * 2.5;
			col += emergency_color * exp(-ld * ld / 0.0005) * blink * hdr_intensity * 0.25;
		}

		// Venting plasma leak on some broken hulks
		if (hash(vec2(fi, 17.0)) > 0.5 && hash(vec2(fi, 25.0)) > 0.4) {
			vec2 vent_local = vec2(-hs.x * 0.2, hs.y * 0.4);
			vec2 vent_world = pos + rot(vent_local, rot_a);
			// Plasma jet direction (perpendicular to hull)
			vec2 jet_dir_local = vec2(0.0, 1.0);
			vec2 jet_dir = rot(jet_dir_local, rot_a);
			vec2 jet_end = vent_world + jet_dir * 0.04;
			// Distance to segment
			vec2 ab = jet_end - vent_world;
			float len2 = dot(ab, ab);
			float t = clamp(dot(d - vent_world, ab) / len2, 0.0, 1.0);
			vec2 closest = vent_world + ab * t;
			float vd = length(d - closest);
			// Width tapers out
			float width = mix(0.004, 0.012, t);
			float jet = exp(-vd * vd / (width * width));
			// Flicker
			float vent_flick = 0.7 + 0.3 * vnoise(vec2(fi * 10.0, TIME * 8.0));
			// Fade at tip
			float tip_fade = smoothstep(1.0, 0.2, t);
			col += vent_color * jet * tip_fade * vent_flick * hdr_intensity * 0.8;
		}
	}

	// ── Dust/debris haze streaks ──
	float dust = fbm(d * vec2(30.0, 4.0) + TIME * vec2(drift_speed * 3.0, 0.0));
	dust = smoothstep(0.55, 0.85, dust);
	col += rim_color * dust * 0.1 * hdr_intensity;

	// ── Background stars ──
	for (int layer = 0; layer < 2; layer++) {
		float gs = (layer == 0) ? 100.0 : 160.0;
		float lo = float(layer) * 300.0;
		vec2 cell_s = floor(uv * vec2(gs, gs * 0.5));
		float h = hash(cell_s + lo);
		if (h > 0.95) {
			vec2 soff = vec2(hash(cell_s + lo + 111.0), hash(cell_s + lo + 222.0));
			vec2 sp = (cell_s + soff) / vec2(gs, gs * 0.5);
			float d_star = length((uv - sp) * vec2(ar, 1.0));
			float tw = 0.7 + 0.3 * sin(TIME * (1.0 + h * 3.0) + h * 6.28);
			float star = exp(-d_star * d_star / 0.000004) * tw;
			col += vec3(0.75, 0.8, 1.0) * star * 1.1;
		}
	}

	COLOR = vec4(col, 1.0);
}
