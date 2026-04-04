shader_type canvas_item;
// Planet 3: Copper Patina — oxidized copper with verdigris, golden atmosphere.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 3.0;
uniform vec3 bg_color : source_color = vec3(0.005, 0.005, 0.012);
uniform vec3 copper_base : source_color = vec3(0.45, 0.2, 0.08);
uniform vec3 patina_color : source_color = vec3(0.1, 0.35, 0.3);
uniform vec3 bright_copper : source_color = vec3(0.8, 0.45, 0.15);
uniform vec3 atmo_color : source_color = vec3(0.9, 0.6, 0.2);
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
			float sd = length((uv - sp) * vec2(ar,1));
			col += vec3(0.7, 0.8, 1.0) * exp(-sd * sd / 0.000004) * 1.5
			     * smoothstep(planet_radius * 0.9, planet_radius * 1.6, dist);
		}
	}

	// Golden atmosphere halo
	float atmo_d = max(dist - planet_radius, 0.0);
	float atmo_fbm = fbm(vec2(atan(d.y, d.x) * 2.0, TIME * 0.05));
	col += atmo_color * exp(-atmo_d * 15.0) * (0.3 + atmo_fbm * 0.2) * hdr_intensity * 0.4;
	col += bright_copper * exp(-atmo_d * 40.0) * 0.4 * hdr_intensity * 0.3;

	// Scattered small moonlets
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		float ma = fi * 1.571 + TIME * 0.04 * (1.0 + fi * 0.3);
		float mr = planet_radius * (1.5 + fi * 0.25);
		vec2 mp = center + vec2(cos(ma) * mr / ar, sin(ma) * mr);
		float md = length((uv - mp) * vec2(ar, 1.0));
		float moon = smoothstep(0.006, 0.003, md);
		float mglow = exp(-md * md / 0.0001);
		col += copper_base * 2.0 * moon + atmo_color * mglow * 0.3 * hdr_intensity * 0.15;
	}

	if (dist < planet_radius) {
		float st = dist / planet_radius;
		float nz = sqrt(max(1.0 - st * st, 0.0));
		vec3 N = normalize(vec3(d / planet_radius, nz));
		float sa = atan(N.y, N.x);
		vec2 suv = vec2(sa * 3.0, N.y * 6.0);

		// Oxidation pattern — large patches of patina vs exposed copper
		float oxide = fbm(suv * 3.0 + 1.0);
		float oxide2 = fbm(suv * 6.0 + 10.0);
		float patina_mask = smoothstep(0.35, 0.65, oxide);
		// Fine grain
		float grain = vnoise(suv * 25.0) * 0.2;
		float scratch = vnoise(suv * vec2(3.0, 40.0)) * 0.15;

		vec3 surface = mix(copper_base, patina_color, patina_mask);
		surface += bright_copper * (1.0 - patina_mask) * grain;
		surface *= 0.7 + oxide2 * 0.3 + scratch;

		// Tarnish streaks
		float streak = smoothstep(0.48, 0.52, fbm(suv * vec2(2.0, 10.0)));
		surface = mix(surface, patina_color * 0.7, streak * 0.4);

		vec3 key_dir = normalize(vec3(-0.4, 0.3, 0.7));
		float ndotl = max(dot(N, key_dir), 0.0);
		float spec = pow(max(dot(N, normalize(key_dir + vec3(0,0,1))), 0.0), 12.0);

		surface *= 0.05 + ndotl * 0.6;
		// Copper has warm specular
		surface += bright_copper * spec * hdr_intensity * 0.4;
		surface += atmo_color * pow(1.0 - nz, 3.0) * hdr_intensity * 0.2;

		col = mix(col, surface, smoothstep(planet_radius, planet_radius - 0.003, dist));
	}

	COLOR = vec4(col, 1.0);
}
