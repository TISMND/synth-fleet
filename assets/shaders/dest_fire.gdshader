shader_type canvas_item;
// Fire Destination — Radiant fire with NO central sphere/circle.
// Just rays, prominences, drifting plasma wisps, and eruption hotspots.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 3.5;
uniform vec3 bg_color : source_color = vec3(0.02, 0.0, 0.0);
uniform vec3 fire_hot : source_color = vec3(1.0, 0.85, 0.3);
uniform vec3 fire_mid : source_color = vec3(1.0, 0.35, 0.05);
uniform vec3 fire_cool : source_color = vec3(0.5, 0.05, 0.0);
uniform float corona_size : hint_range(0.05, 0.4) = 0.18;
uniform float flare_intensity : hint_range(0.0, 3.0) = 1.5;
uniform float wisp_scale : hint_range(1.0, 6.0) = 3.0;
uniform float wisp_speed : hint_range(0.0, 1.0) = 0.3;
uniform float ember_density : hint_range(0.0, 1.0) = 0.6;
uniform float ray_count : hint_range(3.0, 10.0) = 6.0;

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
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 6; i++) { v += a * vnoise(p); p = rot * p * 2.1; a *= 0.48; }
	return v;
}

void fragment() {
	vec2 uv = UV;
	float ar = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 center = vec2(0.5, 0.48);
	vec2 d = vec2((uv.x - center.x) * ar, uv.y - center.y);
	float dist = length(d);
	float angle = atan(d.y, d.x);
	vec3 col = bg_color;

	// ── Central radiance (soft, no hard edge) ──
	float core_glow = exp(-dist * dist / (corona_size * corona_size * 0.3));
	col += fire_mid * core_glow * hdr_intensity * 0.4;
	float inner_glow = exp(-dist * dist / (corona_size * corona_size * 0.08));
	col += fire_hot * inner_glow * hdr_intensity * 0.3;

	// ── Radial flare rays ──
	int rc = int(ray_count);
	for (int i = 0; i < 10; i++) {
		if (i >= rc) break;
		float fi = float(i);
		float ray_base_a = fi * 6.2832 / ray_count;
		// Slow wander
		float ray_a = ray_base_a + sin(TIME * 0.2 + fi * 1.7) * 0.3;
		float da = abs(mod(angle - ray_a + PI, 6.2832) - PI);

		// Width varies with FBM
		float rw = 0.08 + fbm(vec2(fi * 3.0 + 1.0, TIME * 0.08)) * 0.1;

		// Length varies
		float ray_length = corona_size * (1.5 + fbm(vec2(fi * 5.0, TIME * 0.12)) * 1.5);
		float ray_falloff = exp(-dist / ray_length);

		float ray = exp(-da * da / (rw * rw)) * ray_falloff;

		// Color shifts along ray: hot near center, cool at tips
		float temp = smoothstep(ray_length, 0.0, dist);
		vec3 ray_col = mix(fire_cool, mix(fire_mid, fire_hot, temp), temp);

		col += ray_col * ray * flare_intensity * hdr_intensity * 0.35;
	}

	// ── Prominence arcs ──
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		float arc_a = fi * 1.257 + TIME * 0.05 + sin(TIME * 0.25 + fi) * 0.5;
		vec2 arc_dir = vec2(cos(arc_a), sin(arc_a));
		float along = dot(d, arc_dir);
		float perp = length(d - arc_dir * along);

		float arc_start = 0.02 + hash(vec2(fi, 10.0)) * 0.03;
		float arc_h = 0.06 + sin(TIME * 0.35 + fi * 2.3) * 0.03;
		float arc_end = arc_start + arc_h;

		if (along > arc_start && along < arc_end * 1.3) {
			float t = (along - arc_start) / max(arc_end * 1.3 - arc_start, 0.001);
			float expected = sin(t * PI) * (0.015 + fi * 0.006);
			float ad = abs(perp - expected);
			float arc = exp(-ad * ad / 0.00003);
			arc *= smoothstep(0.0, 0.15, t) * smoothstep(1.0, 0.7, t);
			vec3 arc_col = mix(fire_mid, fire_hot, smoothstep(0.5, 0.0, t));
			col += arc_col * arc * flare_intensity * hdr_intensity * 0.4;
		}
	}

	// ── Drifting plasma wisps (FBM clouds, no hard boundary) ──
	vec2 wisp_uv = d * wisp_scale;
	// Multiple layers drifting in different directions
	vec2 drift1 = wisp_uv + TIME * wisp_speed * vec2(0.3, -0.5);
	float w1 = fbm(drift1 * 2.0);
	float w2 = fbm(drift1 * 2.5 + 4.0);
	float wisp1 = w1 * w2;
	wisp1 = smoothstep(0.08, 0.4, wisp1);
	// Fade with distance from center (organic falloff)
	float wisp_fade = exp(-dist * dist / (corona_size * corona_size * 1.5));
	col += fire_cool * wisp1 * wisp_fade * hdr_intensity * 0.5;

	vec2 drift2 = wisp_uv * 0.8 + TIME * wisp_speed * vec2(-0.2, -0.4) + 10.0;
	float w3 = fbm(drift2 * 1.8);
	float w4 = fbm(drift2 * 2.2 + 7.0);
	float wisp2 = w3 * w4;
	wisp2 = smoothstep(0.1, 0.35, wisp2);
	float wisp_fade2 = exp(-dist * dist / (corona_size * corona_size * 2.0));
	col += fire_mid * 0.5 * wisp2 * wisp_fade2 * hdr_intensity * 0.35;

	// Third layer — hotter, closer to center
	vec2 drift3 = wisp_uv * 1.5 + TIME * wisp_speed * vec2(0.15, 0.3) + 20.0;
	float wisp3 = fbm(drift3 * 3.0) * fbm(drift3 * 2.0 + 3.0);
	wisp3 = smoothstep(0.12, 0.4, wisp3);
	float wisp_fade3 = exp(-dist * dist / (corona_size * corona_size * 0.5));
	col += fire_hot * 0.4 * wisp3 * wisp_fade3 * hdr_intensity * 0.4;

	// ── Floating ember particles ──
	if (ember_density > 0.01) {
		for (int i = 0; i < 30; i++) {
			float fi = float(i);
			if (hash(vec2(fi * 7.13, 42.0)) > ember_density) continue;

			float phase = hash(vec2(fi * 3.31, 99.0));
			float lifetime = fract(phase + TIME * (0.1 + hash(vec2(fi, 55.0)) * 0.15));
			// Embers drift outward from center in random directions
			float ember_a = hash(vec2(fi * 2.0, 77.0)) * 6.28;
			float ember_r = lifetime * corona_size * 2.5;
			// Gentle wander
			float wx = sin(lifetime * 5.0 + fi * 2.0) * 0.02;
			float wy = cos(lifetime * 4.0 + fi * 3.0) * 0.02;
			vec2 ep = center + vec2((cos(ember_a) * ember_r + wx) / ar, sin(ember_a) * ember_r + wy);

			float ed = length((uv - ep) * vec2(ar, 1.0));
			float ember = exp(-ed * ed / 0.00002);
			float alpha = smoothstep(0.0, 0.1, lifetime) * smoothstep(1.0, 0.5, lifetime);
			vec3 ecol = mix(fire_hot, fire_cool, lifetime);
			col += ecol * ember * alpha * hdr_intensity * 0.7;
		}
	}

	COLOR = vec4(col, 1.0);
}
