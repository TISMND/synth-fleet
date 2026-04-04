shader_type canvas_item;
// Planet 7: Liquid Mercury — rippling chrome surface, prismatic reflections, ripple rings.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 3.0;
uniform vec3 bg_color : source_color = vec3(0.005, 0.005, 0.018);
uniform vec3 chrome_base : source_color = vec3(0.35, 0.37, 0.4);
uniform vec3 chrome_bright : source_color = vec3(0.9, 0.92, 1.0);
uniform vec3 prismatic_a : source_color = vec3(0.3, 0.6, 1.0);
uniform vec3 prismatic_b : source_color = vec3(1.0, 0.4, 0.6);
uniform float planet_radius : hint_range(0.1, 0.35) = 0.25;
uniform float ripple_speed : hint_range(0.0, 1.0) = 0.3;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
vec2 hash22(vec2 p) { return vec2(hash(p), hash(p + 57.0)); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1,0)), f.x),
	           mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * vnoise(p); p *= 2.1; a *= 0.48; }
	return v;
}

void fragment() {
	vec2 uv = UV;
	float ar = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 center = vec2(0.5, 0.48);
	vec2 d = vec2((uv.x - center.x) * ar, uv.y - center.y);
	float dist = length(d);
	vec3 col = bg_color;

	// Stars
	for (int L = 0; L < 2; L++) {
		float gs = (L == 0) ? 90.0 : 140.0; float lo = float(L) * 300.0;
		vec2 cs = floor(uv * vec2(gs, gs * 0.5)); float h = hash(cs + lo);
		if (h > 0.93) {
			vec2 sp = (cs + hash22(cs + lo + 111.0)) / vec2(gs, gs * 0.5);
			float sd = length((uv - sp) * vec2(ar,1));
			col += vec3(0.7, 0.8, 1.0) * exp(-sd * sd / 0.000004) * 1.5
			     * smoothstep(planet_radius * 0.9, planet_radius * 1.6, dist);
		}
	}

	// Expanding ripple rings around planet
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		float ring_phase = fi * 0.25;
		float ring_t = fract(ring_phase + TIME * ripple_speed * 0.15);
		float ring_r = planet_radius + ring_t * 0.25;
		float ring_d = abs(dist - ring_r);
		float ring = exp(-ring_d * ring_d / 0.00004);
		float fade = smoothstep(0.25, 0.0, ring_t);
		col += chrome_bright * ring * fade * hdr_intensity * 0.15;
	}

	// Chrome atmosphere
	float atmo_d = max(dist - planet_radius, 0.0);
	col += chrome_bright * exp(-atmo_d * 25.0) * 0.25 * hdr_intensity * 0.3;

	if (dist < planet_radius) {
		float st = dist / planet_radius;
		float nz = sqrt(max(1.0 - st * st, 0.0));
		vec3 N = normalize(vec3(d / planet_radius, nz));
		float sa = atan(N.y, N.x);
		vec2 suv = vec2(sa * 3.0, N.y * 6.0);

		// Animated ripple displacement
		float ripple1 = sin(suv.x * 8.0 + suv.y * 6.0 + TIME * ripple_speed * 3.0) * 0.03;
		float ripple2 = sin(suv.x * 12.0 - suv.y * 10.0 + TIME * ripple_speed * 4.0) * 0.02;
		vec2 disp_uv = suv + vec2(ripple1, ripple2);

		// Chrome surface — perturbed normals from ripples
		float h1 = fbm(disp_uv * 5.0);
		float h2 = fbm(disp_uv * 5.0 + vec2(0.01, 0.0));
		float h3 = fbm(disp_uv * 5.0 + vec2(0.0, 0.01));
		vec3 bump_N = normalize(N + vec3(h2 - h1, h3 - h1, 0.0) * 3.0);

		// Environment reflection — fake via angle-dependent color
		vec3 key_dir = normalize(vec3(-0.3, 0.3, 0.8));
		float ndotl = max(dot(bump_N, key_dir), 0.0);
		vec3 half_v = normalize(key_dir + vec3(0,0,1));
		float spec = pow(max(dot(bump_N, half_v), 0.0), 40.0);
		float spec_wide = pow(max(dot(bump_N, half_v), 0.0), 6.0);

		// Prismatic color shift based on view angle
		float view_dot = dot(bump_N, vec3(0,0,1));
		vec3 prism = mix(prismatic_a, prismatic_b, smoothstep(0.3, 0.9, view_dot));

		vec3 surface = chrome_base * (0.5 + h1 * 0.5);
		surface *= 0.08 + ndotl * 0.4;
		surface += chrome_bright * spec * hdr_intensity * 0.6;
		surface += prism * spec_wide * hdr_intensity * 0.15;
		surface += chrome_bright * pow(1.0 - nz, 3.0) * hdr_intensity * 0.3;

		col = mix(col, surface, smoothstep(planet_radius, planet_radius - 0.003, dist));
	}

	COLOR = vec4(col, 1.0);
}
