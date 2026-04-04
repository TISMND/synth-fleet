shader_type canvas_item;
// Fluid Rift — Spiral vortex center with aurora curtains and HDR ring pulses
// that illuminate geometric grid lines as they expand outward.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 3.0;
uniform vec3 bg_color : source_color = vec3(0.0, 0.01, 0.04);
uniform vec3 fluid_color : source_color = vec3(0.2, 0.6, 1.0);
uniform vec3 aurora_color : source_color = vec3(0.3, 0.85, 0.95);
uniform vec3 line_color : source_color = vec3(0.15, 0.5, 0.9);
uniform float vortex_radius : hint_range(0.05, 0.3) = 0.18;
uniform float swirl_speed : hint_range(0.0, 1.0) = 0.3;
uniform float curtain_count : hint_range(2.0, 8.0) = 5.0;
uniform float wave_amplitude : hint_range(0.01, 0.12) = 0.05;
uniform float line_density : hint_range(8.0, 35.0) = 16.0;
uniform float line_brightness : hint_range(0.2, 3.0) = 1.2;
uniform float pulse_speed : hint_range(0.1, 2.0) = 0.45;
uniform float pulse_count : hint_range(1.0, 8.0) = 4.0;
uniform float pulse_hdr : hint_range(1.0, 6.0) = 3.0;
uniform float drift_speed : hint_range(0.0, 0.3) = 0.06;

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
	for (int i = 0; i < 4; i++) { v += a * vnoise(p); p *= 2.0; a *= 0.5; }
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

	// ══════════════════════════════════════════════
	// LAYER 1: Aurora curtains (background)
	// ══════════════════════════════════════════════
	int cc = int(curtain_count);
	for (int i = 0; i < 8; i++) {
		if (i >= cc) break;
		float fi = float(i);
		float base_x = 0.12 + fi * 0.76 / curtain_count;

		float wave = sin(uv.y * 10.0 + TIME * swirl_speed * (0.6 + fi * 0.15) + fi * 2.0) * wave_amplitude;
		wave += sin(uv.y * 18.0 - TIME * swirl_speed * 0.4 + fi * 3.5) * wave_amplitude * 0.35;
		wave += sin(uv.y * 4.0 + TIME * swirl_speed * 0.2 + fi * 1.2) * wave_amplitude * 0.6;
		float noise_disp = (fbm(vec2(uv.y * 2.5 + fi * 5.0, TIME * 0.06)) - 0.5) * 0.06;

		float curtain_x = base_x + wave + noise_disp;
		float dx = abs(uv.x - curtain_x);

		// Use HDR values directly — let bloom handle the glow
		float curtain = exp(-dx * dx * 1500.0);

		float height_var = fbm(vec2(fi * 3.0 + uv.y * 3.0, TIME * 0.05));
		height_var = smoothstep(0.25, 0.7, height_var);

		vec3 c = mix(fluid_color, aurora_color, fract(fi * 0.4 + TIME * 0.03));

		float val = curtain * height_var;
		val *= smoothstep(vortex_radius * 0.5, vortex_radius * 1.8, abs(uv.x - center.x) * ar + abs(uv.y - center.y));
		col += c * val * hdr_intensity * 0.6;
	}

	// ══════════════════════════════════════════════
	// LAYER 2: Spiral vortex center
	// ══════════════════════════════════════════════
	float swirl_a = angle - dist * 10.0 + TIME * swirl_speed;
	float arms = sin(swirl_a * 3.0) * 0.5 + 0.5;
	arms = pow(arms, 2.0);

	vec2 turb_uv = vec2(swirl_a * 0.5, dist * 6.0) + TIME * vec2(0.0, -0.08);
	float turb = fbm(turb_uv * 2.0) * 0.25;
	arms = clamp(arms + turb - 0.12, 0.0, 1.0);

	float arm_fade = smoothstep(vortex_radius * 2.2, vortex_radius * 0.35, dist);
	float arm_outside = smoothstep(vortex_radius * 0.1, vortex_radius * 0.4, dist);
	arms *= arm_fade * arm_outside;
	col += fluid_color * arms * hdr_intensity * 0.5;

	// Core glow — HDR for bloom
	float core = exp(-dist * 10.0 / vortex_radius);
	col += aurora_color * core * hdr_intensity * 0.4;
	// Dark eye
	float eye = smoothstep(vortex_radius * 0.15, vortex_radius * 0.04, dist);
	col = mix(col, bg_color * 0.4, eye * 0.6);

	// ══════════════════════════════════════════════
	// LAYER 3: HDR ring pulses from center
	// ══════════════════════════════════════════════
	float radial = max(dist - vortex_radius * 0.3, 0.0);
	float ring_boost = 0.0;
	int pc = int(pulse_count);
	for (int i = 0; i < 8; i++) {
		if (i >= pc) break;
		float fi = float(i);
		float phase = fi / pulse_count;
		float wave_pos = fract(phase + TIME * pulse_speed * 0.12);
		float wave_radius = wave_pos * 0.55;
		float wave_match = abs(radial - wave_radius);
		float ring = exp(-wave_match * wave_match / 0.0007);
		float wave_fade = smoothstep(0.55, 0.02, wave_pos);
		ring_boost += ring * wave_fade;
	}
	ring_boost = min(ring_boost, 2.5);

	// Ambient HDR wash from rings (bloom picks this up)
	float ambient_mask = smoothstep(0.0, 0.04, radial) * smoothstep(0.55, 0.08, radial);
	col += aurora_color * ring_boost * 0.1 * hdr_intensity * pulse_hdr * 0.06 * ambient_mask;

	// ══════════════════════════════════════════════
	// LAYER 4: Geometric grid lines illuminated by rings
	// ══════════════════════════════════════════════
	vec2 grid_offset = vec2(sin(TIME * drift_speed * 0.6) * 0.008, cos(TIME * drift_speed) * 0.008);
	vec2 grid_uv = (uv + grid_offset) * line_density;
	vec2 cell_id = floor(grid_uv);
	vec2 cell_f = fract(grid_uv);

	float cell_dist = length((cell_id + 0.5) / line_density - center);
	float base_activity = smoothstep(0.5, 0.03, cell_dist);
	float thin_chance = smoothstep(0.07, 0.4, cell_dist);
	float sparse_mask = step(thin_chance * 0.7, hash(cell_id + 200.0));
	float activity = base_activity * sparse_mask;
	activity *= smoothstep(0.0, 0.04, cell_dist - 0.02);

	float h_active = step(0.35, hash(cell_id)) * activity;
	float v_active = step(0.35, hash(cell_id + 77.0)) * activity;
	float near_center = smoothstep(0.1, 0.03, cell_dist);
	h_active = max(h_active, near_center);
	v_active = max(v_active, near_center);

	float line_w = 0.05;
	float h_line = smoothstep(line_w, line_w * 0.12, abs(cell_f.y - 0.5)) * h_active;
	float v_line = smoothstep(line_w, line_w * 0.12, abs(cell_f.x - 0.5)) * v_active;
	float line_core = max(h_line, v_line);

	// Lines are dim by default, lit up by passing HDR ring pulses
	float illuminated = 0.1 + ring_boost * pulse_hdr;
	col += line_color * line_core * illuminated * line_brightness * hdr_intensity * 0.12;

	// Intersection nodes
	float at_int = smoothstep(0.1, 0.02, max(abs(cell_f.x - 0.5), abs(cell_f.y - 0.5)));
	float node_active = min(h_active, v_active);
	col += line_color * at_int * node_active * (0.1 + ring_boost * pulse_hdr * 0.4) * hdr_intensity * 0.15;

	// ── Stars ──
	for (int layer = 0; layer < 2; layer++) {
		float gs = (layer == 0) ? 90.0 : 140.0;
		float lo = float(layer) * 300.0;
		vec2 cell_s = floor(uv * vec2(gs, gs * 0.5));
		float h = hash(cell_s + lo);
		if (h > 0.95) {
			vec2 soff = vec2(hash(cell_s + lo + 111.0), hash(cell_s + lo + 222.0));
			vec2 sp = (cell_s + soff) / vec2(gs, gs * 0.5);
			float d_star = length((uv - sp) * vec2(ar, 1.0));
			float tw = 0.7 + 0.3 * sin(TIME * (1.0 + h * 3.0) + h * 6.28);
			float star = exp(-d_star * d_star / 0.000004) * tw;
			star *= smoothstep(vortex_radius * 0.3, vortex_radius * 2.0, dist);
			col += vec3(0.6, 0.8, 1.0) * star * 1.2;
		}
	}

	COLOR = vec4(col, 1.0);
}
