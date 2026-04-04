shader_type canvas_item;
// Planet 8: Ancient Relic — weathered dark metal, glowing rune lines, energy corona.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 3.5;
uniform vec3 bg_color : source_color = vec3(0.005, 0.005, 0.015);
uniform vec3 stone_dark : source_color = vec3(0.04, 0.04, 0.05);
uniform vec3 stone_light : source_color = vec3(0.12, 0.11, 0.1);
uniform vec3 rune_color : source_color = vec3(0.2, 0.8, 0.6);
uniform vec3 energy_color : source_color = vec3(0.15, 0.6, 1.0);
uniform float planet_radius : hint_range(0.1, 0.35) = 0.25;
uniform float rune_brightness : hint_range(0.5, 5.0) = 2.5;

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
	float angle = atan(d.y, d.x);
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

	// Energy corona — pulsing, irregular
	float atmo_d = max(dist - planet_radius, 0.0);
	float corona_fbm = fbm(vec2(angle * 2.0, dist * 5.0) + TIME * vec2(0.1, 0.05));
	float corona = exp(-atmo_d * 10.0) * (0.3 + corona_fbm * 0.4);
	float corona_pulse = sin(TIME * 1.5 + angle * 3.0) * 0.2 + 0.8;
	col += energy_color * corona * corona_pulse * hdr_intensity * 0.35;
	col += rune_color * exp(-atmo_d * 30.0) * 0.3 * hdr_intensity * 0.25;

	// Floating fragments
	for (int i = 0; i < 6; i++) {
		float fi = float(i);
		float fa = fi * 1.047 + TIME * 0.03 * (1.0 + hash(vec2(fi, 1.0)) * 0.5);
		float fr = planet_radius * (1.3 + hash(vec2(fi, 2.0)) * 0.5);
		float bob = sin(TIME * 0.5 + fi * 2.0) * 0.01;
		vec2 fp = center + vec2(cos(fa) * fr / ar, sin(fa) * fr + bob);
		float fd = length((uv - fp) * vec2(ar, 1.0));
		float frag = smoothstep(0.008, 0.004, fd);
		float fglow = exp(-fd * fd / 0.00015);
		col += stone_light * 1.5 * frag + rune_color * fglow * hdr_intensity * 0.15;
	}

	if (dist < planet_radius) {
		float st = dist / planet_radius;
		float nz = sqrt(max(1.0 - st * st, 0.0));
		vec3 N = normalize(vec3(d / planet_radius, nz));
		float sa = atan(N.y, N.x);
		vec2 suv = vec2(sa * 3.0, N.y * 6.0);

		// Weathered surface
		float wear = fbm(suv * 4.0);
		float pits = fbm(suv * 12.0);
		float grain = vnoise(suv * 30.0) * 0.2;
		vec3 surface = mix(stone_dark, stone_light, wear * 0.5 + grain);
		surface *= 0.8 + pits * 0.2;

		// Rune lines — geometric patterns via grid + hash selection
		vec2 rune_uv = suv * 10.0;
		vec2 rune_id = floor(rune_uv);
		vec2 rune_f = fract(rune_uv);
		float rh = hash(rune_id);

		float rune_val = 0.0;
		// Horizontal rune segments
		if (rh > 0.5) {
			float ry = hash(rune_id + 11.0) * 0.6 + 0.2;
			rune_val += smoothstep(0.03, 0.008, abs(rune_f.y - ry))
			          * step(hash(rune_id + 22.0) * 0.3, rune_f.x)
			          * step(rune_f.x, 0.7 + hash(rune_id + 33.0) * 0.3);
		}
		// Vertical rune segments
		if (rh > 0.35) {
			float rx = hash(rune_id + 44.0) * 0.6 + 0.2;
			rune_val += smoothstep(0.03, 0.008, abs(rune_f.x - rx))
			          * step(hash(rune_id + 55.0) * 0.3, rune_f.y)
			          * step(rune_f.y, 0.7 + hash(rune_id + 66.0) * 0.3);
		}
		// Circle rune at cell center
		if (rh > 0.75) {
			float cd = length(rune_f - 0.5);
			float cr = 0.12 + hash(rune_id + 77.0) * 0.1;
			rune_val += smoothstep(0.02, 0.005, abs(cd - cr));
		}
		rune_val = min(rune_val, 1.0);

		// Rune pulse
		float rune_pulse = sin(TIME * 1.2 + rh * 6.28 + suv.y * 3.0) * 0.3 + 0.7;
		rune_val *= rune_pulse;

		// Lighting
		vec3 key_dir = normalize(vec3(-0.4, 0.3, 0.7));
		float ndotl = max(dot(N, key_dir), 0.0);
		surface *= 0.05 + ndotl * 0.4;

		// Rune glow — HDR
		surface += rune_color * rune_val * rune_brightness * hdr_intensity * 0.25;
		// Fresnel
		surface += energy_color * pow(1.0 - nz, 3.5) * hdr_intensity * 0.2;

		col = mix(col, surface, smoothstep(planet_radius, planet_radius - 0.003, dist));
	}

	COLOR = vec4(col, 1.0);
}
