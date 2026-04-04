shader_type canvas_item;
// Fluid Rift — Approach C: Flowing aurora curtains converging on a rift opening.
// Layered sine-wave curtains of light blue light, rippling and undulating.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 3.0;
uniform vec3 bg_color : source_color = vec3(0.0, 0.01, 0.04);
uniform vec3 aurora_color_a : source_color = vec3(0.15, 0.55, 1.0);
uniform vec3 aurora_color_b : source_color = vec3(0.3, 0.85, 0.95);
uniform vec3 aurora_color_c : source_color = vec3(0.05, 0.3, 0.7);
uniform float wave_speed : hint_range(0.0, 2.0) = 0.5;
uniform float wave_amplitude : hint_range(0.01, 0.15) = 0.06;
uniform float curtain_count : hint_range(2.0, 8.0) = 5.0;
uniform float curtain_sharpness : hint_range(1.0, 8.0) = 3.0;
uniform float rift_glow : hint_range(0.0, 2.0) = 0.8;

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
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p *= 2.0; a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	float ar = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 center = vec2(0.5, 0.48);
	vec3 col = bg_color;

	// ── Aurora curtains (vertical strips that undulate horizontally) ──
	float aurora_total = 0.0;
	vec3 aurora_col_total = vec3(0.0);
	int cc = int(curtain_count);

	for (int i = 0; i < 8; i++) {
		if (i >= cc) break;
		float fi = float(i);
		float base_x = 0.15 + fi * 0.7 / curtain_count;

		// Undulation — multiple sine waves
		float wave = sin(uv.y * 12.0 + TIME * wave_speed * (0.8 + fi * 0.2) + fi * 2.0) * wave_amplitude;
		wave += sin(uv.y * 20.0 - TIME * wave_speed * 0.6 + fi * 4.0) * wave_amplitude * 0.4;
		wave += sin(uv.y * 5.0 + TIME * wave_speed * 0.3 + fi * 1.5) * wave_amplitude * 0.7;

		// Noise-based displacement
		float noise_disp = (fbm(vec2(uv.y * 3.0 + fi * 5.0, TIME * 0.1)) - 0.5) * 0.08;

		float curtain_x = base_x + wave + noise_disp;
		float dx = abs(uv.x - curtain_x);

		// Sharp center, soft falloff
		float curtain = exp(-dx * dx * 800.0 * curtain_sharpness);
		// Softer glow around it
		float glow = exp(-dx * dx * 80.0);

		// Height-based intensity variation
		float height_var = fbm(vec2(fi * 3.0 + uv.y * 4.0, TIME * 0.08));
		height_var = smoothstep(0.3, 0.7, height_var);

		// Color cycling per curtain
		vec3 c;
		float t = fract(fi * 0.33 + TIME * 0.05);
		if (t < 0.33) c = mix(aurora_color_a, aurora_color_b, t * 3.0);
		else if (t < 0.66) c = mix(aurora_color_b, aurora_color_c, (t - 0.33) * 3.0);
		else c = mix(aurora_color_c, aurora_color_a, (t - 0.66) * 3.0);

		float val = (curtain * 1.0 + glow * 0.3) * height_var;
		aurora_col_total += c * val;
		aurora_total += val;
	}

	col += aurora_col_total * hdr_intensity * 0.6;

	// ── Central rift convergence ──
	vec2 d = vec2((uv.x - center.x) * ar, uv.y - center.y);
	float dist = length(d);

	// Curtains converge toward center — additional brightness
	float converge = exp(-dist * 6.0) * aurora_total;
	col += aurora_color_b * converge * hdr_intensity * 0.4;

	// Central rift glow
	float rift = exp(-dist * 10.0) * rift_glow;
	col += aurora_color_b * rift * hdr_intensity * 0.6;

	// Rift rim
	float rift_rim_dist = abs(dist - 0.06);
	float rim = exp(-rift_rim_dist * 40.0) * 0.4;
	float rim_pulse = sin(atan(d.y, d.x) * 8.0 + TIME * 1.5) * 0.2 + 0.8;
	col += aurora_color_a * rim * rim_pulse * hdr_intensity * 0.5;

	// ── Ambient shimmer ──
	float shimmer = fbm(uv * 8.0 + TIME * vec2(0.02, 0.01));
	shimmer = pow(shimmer, 3.0) * 0.3;
	col += aurora_color_c * shimmer * hdr_intensity * 0.15;

	// ── Stars ──
	for (int layer = 0; layer < 2; layer++) {
		float gs = (layer == 0) ? 90.0 : 140.0;
		float lo = float(layer) * 300.0;
		vec2 cell = floor(uv * vec2(gs, gs * 0.5));
		float h = hash(cell + lo);
		if (h > 0.95) {
			vec2 soff = vec2(hash(cell + lo + 111.0), hash(cell + lo + 222.0));
			vec2 sp = (cell + soff) / vec2(gs, gs * 0.5);
			float d_star = length((uv - sp) * vec2(ar, 1.0));
			float tw = 0.7 + 0.3 * sin(TIME * (1.0 + h * 3.0) + h * 6.28);
			float star = exp(-d_star * d_star / 0.000004) * tw;
			star *= smoothstep(0.0, 0.15, dist);
			col += vec3(0.6, 0.8, 1.0) * star * 1.2;
		}
	}

	COLOR = vec4(col, 1.0);
}
