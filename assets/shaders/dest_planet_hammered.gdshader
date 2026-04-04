shader_type canvas_item;
// Planet 1: Hammered Iron — impact craters, warm/cool dual lighting, dust halo.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 3.0;
uniform vec3 bg_color : source_color = vec3(0.005, 0.005, 0.015);
uniform vec3 metal_base : source_color = vec3(0.1, 0.09, 0.08);
uniform vec3 metal_light : source_color = vec3(0.3, 0.28, 0.25);
uniform vec3 key_color : source_color = vec3(1.0, 0.7, 0.4);
uniform vec3 fill_color : source_color = vec3(0.2, 0.35, 0.6);
uniform vec3 dust_color : source_color = vec3(0.4, 0.3, 0.2);
uniform float planet_radius : hint_range(0.1, 0.35) = 0.25;

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

	// Stars
	for (int L = 0; L < 2; L++) {
		float gs = (L == 0) ? 90.0 : 140.0;
		float lo = float(L) * 300.0;
		vec2 cs = floor(uv * vec2(gs, gs * 0.5));
		float h = hash(cs + lo);
		if (h > 0.93) {
			vec2 sp = (cs + hash22(cs + lo + 111.0)) / vec2(gs, gs * 0.5);
			float sd = length((uv - sp) * vec2(ar, 1.0));
			col += vec3(0.7, 0.8, 1.0) * exp(-sd * sd / 0.000004) * 1.5
			     * smoothstep(planet_radius * 0.9, planet_radius * 1.6, dist);
		}
	}

	// Dust halo
	float halo_fbm = fbm(vec2(atan(d.y, d.x) * 3.0, dist * 8.0) + TIME * 0.02);
	float halo = exp(-abs(dist - planet_radius * 1.3) / 0.04) * halo_fbm * 0.5;
	col += dust_color * halo * hdr_intensity * 0.4;

	// Atmosphere rim
	float atmo_d = max(dist - planet_radius, 0.0);
	col += key_color * exp(-atmo_d * 30.0) * 0.3 * hdr_intensity * 0.3;
	col += fill_color * exp(-atmo_d * 20.0) * 0.2 * hdr_intensity * 0.25;

	if (dist < planet_radius) {
		float st = dist / planet_radius;
		float nz = sqrt(max(1.0 - st * st, 0.0));
		vec3 N = normalize(vec3(d / planet_radius, nz));
		float sa = atan(N.y, N.x);
		vec2 suv = vec2(sa * 3.0, N.y * 6.0);

		// Crater field (voronoi cells)
		vec2 vor = voronoi(suv * 4.0);
		float crater_rim = smoothstep(0.12, 0.06, vor.x); // bright rim
		float crater_floor = smoothstep(0.0, 0.08, vor.x); // dark floor
		// Hammered texture
		float hammered = fbm(suv * 8.0) * 0.4 + fbm(suv * 16.0) * 0.2;
		float grain = vnoise(suv * 30.0) * 0.15;

		vec3 surface = mix(metal_base, metal_light, hammered + grain);
		surface *= 0.7 + crater_floor * 0.3;
		surface += metal_light * crater_rim * 0.3;

		// Dual lighting
		vec3 key_dir = normalize(vec3(-0.5, 0.3, 0.7));
		vec3 fill_dir = normalize(vec3(0.4, -0.3, 0.5));
		float ndotk = max(dot(N, key_dir), 0.0);
		float ndotf = max(dot(N, fill_dir), 0.0);
		float spec = pow(max(dot(N, normalize(key_dir + vec3(0,0,1))), 0.0), 20.0);

		surface *= 0.04 + ndotk * 0.55 + ndotf * 0.15;
		surface += key_color * spec * hdr_intensity * 0.35;
		surface += fill_color * pow(1.0 - nz, 3.0) * hdr_intensity * 0.2;

		col = mix(col, surface, smoothstep(planet_radius, planet_radius - 0.003, dist));
	}

	COLOR = vec4(col, 1.0);
}
