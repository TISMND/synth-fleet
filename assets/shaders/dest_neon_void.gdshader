shader_type canvas_item;
// Neon Void Rift — Vertical oval rip with geometric right-angle lines extending outward.
// Center pulses send HDR light rings outward that illuminate the grid as they pass.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 3.0;
uniform vec3 bg_color : source_color = vec3(0.01, 0.0, 0.03);
uniform vec3 rift_color : source_color = vec3(1.0, 0.1, 0.55);
uniform vec3 line_color : source_color = vec3(0.9, 0.06, 0.45);
uniform vec3 neuron_color : source_color = vec3(1.0, 0.4, 0.75);
uniform float rift_width : hint_range(0.02, 0.15) = 0.055;
uniform float rift_height : hint_range(0.05, 0.3) = 0.16;
uniform float line_brightness : hint_range(0.2, 4.0) = 1.5;
uniform float pulse_speed : hint_range(0.1, 2.0) = 0.5;
uniform float pulse_count : hint_range(1.0, 8.0) = 4.0;
uniform float pulse_hdr : hint_range(1.0, 6.0) = 3.0;
uniform float line_density : hint_range(8.0, 40.0) = 18.0;
uniform float cloud_intensity : hint_range(0.0, 0.6) = 0.2;
uniform float drift_speed : hint_range(0.0, 0.3) = 0.08;

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
	for (int i = 0; i < 4; i++) { v += a * vnoise(p); p *= 2.1; a *= 0.45; }
	return v;
}

