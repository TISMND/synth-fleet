shader_type canvas_item;
// Metallic Planet — Approach A: Chrome/silver sphere with specular highlights.
// Reflective metallic surface, fresnel rim, orbiting light reflections.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 3.0;
uniform vec3 bg_color : source_color = vec3(0.01, 0.01, 0.02);
uniform vec3 metal_base : source_color = vec3(0.35, 0.38, 0.42);
uniform vec3 metal_highlight : source_color = vec3(0.85, 0.9, 1.0);
uniform vec3 rim_color : source_color = vec3(0.5, 0.6, 0.8);
uniform float planet_radius : hint_range(0.05, 0.3) = 0.18;
uniform float specular_power : hint_range(4.0, 64.0) = 24.0;
uniform float fresnel_strength : hint_range(0.0, 3.0) = 1.5;
uniform float surface_detail : hint_range(0.0, 1.0) = 0.5;
uniform float light_orbit_speed : hint_range(0.0, 1.0) = 0.3;

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
			star *= smoothstep(planet_radius * 0.8, planet_radius * 2.0, dist);
			col += vec3(0.7, 0.8, 1.0) * star * 1.8;
		}
	}

	// ── Planet surface ──
	if (dist < planet_radius) {
		float sphere_t = dist / planet_radius;
		// Pseudo-3D normal from 2D position
		float nz = sqrt(max(1.0 - sphere_t * sphere_t, 0.0));
		vec3 normal = normalize(vec3(d.x / planet_radius, d.y / planet_radius, nz));

		// ── Surface detail (brushed metal + panel lines) ──
		float angle = atan(normal.y, normal.x);
		vec2 surf_uv = vec2(angle * 3.0, sphere_t * 8.0);

		// Brushed metal streaks
		float brush = vnoise(surf_uv * vec2(1.0, 8.0)) * 0.5 + 0.5;
		brush = mix(1.0, brush, surface_detail);

		// Panel lines (latitude/longitude)
		float lat = abs(fract(normal.y * 5.0 + 0.5) - 0.5);
		float lon = abs(fract(angle * 2.0 / 6.283 + 0.5) - 0.5);
		float panels = smoothstep(0.03, 0.04, lat) * smoothstep(0.03, 0.04, lon);
		panels = mix(1.0, panels, surface_detail * 0.6);

		// ── Main light (slowly orbiting) ──
		float light_a = TIME * light_orbit_speed;
		vec3 light_dir = normalize(vec3(cos(light_a) * 0.7, 0.3, sin(light_a) * 0.7 + 0.5));
		float ndotl = max(dot(normal, light_dir), 0.0);

		// Specular
		vec3 view = vec3(0.0, 0.0, 1.0);
		vec3 half_vec = normalize(light_dir + view);
		float spec = pow(max(dot(normal, half_vec), 0.0), specular_power);

		// ── Secondary light ──
		vec3 light2 = normalize(vec3(-0.5, -0.4, 0.6));
		float ndotl2 = max(dot(normal, light2), 0.0) * 0.3;
		float spec2 = pow(max(dot(normal, normalize(light2 + view)), 0.0), specular_power * 0.5) * 0.3;

		// ── Fresnel rim ──
		float fresnel = pow(1.0 - nz, 3.0) * fresnel_strength;

		// ── Compose surface ──
		vec3 surface = metal_base * brush * panels;
		surface *= 0.08 + ndotl * 0.7 + ndotl2;  // Diffuse
		surface += metal_highlight * (spec + spec2) * hdr_intensity;  // Specular HDR
		surface += rim_color * fresnel * hdr_intensity * 0.5;  // Fresnel

		// Panel seam glow (subtle)
		float seam = (1.0 - panels) * surface_detail;
		surface += rim_color * seam * 0.2 * hdr_intensity;

		float edge = smoothstep(planet_radius, planet_radius - 0.003, dist);
		col = mix(col, surface, edge);
	}

	// ── Atmosphere halo ──
	float atmo = exp(-max(dist - planet_radius, 0.0) * 20.0) * 0.3;
	col += rim_color * atmo * hdr_intensity * 0.3;

	// ── Light source glow (visible in background) ──
	float la = TIME * light_orbit_speed;
	vec2 light_pos = center / vec2(ar, 1.0) + vec2(cos(la), sin(la) * 0.3) * 0.35 / vec2(ar, 1.0);
	float ld = length((uv - light_pos) * vec2(ar, 1.0));
	float light_glow = exp(-ld * ld / 0.003) * 0.5;
	light_glow *= smoothstep(planet_radius * 0.9, planet_radius * 1.5, dist); // behind planet
	col += metal_highlight * light_glow * hdr_intensity * 0.4;

	COLOR = vec4(col, 1.0);
}
