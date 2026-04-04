shader_type canvas_item;
// Planet 2: Frozen Steel — cold blue-grey, frost crystalline, thin ice ring, aurora bands.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 3.0;
uniform vec3 bg_color : source_color = vec3(0.005, 0.005, 0.02);
uniform vec3 metal_base : source_color = vec3(0.08, 0.1, 0.14);
uniform vec3 frost_color : source_color = vec3(0.5, 0.7, 0.9);
uniform vec3 aurora_a : source_color = vec3(0.1, 0.8, 0.5);
uniform vec3 aurora_b : source_color = vec3(0.2, 0.4, 1.0);
uniform vec3 ring_color : source_color = vec3(0.4, 0.6, 0.85);
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
			col += vec3(0.7, 0.8, 1.0) * exp(-length((uv - sp) * vec2(ar,1)) * length((uv - sp) * vec2(ar,1)) / 0.000004) * 1.5
			     * smoothstep(planet_radius * 0.9, planet_radius * 1.6, dist);
		}
	}

	// Aurora bands above planet
	float aurora_y = center.y - planet_radius * 1.4;
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float band_y = aurora_y - fi * 0.04;
		float wave = sin(uv.x * 15.0 + TIME * 0.5 + fi * 2.0) * 0.015;
		wave += sin(uv.x * 25.0 - TIME * 0.3 + fi * 4.0) * 0.008;
		float dy = abs(uv.y - band_y - wave);
		float band = exp(-dy * dy * 3000.0);
		float var = fbm(vec2(uv.x * 5.0 + fi * 3.0, TIME * 0.08));
		var = smoothstep(0.3, 0.7, var);
		vec3 ac = mix(aurora_a, aurora_b, fi * 0.4 + 0.2);
		col += ac * band * var * hdr_intensity * 0.6;
	}

	// Ice ring
	float ring_tilt = 0.2;
	vec2 rd = vec2(d.x, d.y / ring_tilt);
	float rdist = length(rd);
	float ring_inner = planet_radius * 1.15;
	float ring_outer = planet_radius * 1.6;
	if (rdist > ring_inner && rdist < ring_outer && d.y < 0.0) {
		float rt = (rdist - ring_inner) / (ring_outer - ring_inner);
		float ring_val = sin(rt * 40.0) * 0.3 + 0.7;
		ring_val *= smoothstep(ring_inner, ring_inner + 0.01, rdist);
		ring_val *= smoothstep(ring_outer, ring_outer - 0.01, rdist);
		col += ring_color * ring_val * hdr_intensity * 0.25;
	}

	// Atmosphere
	float atmo_d = max(dist - planet_radius, 0.0);
	col += frost_color * exp(-atmo_d * 25.0) * 0.35 * hdr_intensity * 0.3;

	if (dist < planet_radius) {
		float st = dist / planet_radius;
		float nz = sqrt(max(1.0 - st * st, 0.0));
		vec3 N = normalize(vec3(d / planet_radius, nz));
		float sa = atan(N.y, N.x);
		vec2 suv = vec2(sa * 3.0, N.y * 6.0);

		// Base metal with frost crystalline overlay
		float base_tex = fbm(suv * 5.0);
		float frost = fbm(suv * 20.0 + 3.0);
		float frost2 = vnoise(suv * 40.0);
		float frost_pattern = smoothstep(0.4, 0.6, frost) * frost2;
		// Ice veins
		float veins = smoothstep(0.48, 0.5, fbm(suv * 12.0));

		vec3 surface = metal_base * (0.6 + base_tex * 0.4);
		surface += frost_color * frost_pattern * 0.3;
		surface += frost_color * veins * 0.2;

		vec3 key_dir = normalize(vec3(-0.3, 0.4, 0.8));
		float ndotl = max(dot(N, key_dir), 0.0);
		float spec = pow(max(dot(N, normalize(key_dir + vec3(0,0,1))), 0.0), 32.0);

		surface *= 0.06 + ndotl * 0.5;
		surface += frost_color * spec * hdr_intensity * 0.4;
		surface += frost_color * pow(1.0 - nz, 3.0) * hdr_intensity * 0.25;

		// Front ring
		if (rdist > ring_inner && rdist < ring_outer && d.y > 0.0) {
			float rt = (rdist - ring_inner) / (ring_outer - ring_inner);
			float rv = sin(rt * 40.0) * 0.3 + 0.7;
			rv *= smoothstep(ring_inner, ring_inner + 0.01, rdist) * smoothstep(ring_outer, ring_outer - 0.01, rdist);
			surface = mix(surface, ring_color * hdr_intensity * 0.3, rv * 0.6);
		}

		col = mix(col, surface, smoothstep(planet_radius, planet_radius - 0.003, dist));
	}

	COLOR = vec4(col, 1.0);
}
