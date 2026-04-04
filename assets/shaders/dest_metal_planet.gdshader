shader_type canvas_item;
// Metallic Planet — Textured iron surface with tiny point lights,
// overlaid with a simple low-poly wireframe sphere (CAD / pre-render look).

uniform float hdr_intensity : hint_range(0.5, 8.0) = 3.0;
uniform vec3 bg_color : source_color = vec3(0.005, 0.005, 0.015);
uniform vec3 metal_dark : source_color = vec3(0.04, 0.04, 0.055);
uniform vec3 metal_mid : source_color = vec3(0.14, 0.13, 0.12);
uniform vec3 metal_light : source_color = vec3(0.28, 0.27, 0.25);
uniform vec3 wire_color : source_color = vec3(0.25, 0.65, 1.0);
uniform vec3 point_light_color : source_color = vec3(1.0, 0.85, 0.5);
uniform vec3 atmo_color : source_color = vec3(0.15, 0.25, 0.45);
uniform float planet_radius : hint_range(0.05, 0.3) = 0.19;
uniform float wire_brightness : hint_range(0.5, 4.0) = 2.0;
uniform float wire_lat_count : hint_range(3.0, 12.0) = 6.0;
uniform float wire_lon_count : hint_range(4.0, 16.0) = 10.0;
uniform float point_light_density : hint_range(0.0, 1.0) = 0.6;
uniform float surface_roughness : hint_range(0.0, 1.0) = 0.7;
uniform float atmo_thickness : hint_range(0.0, 2.0) = 0.7;

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
	for (int i = 0; i < 5; i++) { v += a * vnoise(p); p *= 2.1; a *= 0.48; }
	return v;
}

