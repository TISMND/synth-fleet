shader_type canvas_item;
// Fluid Rift — Approach A: Smooth spiral vortex with caustic patterns.
// Light blue fluid dynamics feel, swirling inward.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 3.0;
uniform vec3 bg_color : source_color = vec3(0.0, 0.01, 0.04);
uniform vec3 fluid_color : source_color = vec3(0.2, 0.65, 1.0);
uniform vec3 highlight_color : source_color = vec3(0.5, 0.9, 1.0);
uniform float vortex_radius : hint_range(0.05, 0.35) = 0.22;
uniform float swirl_tightness : hint_range(2.0, 20.0) = 10.0;
uniform float swirl_speed : hint_range(0.0, 2.0) = 0.6;
uniform float caustic_scale : hint_range(1.0, 8.0) = 4.0;
uniform float caustic_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float flow_speed : hint_range(0.0, 1.0) = 0.2;

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
		p *= 2.0; a *= 0.5;
	}
	return v;
}

// Caustic pattern using overlapping sine waves
float caustics(vec2 p) {
	float c = 0.0;
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float a = fi * 2.094 + TIME * flow_speed * (0.5 + fi * 0.3);
		vec2 dir = vec2(cos(a), sin(a));
		c += sin(dot(p, dir) * 6.283 + TIME * flow_speed * 2.0) * 0.5 + 0.5;
	}
	return c / 3.0;
}

void fragment() {
	vec2 uv = UV;
	float ar = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 center = vec2(0.5, 0.48);
	vec2 d = vec2((uv.x - center.x) * ar, uv.y - center.y);
	float dist = length(d);
	float angle = atan(d.y, d.x);
	vec3 col = bg_color;

	// ── Swirling fluid arms ──
	float swirl_a = angle - dist * swirl_tightness + TIME * swirl_speed;
	float arms = sin(swirl_a * 3.0) * 0.5 + 0.5;
	arms = pow(arms, 2.0);

	// Turbulence in the spiral
	vec2 turb_uv = vec2(swirl_a * 0.5, dist * 8.0) + TIME * vec2(0.0, -flow_speed);
	float turb = fbm(turb_uv * 2.0) * 0.3;
	arms = clamp(arms + turb - 0.15, 0.0, 1.0);

	// Fade with distance from center
	float arm_fade = smoothstep(vortex_radius * 2.5, vortex_radius * 0.4, dist);
	float arm_outside = smoothstep(vortex_radius * 0.15, vortex_radius * 0.5, dist);
	arms *= arm_fade * arm_outside;

	col += fluid_color * arms * hdr_intensity * 0.6;

	// ── Caustic overlay ──
	vec2 caust_uv = uv * caustic_scale;
	// Warp caustic UVs with swirl
	float sa = dist * 3.0 + TIME * swirl_speed * 0.5;
	caust_uv += vec2(cos(sa), sin(sa)) * 0.3;
	float c = caustics(caust_uv);
	c = smoothstep(0.3, 0.8, c);
	float caust_fade = smoothstep(vortex_radius * 3.0, vortex_radius * 0.5, dist) * arm_outside;
	col += highlight_color * c * caustic_intensity * hdr_intensity * 0.5 * caust_fade;

	// ── Central bright core ──
	float core_glow = exp(-dist * 12.0 / vortex_radius);
	col += highlight_color * core_glow * hdr_intensity * 0.4;

	// Inner eye — darker
	float eye = smoothstep(vortex_radius * 0.2, vortex_radius * 0.05, dist);
	col = mix(col, bg_color * 0.5, eye * 0.7);

	// ── Outer fluid wisps ──
	vec2 wisp_uv = uv * 3.0 + vec2(TIME * 0.015, TIME * 0.01);
	float wisp = fbm(wisp_uv) * fbm(wisp_uv * 1.3 + 5.0);
	wisp = smoothstep(0.12, 0.35, wisp);
	float wisp_ring = smoothstep(vortex_radius * 1.5, vortex_radius * 2.8, dist)
	                * smoothstep(vortex_radius * 4.0, vortex_radius * 3.0, dist);
	col += fluid_color * 0.5 * wisp * wisp_ring * hdr_intensity * 0.3;

	// ── Rim highlight ring ──
	float rim = abs(dist - vortex_radius * 0.9);
	float rim_glow = exp(-rim / 0.015);
	float rim_pulse = sin(angle * 6.0 + TIME * 2.0) * 0.2 + 0.8;
	col += highlight_color * rim_glow * rim_pulse * hdr_intensity * 0.3;

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
			star *= smoothstep(vortex_radius * 0.5, vortex_radius * 2.5, dist);
			col += vec3(0.6, 0.8, 1.0) * star * 1.5;
		}
	}

	COLOR = vec4(col, 1.0);
}
