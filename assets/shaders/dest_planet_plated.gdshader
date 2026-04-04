shader_type canvas_item;
// Planet 5: Plated Fortress — armored panels, varied metal tones, docking lights, orbital ring.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 3.0;
uniform vec3 bg_color : source_color = vec3(0.005, 0.005, 0.015);
uniform vec3 plate_dark : source_color = vec3(0.06, 0.06, 0.07);
uniform vec3 plate_mid : source_color = vec3(0.15, 0.14, 0.13);
uniform vec3 plate_light : source_color = vec3(0.25, 0.24, 0.22);
uniform vec3 light_color : source_color = vec3(1.0, 0.8, 0.4);
uniform vec3 ring_color : source_color = vec3(0.3, 0.5, 0.8);
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

	// Orbital defense ring — thin structure orbiting at equator
	float ring_tilt = 0.15;
	vec2 rd = vec2(d.x, d.y / ring_tilt);
	float rdist = length(rd);
	float ring_r = planet_radius * 1.25;
	float ring_w = 0.008;
	float ring_d = abs(rdist - ring_r);
	if (ring_d < ring_w * 3.0) {
		float ring_core = smoothstep(ring_w, ring_w * 0.2, ring_d);
		float ring_glow = exp(-ring_d / (ring_w * 2.0));
		// Segmented
		float seg = step(0.4, fract(atan(rd.y, rd.x) * 8.0 / 6.2832 + TIME * 0.05));
		float rv = (ring_core + ring_glow * 0.3) * seg;
		float behind = (d.y < 0.0 && dist < planet_radius) ? 0.0 : 1.0;
		col += ring_color * rv * hdr_intensity * 0.4 * behind;
	}

	// Atmosphere
	float atmo_d = max(dist - planet_radius, 0.0);
	col += ring_color * exp(-atmo_d * 30.0) * 0.25 * hdr_intensity * 0.25;

	if (dist < planet_radius) {
		float st = dist / planet_radius;
		float nz = sqrt(max(1.0 - st * st, 0.0));
		vec3 N = normalize(vec3(d / planet_radius, nz));
		float sa = atan(N.y, N.x);
		vec2 suv = vec2(sa * 3.0, N.y * 6.0);

		// Armor plates — rectangular grid with varied colors per cell
		vec2 plate_uv = suv * vec2(8.0, 12.0);
		vec2 plate_id = floor(plate_uv);
		vec2 plate_f = fract(plate_uv);
		float ph = hash(plate_id);

		// Plate color varies
		vec3 plate_col;
		if (ph > 0.7) plate_col = plate_light;
		else if (ph > 0.3) plate_col = plate_mid;
		else plate_col = plate_dark;

		// Panel seams
		float seam_x = smoothstep(0.04, 0.01, min(plate_f.x, 1.0 - plate_f.x));
		float seam_y = smoothstep(0.04, 0.01, min(plate_f.y, 1.0 - plate_f.y));
		float seam = max(seam_x, seam_y);

		// Surface detail within plate
		float detail = vnoise(suv * 30.0 + plate_id) * 0.15;
		// Rivet dots at corners
		float corner_d = min(min(length(plate_f - vec2(0.08, 0.08)),
		                         length(plate_f - vec2(0.92, 0.08))),
		                     min(length(plate_f - vec2(0.08, 0.92)),
		                         length(plate_f - vec2(0.92, 0.92))));
		float rivet = smoothstep(0.04, 0.02, corner_d);

		vec3 surface = plate_col * (0.8 + detail);
		surface *= 1.0 - seam * 0.6;
		surface += plate_light * rivet * 0.2;

		// Lighting
		vec3 key_dir = normalize(vec3(-0.4, 0.35, 0.75));
		float ndotl = max(dot(N, key_dir), 0.0);
		float spec = pow(max(dot(N, normalize(key_dir + vec3(0,0,1))), 0.0), 16.0);
		float dark_side = smoothstep(0.2, 0.0, ndotl);

		surface *= 0.04 + ndotl * 0.55;
		surface += plate_light * spec * hdr_intensity * 0.25;

		// Docking lights on dark side
		vec2 dock_uv = suv * vec2(20.0, 40.0);
		vec2 dock_id = floor(dock_uv);
		float dh = hash(dock_id);
		if (dh > 0.8 && dark_side > 0.2) {
			vec2 df = fract(dock_uv);
			vec2 dp = vec2(hash(dock_id + 11.0), hash(dock_id + 22.0)) * 0.6 + 0.2;
			float dd = length(df - dp);
			float blink = 0.6 + 0.4 * step(0.3, sin(TIME * (1.5 + dh * 4.0)));
			surface += light_color * exp(-dd * dd / 0.004) * dark_side * hdr_intensity * 0.3 * blink;
		}

		surface += ring_color * pow(1.0 - nz, 3.0) * hdr_intensity * 0.15;

		col = mix(col, surface, smoothstep(planet_radius, planet_radius - 0.003, dist));
	}

	COLOR = vec4(col, 1.0);
}
