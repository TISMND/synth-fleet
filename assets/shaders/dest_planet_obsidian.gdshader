shader_type canvas_item;
// Planet 4: Obsidian Mirror — near-black reflective, strong specular, nebula wisps.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 3.0;
uniform vec3 bg_color : source_color = vec3(0.005, 0.003, 0.015);
uniform vec3 obsidian : source_color = vec3(0.02, 0.02, 0.03);
uniform vec3 spec_color : source_color = vec3(0.9, 0.85, 1.0);
uniform vec3 nebula_a : source_color = vec3(0.4, 0.1, 0.6);
uniform vec3 nebula_b : source_color = vec3(0.1, 0.3, 0.7);
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
	float angle = atan(d.y, d.x);
	vec3 col = bg_color;

	// Nebula wisps in background
	vec2 neb_uv = uv * 3.0 + TIME * vec2(0.01, 0.008);
	float neb1 = fbm(neb_uv) * fbm(neb_uv * 1.3 + 5.0);
	neb1 = smoothstep(0.08, 0.35, neb1);
	col += nebula_a * neb1 * 0.4;
	vec2 neb_uv2 = uv * 2.5 + TIME * vec2(-0.008, 0.012) + 10.0;
	float neb2 = fbm(neb_uv2) * fbm(neb_uv2 * 1.2 + 8.0);
	neb2 = smoothstep(0.1, 0.3, neb2);
	col += nebula_b * neb2 * 0.3;

	// Stars
	for (int L = 0; L < 2; L++) {
		float gs = (L == 0) ? 90.0 : 140.0; float lo = float(L) * 300.0;
		vec2 cs = floor(uv * vec2(gs, gs * 0.5)); float h = hash(cs + lo);
		if (h > 0.93) {
			vec2 sp = (cs + hash22(cs + lo + 111.0)) / vec2(gs, gs * 0.5);
			float sd = length((uv - sp) * vec2(ar,1));
			col += vec3(0.8, 0.85, 1.0) * exp(-sd * sd / 0.000004) * 2.0
			     * smoothstep(planet_radius * 0.9, planet_radius * 1.5, dist);
		}
	}

	// Faint purple corona
	float atmo_d = max(dist - planet_radius, 0.0);
	col += nebula_a * exp(-atmo_d * 18.0) * 0.3 * hdr_intensity * 0.3;

	if (dist < planet_radius) {
		float st = dist / planet_radius;
		float nz = sqrt(max(1.0 - st * st, 0.0));
		vec3 N = normalize(vec3(d / planet_radius, nz));
		float sa = atan(N.y, N.x);
		vec2 suv = vec2(sa * 3.0, N.y * 6.0);

		// Nearly black surface with subtle swirl texture
		float swirl = fbm(suv * 4.0 + vec2(0.0, TIME * 0.02));
		float fine = vnoise(suv * 20.0) * 0.1;
		vec3 surface = obsidian * (0.8 + swirl * 0.2 + fine);

		// Strong single specular — this planet is all about the highlight
		vec3 key_dir = normalize(vec3(-0.3, 0.25, 0.8));
		float ndotl = max(dot(N, key_dir), 0.0);
		vec3 half_v = normalize(key_dir + vec3(0,0,1));
		float spec = pow(max(dot(N, half_v), 0.0), 64.0);
		float spec_wide = pow(max(dot(N, half_v), 0.0), 8.0);

		surface *= 0.02 + ndotl * 0.15; // Very dark diffuse
		surface += spec_color * spec * hdr_intensity * 0.8; // Sharp specular
		surface += spec_color * spec_wide * hdr_intensity * 0.1; // Wide sheen

		// Reflected nebula on surface (environment map fake)
		vec2 refl_uv = vec2(sa * 0.5 + 0.5, N.y * 0.5 + 0.5) * 3.0;
		float refl_neb = fbm(refl_uv + TIME * 0.01);
		surface += mix(nebula_a, nebula_b, refl_neb) * refl_neb * 0.08 * (1.0 - nz);

		// Fresnel
		surface += spec_color * pow(1.0 - nz, 4.0) * hdr_intensity * 0.2;

		col = mix(col, surface, smoothstep(planet_radius, planet_radius - 0.003, dist));
	}

	COLOR = vec4(col, 1.0);
}
