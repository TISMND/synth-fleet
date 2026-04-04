shader_type canvas_item;
// Fluid Rift — Approach B: Organic flowing tendrils, bioluminescent jellyfish-like.
// Undulating strands of light emanating from a soft central glow.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 3.0;
uniform vec3 bg_color : source_color = vec3(0.0, 0.01, 0.05);
uniform vec3 tendril_color : source_color = vec3(0.15, 0.6, 1.0);
uniform vec3 core_color : source_color = vec3(0.4, 0.85, 1.0);
uniform vec3 accent_color : source_color = vec3(0.1, 0.3, 0.9);
uniform float tendril_count : hint_range(3.0, 12.0) = 6.0;
uniform float tendril_length : hint_range(0.1, 0.5) = 0.3;
uniform float undulate_speed : hint_range(0.0, 3.0) = 1.0;
uniform float glow_size : hint_range(0.02, 0.15) = 0.06;
uniform float particle_density : hint_range(0.0, 1.0) = 0.5;

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
		p *= 2.1; a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	float ar = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 center = vec2(0.5, 0.42);
	vec2 d = vec2((uv.x - center.x) * ar, uv.y - center.y);
	float dist = length(d);
	float angle = atan(d.y, d.x);
	vec3 col = bg_color;

	// ── Ambient deep-sea haze ──
	float haze = fbm(uv * 2.5 + TIME * 0.01) * 0.15;
	col += accent_color * haze * 0.3;

	// ── Tendrils ──
	int tc = int(tendril_count);
	float tendril_total = 0.0;
	for (int i = 0; i < 12; i++) {
		if (i >= tc) break;
		float fi = float(i);
		float base_angle = fi * 6.2832 / tendril_count + 1.5708; // Start pointing down
		// Weighted downward — more tendrils below center
		base_angle += sin(fi * 0.7) * 0.3;

		// Undulation along tendril
		float t_param = dist / tendril_length;
		if (t_param > 1.0) continue;

		// Tendril path: base angle + wave displacement
		float wave1 = sin(t_param * 8.0 + TIME * undulate_speed + fi * 1.7) * 0.15;
		float wave2 = sin(t_param * 12.0 - TIME * undulate_speed * 0.7 + fi * 2.3) * 0.08;
		float tendril_angle = base_angle + (wave1 + wave2) * t_param;

		// Point on tendril at this distance
		vec2 t_pos = vec2(cos(tendril_angle), sin(tendril_angle)) * dist;
		float perp_dist = length(d - t_pos);

		// Width tapers along length
		float width = mix(glow_size, glow_size * 0.15, t_param);
		float core = smoothstep(width, width * 0.15, perp_dist);
		float glow = exp(-perp_dist / (width * 2.5));

		// Fade at tip
		float tip_fade = smoothstep(1.0, 0.7, t_param);
		// Brightness variation along length
		float brightness = 0.6 + 0.4 * sin(t_param * 15.0 - TIME * 3.0 + fi * 2.0);

		tendril_total += (core * 0.8 + glow * 0.3) * tip_fade * brightness;
	}
	tendril_total = min(tendril_total, 2.0);
	col += tendril_color * tendril_total * hdr_intensity * 0.5;

	// ── Central bell/dome glow ──
	float bell_y = (d.y + 0.02) * 2.0; // Elongated upward
	float bell_dist = length(vec2(d.x, min(bell_y, d.y)));
	float bell = exp(-dist * dist / (glow_size * glow_size * 8.0));
	// Top dome shape
	float dome = smoothstep(glow_size * 2.0, glow_size * 0.5, length(vec2(d.x, min(d.y, 0.0))));
	col += core_color * (bell * 0.6 + dome * 0.4) * hdr_intensity * 0.8;

	// Pulsing inner core
	float pulse = sin(TIME * 2.0) * 0.2 + 0.8;
	float inner = exp(-dist * 30.0);
	col += core_color * inner * pulse * hdr_intensity * 1.2;

	// ── Drifting particles ──
	if (particle_density > 0.01) {
		for (int layer = 0; layer < 3; layer++) {
			float gs = 50.0 + float(layer) * 30.0;
			float lo = float(layer) * 500.0;
			vec2 p_uv = uv + vec2(sin(TIME * 0.05 + float(layer)), TIME * 0.02 * (1.0 + float(layer) * 0.3));
			vec2 cell = floor(p_uv * gs);
			float h = hash(cell + lo);
			if (h > 1.0 - particle_density * 0.15) {
				vec2 poff = vec2(hash(cell + lo + 111.0), hash(cell + lo + 222.0));
				vec2 pp = (cell + poff) / gs;
				float pd = length((uv - pp) * vec2(ar, 1.0));
				float glow = exp(-pd * pd / 0.00002) * 0.6;
				float near_tendril = smoothstep(0.3, 0.1, length(uv - center));
				col += core_color * glow * hdr_intensity * 0.3 * (0.3 + near_tendril);
			}
		}
	}

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
			star *= smoothstep(0.05, 0.2, dist);
			col += vec3(0.6, 0.8, 1.0) * star * 1.2;
		}
	}

	COLOR = vec4(col, 1.0);
}
