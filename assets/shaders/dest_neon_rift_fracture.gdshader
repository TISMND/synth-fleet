shader_type canvas_item;
// Neon Void Rift — Approach C: Jagged fractures/cracks in space leaking neon energy.
// Lightning-style tears with volumetric pink glow, grid visible through cracks.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 3.0;
uniform vec3 bg_color : source_color = vec3(0.01, 0.0, 0.03);
uniform vec3 crack_color : source_color = vec3(1.0, 0.1, 0.55);
uniform vec3 glow_color : source_color = vec3(0.7, 0.0, 0.35);
uniform float crack_width : hint_range(0.002, 0.02) = 0.006;
uniform float glow_spread : hint_range(0.01, 0.15) = 0.05;
uniform float pulse_speed : hint_range(0.0, 3.0) = 1.0;
uniform float cloud_intensity : hint_range(0.0, 1.0) = 0.35;

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
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p *= 2.1; a *= 0.5;
	}
	return v;
}

// Worley-style distance for crack pattern
float crack_noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	float d1 = 1.0, d2 = 1.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 n = vec2(float(x), float(y));
			vec2 pt = vec2(hash(i + n + 0.0), hash(i + n + 57.0));
			pt = 0.5 + 0.5 * sin(6.2832 * pt);
			float d = length(n + pt - f);
			if (d < d1) { d2 = d1; d1 = d; }
			else if (d < d2) { d2 = d; }
		}
	}
	return d2 - d1; // Edge distance — thin = crack
}

void fragment() {
	vec2 uv = UV;
	float ar = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec3 col = bg_color;

	// ── Background nebula haze ──
	vec2 neb_uv = uv * 3.5 + vec2(TIME * 0.01, TIME * 0.008);
	float neb = fbm(neb_uv) * 0.5;
	neb *= cloud_intensity;
	col += glow_color * neb * 0.3;

	// ── Main crack network ──
	// Two scales of cracks for variety
	float crack_val = 0.0;
	float glow_val = 0.0;

	for (int scale = 0; scale < 3; scale++) {
		float s = (scale == 0) ? 3.0 : (scale == 1) ? 5.5 : 9.0;
		float w = (scale == 0) ? crack_width * 1.5 : (scale == 1) ? crack_width : crack_width * 0.7;
		float weight = (scale == 0) ? 1.0 : (scale == 1) ? 0.7 : 0.4;

		vec2 crack_uv = uv * s * vec2(ar, 1.0) + float(scale) * 33.0;
		float cn = crack_noise(crack_uv);

		// Crack core
		float core = smoothstep(w, w * 0.1, cn);
		// Glow around crack
		float glow = exp(-cn / glow_spread) * 0.5;

		// Pulse along cracks
		float pulse = sin(TIME * pulse_speed * (1.0 + float(scale) * 0.3) + uv.y * 10.0 + uv.x * 7.0) * 0.3 + 0.7;

		crack_val += core * weight * pulse;
		glow_val += glow * weight * pulse;
	}

	// Central concentration — cracks stronger near center
	vec2 center = vec2(0.5, 0.48);
	float cdist = length((uv - center) * vec2(ar, 1.0));
	float center_focus = smoothstep(0.5, 0.1, cdist);
	float outer_focus = smoothstep(0.0, 0.15, cdist);
	float focus = mix(0.3, 1.0, center_focus) * outer_focus;

	col += crack_color * crack_val * hdr_intensity * 1.5 * focus;
	col += glow_color * glow_val * hdr_intensity * 0.4 * focus;

	// ── Grid visible through the main cracks ──
	if (crack_val > 0.1) {
		float gx = abs(fract(uv.x * 25.0 * ar) - 0.5);
		float gy = abs(fract(uv.y * 25.0) - 0.5);
		float grid = max(smoothstep(0.08, 0.0, gx), smoothstep(0.08, 0.0, gy));
		float grid_scroll = sin(uv.y * 50.0 - TIME * 2.0) * 0.15 + 0.85;
		col += crack_color * grid * crack_val * 0.4 * hdr_intensity * grid_scroll * focus;
	}

	// ── Central void glow (the rift itself) ──
	float void_glow = exp(-cdist * 8.0) * 0.6;
	col += crack_color * void_glow * hdr_intensity * 0.3;

	// Flickering energy at center
	float flicker = sin(TIME * 5.0) * 0.15 + sin(TIME * 8.3) * 0.1 + 0.75;
	float center_bright = exp(-cdist * 20.0) * flicker;
	col += crack_color * center_bright * hdr_intensity * 0.8;

	// ── Cloud wisps ──
	vec2 cloud_uv = uv * 5.0 + vec2(TIME * 0.03, -TIME * 0.02);
	float cloud = fbm(cloud_uv) * fbm(cloud_uv * 1.2 + 4.0);
	cloud = smoothstep(0.1, 0.35, cloud) * cloud_intensity;
	cloud *= smoothstep(0.6, 0.15, cdist); // near center
	col += glow_color * cloud * hdr_intensity * 0.5;

	// ── Stars ──
	for (int layer = 0; layer < 2; layer++) {
		float gs = (layer == 0) ? 90.0 : 140.0;
		float lo = float(layer) * 300.0;
		vec2 cell = floor(uv * vec2(gs, gs * 0.5));
		float h = hash(cell + lo);
		if (h > 0.94) {
			vec2 soff = vec2(hash(cell + lo + 111.0), hash(cell + lo + 222.0));
			vec2 sp = (cell + soff) / vec2(gs, gs * 0.5);
			float d_star = length((uv - sp) * vec2(ar, 1.0));
			float tw = 0.7 + 0.3 * sin(TIME * (1.0 + h * 3.0) + h * 6.28);
			float star = exp(-d_star * d_star / 0.000004) * tw;
			star *= smoothstep(0.08, 0.25, cdist);
			col += vec3(0.7, 0.8, 1.0) * star * 1.5;
		}
	}

	COLOR = vec4(col, 1.0);
}
