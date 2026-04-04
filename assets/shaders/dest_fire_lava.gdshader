shader_type canvas_item;
// Fire Destination — Approach B: Molten lava surface with voronoi cracks.
// Bright magma veins between dark cooled plates, pulsing with heat.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 3.5;
uniform vec3 bg_color : source_color = vec3(0.02, 0.0, 0.0);
uniform vec3 lava_hot : source_color = vec3(1.0, 0.7, 0.1);
uniform vec3 lava_warm : source_color = vec3(1.0, 0.2, 0.02);
uniform vec3 crust_color : source_color = vec3(0.08, 0.02, 0.01);
uniform float cell_scale : hint_range(2.0, 12.0) = 5.0;
uniform float crack_width : hint_range(0.01, 0.2) = 0.08;
uniform float pulse_speed : hint_range(0.0, 3.0) = 0.8;
uniform float flow_speed : hint_range(0.0, 0.5) = 0.1;
uniform float heat_distortion : hint_range(0.0, 1.0) = 0.4;

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

// Voronoi — returns vec2(closest_dist, second_closest_dist)
vec2 voronoi(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	float d1 = 8.0, d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 n = vec2(float(x), float(y));
			vec2 pt = hash(i + n) * vec2(0.8, 0.8) + 0.1;
			// Slow drift
			pt += 0.1 * sin(TIME * flow_speed * 0.5 + 6.28 * hash(i + n + 57.0));
			float d = length(n + pt - f);
			if (d < d1) { d2 = d1; d1 = d; }
			else if (d < d2) { d2 = d; }
		}
	}
	return vec2(d1, d2);
}

void fragment() {
	vec2 uv = UV;
	float ar = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 center = vec2(0.5, 0.48);
	vec2 d = vec2((uv.x - center.x) * ar, uv.y - center.y);
	float dist = length(d);

	// Heat distortion
	vec2 distorted_uv = uv;
	if (heat_distortion > 0.001) {
		distorted_uv.x += sin(uv.y * 30.0 + TIME * 2.0) * heat_distortion * 0.005;
		distorted_uv.y += sin(uv.x * 25.0 + TIME * 1.7) * heat_distortion * 0.005;
	}

	vec3 col = bg_color;

	// ── Lava voronoi field ──
	vec2 lava_uv = distorted_uv * cell_scale + TIME * flow_speed * vec2(0.3, -0.1);
	vec2 vor = voronoi(lava_uv);
	float edge = vor.y - vor.x; // Crack distance

	// Crack brightness with pulsing
	float pulse = sin(TIME * pulse_speed + vor.x * 4.0) * 0.3 + 0.7;
	float crack = smoothstep(crack_width, crack_width * 0.1, edge) * pulse;
	float crack_glow = exp(-edge / (crack_width * 2.0)) * pulse;

	// Lava color — hotter at crack centers
	vec3 lava_col = mix(lava_warm, lava_hot, crack);

	// Plate surface — darker crust with subtle glow variation
	float plate_heat = fbm(lava_uv * 0.8 + TIME * 0.02) * 0.15;
	vec3 plate_col = crust_color + lava_warm * plate_heat;

	// Compose
	float visible_radius = 0.32;
	float lava_mask = smoothstep(visible_radius, visible_radius * 0.5, dist);

	vec3 surface = mix(plate_col, lava_col, max(crack, crack_glow * 0.5));
	surface *= hdr_intensity;
	col = mix(col, surface, lava_mask);

	// ── Sphere shading — make it feel like a molten sphere ──
	if (dist < visible_radius) {
		float sphere_t = dist / visible_radius;
		// Darken edges (pseudo-sphere)
		float sphere_shade = sqrt(1.0 - sphere_t * sphere_t);
		col *= 0.3 + 0.7 * sphere_shade;
		// Rim glow
		float rim = smoothstep(0.6, 1.0, sphere_t);
		col += lava_warm * rim * hdr_intensity * 0.4;
	}

	// ── Heat haze glow around the sphere ──
	float haze = exp(-max(dist - visible_radius, 0.0) * 8.0) * 0.5;
	col += lava_warm * haze * hdr_intensity * 0.3;

	// Outer corona
	float corona = exp(-max(dist - visible_radius, 0.0) * 3.0) * 0.2;
	col += lava_hot * corona * hdr_intensity * 0.15;

	// ── Bright eruption spots ──
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		float ea = hash(vec2(fi, 1.0)) * 6.28 + TIME * 0.2;
		float er = hash(vec2(fi, 2.0)) * visible_radius * 0.7;
		vec2 ep = center + vec2(cos(ea) * er / ar, sin(ea) * er);
		float ed = length((uv - ep) * vec2(ar, 1.0));

		float flare_time = sin(TIME * (1.5 + fi * 0.4) + fi * 3.0) * 0.5 + 0.5;
		float flare = exp(-ed * ed / 0.0008) * flare_time;
		col += lava_hot * flare * hdr_intensity * 0.5;
	}

	COLOR = vec4(col, 1.0);
}