float detail_noise(vec2 p) {
	float v = 0.0, a = 0.4;
	for (int i = 0; i < 6; i++) {
		v += a * (vnoise(p) * 2.0 - 1.0);
		p *= 2.3 + float(i) * 0.1;
		a *= 0.55;
	}
	return v * 0.5 + 0.5;
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
		if (h > 0.93) {
			vec2 soff = vec2(hash(cell + lo + 111.0), hash(cell + lo + 222.0));
			vec2 sp = (cell + soff) / vec2(gs, gs * 0.5);
			float d_star = length((uv - sp) * vec2(ar, 1.0));
			float tw = 0.7 + 0.3 * sin(TIME * (1.0 + h * 3.0) + h * 6.28);
			float star = exp(-d_star * d_star / 0.000004) * tw;
			star *= smoothstep(planet_radius * 0.9, planet_radius * 1.8, dist);
			col += vec3(0.7, 0.8, 1.0) * star * 1.5;
		}
	}

	// ══════════════════════════════════════════════
	// PLANET SURFACE — layered metal texturing
	// ══════════════════════════════════════════════
	if (dist < planet_radius) {
		float sphere_t = dist / planet_radius;
		float nz = sqrt(max(1.0 - sphere_t * sphere_t, 0.0));
		vec3 normal = normalize(vec3(d / planet_radius, nz));
		float surf_angle = atan(normal.y, normal.x);
		vec2 base_uv = vec2(surf_angle * 3.0, normal.y * 6.0);

		// Large terrain
		float terrain = fbm(base_uv * 1.5 + 3.0);
		// Plate boundaries
		float plates = fbm(base_uv * 4.0 + 10.0);
		float plate_edge = abs(fract(plates * 3.0) - 0.5);
		float plate_line = smoothstep(0.04, 0.01, plate_edge) * surface_roughness;
		// Fine grain
		float grain = detail_noise(base_uv * 12.0);
		float grain2 = detail_noise(base_uv * 25.0 + 5.0);
		float fine = mix(grain, grain2, 0.4);
		// Scratches
		float scratch = vnoise(base_uv * vec2(2.0, 40.0)) * surface_roughness;

		float t_val = terrain * 0.5 + fine * 0.3 + scratch * 0.2;
		vec3 surface;
		if (t_val > 0.55) {
			surface = mix(metal_mid, metal_light, (t_val - 0.55) / 0.45);
		} else if (t_val > 0.3) {
			surface = mix(metal_dark, metal_mid, (t_val - 0.3) / 0.25);
		} else {
			surface = metal_dark * (0.5 + t_val / 0.3 * 0.5);
		}
		surface *= 1.0 - plate_line * 0.5;

		// Lighting
		vec3 key_light = normalize(vec3(-0.4, 0.35, 0.75));
		float ndotl = max(dot(normal, key_light), 0.0);
		float fill = max(dot(normal, normalize(vec3(0.3, -0.2, 0.5))), 0.0) * 0.12;
		vec3 half_v = normalize(key_light + vec3(0.0, 0.0, 1.0));
		float spec = pow(max(dot(normal, half_v), 0.0), 16.0) * 0.4;

		surface *= 0.05 + ndotl * 0.6 + fill;
		surface += metal_light * spec * hdr_intensity * 0.3;

		// ── Tiny point lights on dark side ──
		float dark_side = smoothstep(0.25, 0.0, ndotl);

		// Layer 1: main lights
		vec2 light_uv = vec2(surf_angle * 30.0, normal.y * 60.0);
		vec2 light_cell = floor(light_uv);
		float lh = hash(light_cell);
		if (lh > 1.0 - point_light_density * 0.4 && dark_side > 0.1) {
			vec2 lf = fract(light_uv);
			vec2 lp = vec2(hash(light_cell + 11.0), hash(light_cell + 22.0)) * 0.8 + 0.1;
			float ld = length(lf - lp);
			float dot_light = exp(-ld * ld / 0.003);
			float color_pick = hash(light_cell + 33.0);
			vec3 lc = (color_pick > 0.7) ? wire_color * 0.6 : point_light_color;
			float blink = 0.6 + 0.4 * step(0.3, sin(TIME * (1.5 + hash(light_cell + 44.0) * 4.0) + lh * 6.28));
			surface += lc * dot_light * dark_side * hdr_intensity * 0.35 * blink;
		}

		// Layer 2: smaller dimmer lights
		vec2 light_uv2 = vec2(surf_angle * 55.0, normal.y * 110.0);
		vec2 light_cell2 = floor(light_uv2);
		float lh2 = hash(light_cell2 + 99.0);
		if (lh2 > 1.0 - point_light_density * 0.25 && dark_side > 0.15) {
			vec2 lf2 = fract(light_uv2);
			vec2 lp2 = vec2(hash(light_cell2 + 55.0), hash(light_cell2 + 66.0)) * 0.8 + 0.1;
			float ld2 = length(lf2 - lp2);
			float dot2 = exp(-ld2 * ld2 / 0.005) * 0.5;
			surface += point_light_color * 0.7 * dot2 * dark_side * hdr_intensity * 0.15;
		}

		// Fresnel
		float fresnel = pow(1.0 - nz, 3.5);
		surface += atmo_color * fresnel * hdr_intensity * 0.25;

		float edge = smoothstep(planet_radius, planet_radius - 0.003, dist);
		col = mix(col, surface, edge);
	}

	// ══════════════════════════════════════════════
	// LOW-POLY WIREFRAME SPHERE OVERLAY
	// Simple CAD-style polygon wireframe, slightly larger than planet.
	// ══════════════════════════════════════════════
	float wire_radius = planet_radius * 1.06;

	if (dist < wire_radius * 1.05) {
		float wt = dist / wire_radius;
		if (wt <= 1.0) {
			float w_nz = sqrt(max(1.0 - wt * wt, 0.0));

			// Spherical coords on wireframe sphere
			// ny ranges -1 to 1 (south to north pole)
			float ny = d.y / wire_radius;
			float nx = d.x / wire_radius;

			// ── Latitude rings ──
			// Place lat_count rings evenly from pole to pole
			float lat_spacing = 2.0 / (wire_lat_count + 1.0);
			float wire_val = 0.0;

			for (int i = 1; i <= 12; i++) {
				if (float(i) > wire_lat_count) break;
				float lat_y = -1.0 + float(i) * lat_spacing;
				// This latitude ring is a horizontal line at ny = lat_y
				// but only visible within the sphere circle
				float lat_dist = abs(ny - lat_y);
				// Line width scales with depth (thinner at edges due to perspective)
				float depth_at_lat = sqrt(max(1.0 - lat_y * lat_y, 0.0));
				float lw = 0.012 / max(depth_at_lat, 0.1);
				float lat_line = smoothstep(lw, lw * 0.2, lat_dist);
				// Only draw where x is within the sphere at this latitude
				float max_x = depth_at_lat * wire_radius;
				float x_mask = smoothstep(max_x, max_x - 0.004, abs(d.x));
				wire_val += lat_line * x_mask;
			}

			// ── Longitude lines ──
			// These are great-circle arcs seen in projection
			// A longitude line at angle theta projects to an ellipse: x = r*cos(theta)*sin(phi), y = r*cos(phi)
			float lon_spacing = 6.2832 / wire_lon_count;
			for (int i = 0; i < 16; i++) {
				if (float(i) >= wire_lon_count) break;
				float theta = float(i) * lon_spacing;
				float ct = cos(theta);
				float st = sin(theta);

				// The longitude line at angle theta, when projected to 2D:
				// It's an ellipse with semi-major axis = wire_radius (vertical)
				// and semi-minor axis = wire_radius * abs(sin(theta)) (horizontal)
				// Center at (0,0) in d-space
				// Parametrically: x = wire_radius * sin(theta) * sin(phi), y = wire_radius * cos(phi)
				// So for our pixel at (d.x, d.y):
				// The closest point on this ellipse...
				// Simpler: the projected line in 2D is x = st * wire_radius * sin(acos(ny_clamped))
				// At the pixel's ny, the expected x for this longitude is:
				float ny_clamped = clamp(ny, -0.999, 0.999);
				float sin_phi = sqrt(1.0 - ny_clamped * ny_clamped);
				float expected_x = st * sin_phi * wire_radius;

				float lon_dist = abs(d.x - expected_x);
				float lw = 0.003 + 0.002 / max(abs(st * sin_phi), 0.05);
				float lon_line = smoothstep(lw, lw * 0.15, lon_dist);

				// Only visible within sphere
				lon_line *= step(wt, 1.0);
				// Fade lines that are nearly edge-on (very thin ellipses)
				lon_line *= smoothstep(0.0, 0.15, abs(st));

				wire_val += lon_line;
			}

			// ── Outline circle ──
			float outline_dist = abs(dist - wire_radius);
			float outline = smoothstep(0.004, 0.001, outline_dist);
			wire_val += outline;

			wire_val = min(wire_val, 1.0);

			// Render wireframe — just clean HDR lines, bloom does the rest
			col += wire_color * wire_val * wire_brightness * hdr_intensity * 0.25;
		}
	}

	// ── Atmosphere ──
	float atmo_dist = max(dist - planet_radius, 0.0);
	float atmo = exp(-atmo_dist * 14.0 / max(atmo_thickness, 0.01)) * atmo_thickness * 0.25;
	col += atmo_color * atmo * hdr_intensity * 0.2;
	float rim = exp(-atmo_dist * 50.0) * 0.4;
	col += atmo_color * rim * hdr_intensity * 0.25;

	COLOR = vec4(col, 1.0);
}
