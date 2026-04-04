shader_type canvas_item;
// Planet 6: Volcanic Metal — dark iron with glowing magma cracks, ember field.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 3.5;
uniform vec3 bg_color : source_color = vec3(0.01, 0.003, 0.003);
uniform vec3 iron_color : source_color = vec3(0.06, 0.05, 0.05);
uniform vec3 magma_hot : source_color = vec3(1.0, 0.7, 0.15);
uniform vec3 magma_cool : source_color = vec3(0.7, 0.15, 0.02);
uniform float planet_radius : hint_range(0.1, 0.35) = 0.25;
uniform float crack_width : hint_range(0.02, 0.15) = 0.07;

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
vec2 voronoi(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	float d1 = 10.0, d2 = 10.0;
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 pt = hash22(i + vec2(float(x), float(y)));
		pt = 0.5 + 0.4 * sin(6.28 * pt + TIME * 0.1);
		float dd = length(vec2(float(x), float(y)) + pt - f);
		if (dd < d1) { d2 = d1; d1 = dd; } else if (dd < d2) { d2 = dd; }
	}
	return vec2(d1, d2);
}

void fragment() {
	vec2 uv = UV;
	float ar = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 center = vec2(0.5, 0.48);
	vec2 d = vec2((uv.x - center.x) * ar, uv.y - center.y);
	float dist = length(d);
	vec3 col = bg_color;

	// Stars (dimmer — fire washes them out)
	for (int L = 0; L < 2; L++) {
		float gs = (L == 0) ? 90.0 : 140.0; float lo = float(L) * 300.0;
		vec2 cs = floor(uv * vec2(gs, gs * 0.5)); float h = hash(cs + lo);
		if (h > 0.94) {
			vec2 sp = (cs + hash22(cs + lo + 111.0)) / vec2(gs, gs * 0.5);
			float sd = length((uv - sp) * vec2(ar,1));
			col += vec3(0.6, 0.5, 0.4) * exp(-sd * sd / 0.000004) * 1.0
			     * smoothstep(planet_radius * 0.9, planet_radius * 1.8, dist);
		}
	}

	// Ember particle field
	for (int i = 0; i < 20; i++) {
		float fi = float(i);
		float phase = hash(vec2(fi * 3.31, 99.0));
		float lifetime = fract(phase + TIME * (0.06 + hash(vec2(fi, 55.0)) * 0.08));
		float ea = hash(vec2(fi * 2.0, 77.0)) * 6.28;
		float er = planet_radius * (1.1 + lifetime * 1.5);
		float wx = sin(lifetime * 4.0 + fi) * 0.02;
		vec2 ep = center + vec2((cos(ea) * er + wx) / ar, sin(ea) * er);
		float ed = length((uv - ep) * vec2(ar, 1.0));
		float ember = exp(-ed * ed / 0.00002);
		float alpha = smoothstep(0.0, 0.1, lifetime) * smoothstep(1.0, 0.5, lifetime);
		col += mix(magma_hot, magma_cool, lifetime) * ember * alpha * hdr_intensity * 0.5;
	}

	// Magma atmosphere glow
	float atmo_d = max(dist - planet_radius, 0.0);
	col += magma_cool * exp(-atmo_d * 12.0) * 0.4 * hdr_intensity * 0.35;
	col += magma_hot * exp(-atmo_d * 35.0) * 0.3 * hdr_intensity * 0.25;

	if (dist < planet_radius) {
		float st = dist / planet_radius;
		float nz = sqrt(max(1.0 - st * st, 0.0));
		vec3 N = normalize(vec3(d / planet_radius, nz));
		float sa = atan(N.y, N.x);
		vec2 suv = vec2(sa * 3.0, N.y * 6.0);

		// Voronoi magma cracks
		vec2 vor = voronoi(suv * 5.0);
		float edge = vor.y - vor.x;
		float pulse = sin(TIME * 0.7 + vor.x * 4.0) * 0.2 + 0.8;
		float crack = smoothstep(crack_width, crack_width * 0.08, edge) * pulse;
		float crack_glow = exp(-edge / (crack_width * 2.0)) * pulse;

		// Iron surface texture
		float iron_tex = fbm(suv * 8.0) * 0.3 + vnoise(suv * 20.0) * 0.15;
		vec3 surface = iron_color * (0.7 + iron_tex);

		// Magma in cracks
		vec3 crack_col = mix(magma_cool, magma_hot, crack);
		surface = mix(surface, crack_col * hdr_intensity, max(crack, crack_glow * 0.5));

		// Dim lighting (mostly lit by own magma)
		vec3 key_dir = normalize(vec3(-0.3, 0.2, 0.7));
		float ndotl = max(dot(N, key_dir), 0.0);
		surface *= 0.15 + ndotl * 0.25;
		// Magma self-illumination
		surface += crack_col * crack * 0.3;

		float limb = 0.3 + 0.7 * nz;
		surface *= limb;
		surface += magma_cool * pow(1.0 - nz, 2.5) * hdr_intensity * 0.15;

		col = mix(col, surface, smoothstep(planet_radius, planet_radius - 0.003, dist));
	}

	COLOR = vec4(col, 1.0);
}
