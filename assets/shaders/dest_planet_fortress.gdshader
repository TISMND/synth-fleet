shader_type canvas_item;
// Metallic Planet — Approach C: Dark iron fortress-world with city lights.
// Heavy industrial planet, scattered glowing windows/lights, atmospheric haze.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 3.0;
uniform vec3 bg_color : source_color = vec3(0.005, 0.005, 0.015);
uniform vec3 surface_dark : source_color = vec3(0.05, 0.05, 0.07);
uniform vec3 surface_light : source_color = vec3(0.15, 0.14, 0.13);
uniform vec3 city_light_color : source_color = vec3(1.0, 0.8, 0.4);
uniform vec3 atmo_color : source_color = vec3(0.2, 0.3, 0.5);
uniform vec3 engine_color : source_color = vec3(0.3, 0.5, 1.0);
uniform float planet_radius : hint_range(0.05, 0.3) = 0.2;
uniform float city_density : hint_range(0.0, 1.0) = 0.6;
uniform float atmo_thickness : hint_range(0.0, 2.0) = 0.8;
uniform float rotation_speed : hint_range(0.0, 0.5) = 0.08;

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

void fragment() {
	vec2 uv = UV;
	float ar = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 center = vec2(0.5, 0.48);
	vec2 d = vec2((uv.x - center.x) * ar, uv.y - center.y);
	float dist = length(d);
	vec3 col = bg_color;

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
			star *= smoothstep(planet_radius * 0.9, planet_radius * 1.8, dist);
			col += vec3(0.7, 0.8, 1.0) * star * 1.5;
		}
	}

	// ── Planet surface ──
	if (dist < planet_radius) {
		float sphere_t = dist / planet_radius;
		float nz = sqrt(max(1.0 - sphere_t * sphere_t, 0.0));
		vec3 normal = normalize(vec3(d / planet_radius, nz));
		float angle = atan(normal.y, normal.x) + TIME * rotation_speed;

		// ── Industrial surface texture ──
		vec2 surf_uv = vec2(angle * 4.0, normal.y * 8.0);
		float plate = fbm(surf_uv * 2.0);
		float plate2 = fbm(surf_uv * 4.0 + 5.0);

		// Panel edges
		float panel_lat = abs(fract(normal.y * 12.0) - 0.5);
		float panel_lon = abs(fract(angle * 6.0 / 6.283) - 0.5);
		float panel_edge = smoothstep(0.05, 0.03, min(panel_lat, panel_lon));

		// ── Lighting — key + fill ──
		vec3 light_dir = normalize(vec3(-0.5, 0.3, 0.7));
		float ndotl = max(dot(normal, light_dir), 0.0);
		float fill = max(dot(normal, normalize(vec3(0.3, -0.2, 0.5))), 0.0) * 0.15;

		// Surface base color
		vec3 surface = mix(surface_dark, surface_light, plate * 0.5);
		surface *= mix(0.85, 1.0, plate2);
		surface *= 0.06 + ndotl * 0.5 + fill;

		// Panel seams slightly brighter
		surface += surface_light * panel_edge * 0.08;

		// ── City lights on the dark side ──
		float dark_side = smoothstep(0.3, 0.0, ndotl); // Only on shadowed parts
		vec2 city_uv = vec2(angle * 20.0, normal.y * 40.0);
		vec2 city_cell = floor(city_uv);
		float city_hash = hash(city_cell);

		if (city_hash > 1.0 - city_density * 0.5 && dark_side > 0.1) {
			vec2 city_f = fract(city_uv);
			// Cluster of lights
			float light_val = 0.0;
			for (int i = 0; i < 3; i++) {
				float fi = float(i);
				vec2 lp = vec2(hash(city_cell + fi * 7.0), hash(city_cell + fi * 13.0)) * 0.8 + 0.1;
				float ld = length(city_f - lp);
				float blink = step(0.3, sin(TIME * (2.0 + hash(city_cell + fi * 19.0) * 3.0) + fi * 2.0));
				light_val += exp(-ld * ld / 0.01) * (0.5 + blink * 0.5);
			}
			light_val = min(light_val, 1.5);
			surface += city_light_color * light_val * dark_side * hdr_intensity * 0.4;

			// Subtle area glow
			float area_glow = exp(-length(city_f - 0.5) * 3.0) * 0.1;
			surface += city_light_color * area_glow * dark_side * hdr_intensity * 0.15;
		}

		// ── Engine/facility glow (larger, rarer) ──
		vec2 fac_uv = vec2(angle * 5.0, normal.y * 10.0);
		vec2 fac_cell = floor(fac_uv);
		float fac_hash = hash(fac_cell + 99.0);
		if (fac_hash > 0.85) {
			vec2 fac_f = fract(fac_uv);
			float fac_d = length(fac_f - 0.5);
			float fac_glow = exp(-fac_d * fac_d / 0.02);
			float fac_pulse = sin(TIME * 1.5 + fac_hash * 6.28) * 0.3 + 0.7;
			surface += engine_color * fac_glow * fac_pulse * dark_side * hdr_intensity * 0.3;
		}

		float edge = smoothstep(planet_radius, planet_radius - 0.003, dist);
		col = mix(col, surface, edge);
	}

	// ── Atmosphere ──
	float atmo_dist = max(dist - planet_radius, 0.0);
	float atmo = exp(-atmo_dist * 15.0 / max(atmo_thickness, 0.01)) * atmo_thickness * 0.3;
	col += atmo_color * atmo * hdr_intensity * 0.25;

	// Thin bright rim
	float rim = exp(-atmo_dist * 60.0) * 0.5;
	col += atmo_color * rim * hdr_intensity * 0.3;

	// ── Terminator glow (light leaking around edge on lit side) ──
	float term_angle = atan(d.y, d.x);
	float lit_side = smoothstep(0.0, -0.5, d.x / max(dist, 0.001));
	float term = exp(-atmo_dist * 25.0) * lit_side * 0.4;
	col += vec3(0.4, 0.45, 0.6) * term * hdr_intensity * 0.2;

	COLOR = vec4(col, 1.0);
}
