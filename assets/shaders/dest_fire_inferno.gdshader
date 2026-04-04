shader_type canvas_item;
// Fire Destination — Approach A: Turbulent inferno maw.
// Chaotic FBM fire billowing from a dark volcanic opening, rising embers.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 3.5;
uniform vec3 bg_color : source_color = vec3(0.02, 0.0, 0.0);
uniform vec3 fire_color_hot : source_color = vec3(1.0, 0.9, 0.3);
uniform vec3 fire_color_mid : source_color = vec3(1.0, 0.35, 0.05);
uniform vec3 fire_color_cool : source_color = vec3(0.5, 0.05, 0.0);
uniform float fire_speed : hint_range(0.1, 2.0) = 0.8;
uniform float fire_scale : hint_range(1.0, 6.0) = 3.0;
uniform float turbulence : hint_range(0.0, 1.0) = 0.6;
uniform float maw_size : hint_range(0.05, 0.25) = 0.12;
uniform float ember_density : hint_range(0.0, 1.0) = 0.5;

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
	for (int i = 0; i < 6; i++) {
		v += a * vnoise(p);
		p = rot * p * 2.1;
		a *= 0.48;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	float ar = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 center = vec2(0.5, 0.55);
	vec2 d = vec2((uv.x - center.x) * ar, uv.y - center.y);
	float dist = length(d);
	float angle = atan(d.y, d.x);
	vec3 col = bg_color;

	// ── Fire field (rises upward from center) ──
	vec2 fire_uv = uv * fire_scale;
	// Upward motion + turbulence displacement
	fire_uv.y -= TIME * fire_speed;
	fire_uv.x += sin(uv.y * 8.0 + TIME * 1.5) * turbulence * 0.15;

	float fire1 = fbm(fire_uv);
	float fire2 = fbm(fire_uv * 1.3 + vec2(3.7, 1.2));
	float fire = fire1 * fire2;

	// Shape fire: stronger near center-bottom, fading outward/upward
	float shape = smoothstep(0.5, 0.0, dist - maw_size);
	// Upward bias — fire rises
	float rise = smoothstep(0.1, -0.25, d.y);
	// Wider at base
	float width = smoothstep(0.35 * ar, 0.05 * ar, abs(d.x)) * rise;
	float fire_mask = max(shape, width * 0.7);

	fire = smoothstep(0.08, 0.5, fire) * fire_mask;

	// Color gradient by intensity
	vec3 fire_col;
	if (fire > 0.6) {
		fire_col = mix(fire_color_mid, fire_color_hot, (fire - 0.6) / 0.4);
	} else if (fire > 0.25) {
		fire_col = mix(fire_color_cool, fire_color_mid, (fire - 0.25) / 0.35);
	} else {
		fire_col = fire_color_cool * (fire / 0.25);
	}

	col += fire_col * fire * hdr_intensity;

	// ── Maw (dark volcanic opening) ──
	float maw_dist = length(vec2(d.x * 1.2, d.y + 0.02));
	float maw = smoothstep(maw_size, maw_size * 0.4, maw_dist);
	// Inner glow at rim
	float maw_rim = smoothstep(maw_size * 0.3, maw_size, maw_dist) * smoothstep(maw_size * 1.3, maw_size, maw_dist);
	col = mix(col, bg_color * 0.2, maw * 0.8);
	col += fire_color_hot * maw_rim * hdr_intensity * 0.5;

	// ── Ambient heat glow ──
	float heat = exp(-dist * 4.0) * 0.3;
	col += fire_color_mid * heat * hdr_intensity * 0.3;

	// ── Embers (rising particles) ──
	if (ember_density > 0.01) {
		for (int i = 0; i < 30; i++) {
			float fi = float(i);
			float eh = hash(vec2(fi * 7.13, 42.0));
			if (eh > ember_density) continue;

			// Start near maw, rise upward with drift
			float phase = hash(vec2(fi * 3.31, 99.0));
			float lifetime = fract(phase + TIME * (0.15 + hash(vec2(fi, 55.0)) * 0.2));
			float ex = center.x + (hash(vec2(fi * 5.0, 11.0)) - 0.5) * 0.25;
			ex += sin(lifetime * 6.0 + fi) * 0.03; // drift
			float ey = center.y - lifetime * 0.5;

			vec2 ep = vec2(ex, ey);
			float ed = length((uv - ep) * vec2(ar, 1.0));
			float ember = exp(-ed * ed / 0.00003);
			// Fade in, then out
			float alpha = smoothstep(0.0, 0.1, lifetime) * smoothstep(1.0, 0.6, lifetime);
			// Color shifts from hot to cool as it rises
			vec3 ecol = mix(fire_color_hot, fire_color_cool, lifetime);
			col += ecol * ember * alpha * hdr_intensity * 0.6;
		}
	}

	// ── Smoke wisps at edges ──
	vec2 smoke_uv = uv * 2.5 + vec2(TIME * 0.02, -TIME * 0.05);
	float smoke = fbm(smoke_uv);
	smoke = smoothstep(0.45, 0.65, smoke) * 0.15;
	float smoke_mask = smoothstep(0.05, 0.2, dist) * smoothstep(0.5, 0.25, dist);
	smoke_mask *= smoothstep(center.y, center.y - 0.3, uv.y); // above center
	col += fire_color_cool * 0.5 * smoke * smoke_mask * hdr_intensity * 0.3;

	COLOR = vec4(col, 1.0);
}