void fragment() {
	vec2 uv = UV;
	float ar = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 center = vec2(0.5, 0.48);
	vec2 d = vec2((uv.x - center.x) * ar, uv.y - center.y);
	float dist = length(d);
	vec3 col = bg_color;

	// ── Rift ellipse (vertically ovular) ──
	float ex = d.x / rift_width;
	float ey = d.y / rift_height;
	float rift_dist = length(vec2(ex, ey));

	// Rift interior — dark void with subtle swirl
	if (rift_dist < 1.0) {
		float inner = smoothstep(1.0, 0.2, rift_dist);
		col = mix(bg_color * 0.3, vec3(0.005, 0.0, 0.01), inner);
		float angle = atan(d.y, d.x);
		float swirl = sin(angle * 3.0 + TIME * 0.8 + rift_dist * 6.0) * 0.5 + 0.5;
		col += rift_color * swirl * inner * 0.12 * hdr_intensity;
	}

	// Neon rim glow
	float rim = smoothstep(0.6, 1.0, rift_dist) * smoothstep(1.5, 1.0, rift_dist);
	col += rift_color * rim * hdr_intensity * 1.2;
	float halo = exp(-max(rift_dist - 1.0, 0.0) * 3.0) * 0.5;
	col += rift_color * halo * hdr_intensity * 0.3;

	// ── World-space distance from rift edge ──
	float rift_outside = max(rift_dist - 1.0, 0.0);
	float radial_dist = rift_outside * max(rift_width, rift_height);

	// ── HDR ring pulses expanding from center ──
	// These are the key effect — rings of HDR light that illuminate everything they cross
	float ring_boost = 0.0;
	int pc = int(pulse_count);
	for (int i = 0; i < 8; i++) {
		if (i >= pc) break;
		float fi = float(i);
		float phase = fi / pulse_count;
		float wave_pos = fract(phase + TIME * pulse_speed * 0.12);
		float wave_radius = wave_pos * 0.6; // travels far out

		float wave_match = abs(radial_dist - wave_radius);
		// Wider ring band so bloom can catch it
		float ring = exp(-wave_match * wave_match / 0.0008);
		// Fade as it expands
		float wave_fade = smoothstep(0.6, 0.02, wave_pos);
		ring_boost += ring * wave_fade;
	}
	ring_boost = min(ring_boost, 2.5);

	// ── Geometric grid lines ──
	// Slight drift for motion
	vec2 grid_offset = vec2(sin(TIME * drift_speed * 0.7) * 0.01, cos(TIME * drift_speed) * 0.01);
	vec2 grid_uv = (uv + grid_offset) * line_density;
	vec2 cell_id = floor(grid_uv);
	vec2 cell_f = fract(grid_uv);

	float cell_dist = length((cell_id + 0.5) / line_density - center);

	// Activity: full near rift, gets SPARSER (not gone) further out
	float base_activity = smoothstep(0.55, 0.03, cell_dist);
	// Sparse far out — probabilistic thinning
	float thin_chance = smoothstep(0.08, 0.45, cell_dist);
	float cell_hash_thin = hash(cell_id + 200.0);
	float sparse_mask = step(thin_chance * 0.7, cell_hash_thin);
	float activity = base_activity * sparse_mask;
	// Don't show inside rift
	activity *= smoothstep(0.0, 0.05, cell_dist - 0.03);

	float h_cell = hash(cell_id);
	float v_cell = hash(cell_id + 77.0);
	float h_active = step(0.3, h_cell) * activity;
	float v_active = step(0.3, v_cell) * activity;

	// Force connectivity near rift
	float near_rift = smoothstep(0.12, 0.03, cell_dist);
	h_active = max(h_active, near_rift);
	v_active = max(v_active, near_rift);

	float line_w = 0.055;
	float h_line = smoothstep(line_w, line_w * 0.12, abs(cell_f.y - 0.5)) * h_active;
	float v_line = smoothstep(line_w, line_w * 0.12, abs(cell_f.x - 0.5)) * v_active;
	float line_core = max(h_line, v_line);

	// Base line brightness (dim)
	float base_bright = 0.12;
	// Lines illuminated by passing HDR rings — this is the key effect
	float illuminated = base_bright + ring_boost * pulse_hdr;

	col += line_color * line_core * illuminated * line_brightness * hdr_intensity * 0.15;

	// Also add the ring pulse as a general ambient HDR wash (visible through bloom)
	float ambient_ring = ring_boost * 0.15;
	float ambient_mask = smoothstep(0.0, 0.03, radial_dist) * smoothstep(0.6, 0.1, radial_dist);
	col += rift_color * ambient_ring * hdr_intensity * pulse_hdr * 0.08 * ambient_mask;

	// ── Intersection nodes ──
	float node_h = abs(cell_f.x - 0.5);
	float node_v = abs(cell_f.y - 0.5);
	float at_int = smoothstep(0.1, 0.02, max(node_h, node_v));
	float node_active = min(h_active, v_active);
	float node = at_int * node_active * (base_bright + ring_boost * pulse_hdr * 0.5);
	col += rift_color * node * hdr_intensity * 0.2;

	// ── Subtle cloud haze ──
	if (cloud_intensity > 0.001) {
		vec2 neb_uv = uv * 3.5 + vec2(TIME * 0.015, TIME * 0.01);
		float neb = fbm(neb_uv) * fbm(neb_uv * 1.2 + 5.0);
		neb = smoothstep(0.1, 0.35, neb) * cloud_intensity;
		float near = smoothstep(0.45, 0.08, dist);
		col += rift_color * 0.35 * neb * near * hdr_intensity * 0.3;
	}

	// ── Stars ──
	for (int layer = 0; layer < 2; layer++) {
		float gs = (layer == 0) ? 90.0 : 140.0;
		float lo = float(layer) * 300.0;
		vec2 cell_s = floor(uv * vec2(gs, gs * 0.5));
		float h = hash(cell_s + lo);
		if (h > 0.94) {
			vec2 soff = vec2(hash(cell_s + lo + 111.0), hash(cell_s + lo + 222.0));
			vec2 sp = (cell_s + soff) / vec2(gs, gs * 0.5);
			float d_star = length((uv - sp) * vec2(ar, 1.0));
			float tw = 0.7 + 0.3 * sin(TIME * (1.0 + h * 3.0) + h * 6.28);
			float star = exp(-d_star * d_star / 0.000004) * tw;
			star *= smoothstep(0.03, 0.15, dist);
			col += vec3(0.7, 0.8, 1.0) * star * 1.5;
		}
	}

	COLOR = vec4(col, 1.0);
}
