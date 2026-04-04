shader_type canvas_item;
// Metallic Planet — Approach B: Tech/circuit planet with glowing grid seams.
// Dark metallic surface with luminous circuit-like patterns, energy veins.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 3.0;
uniform vec3 bg_color : source_color = vec3(0.01, 0.01, 0.02);
uniform vec3 surface_color : source_color = vec3(0.12, 0.13, 0.16);
uniform vec3 circuit_color : source_color = vec3(0.3, 0.7, 1.0);
uniform vec3 energy_color : source_color = vec3(0.1, 0.9, 0.6);
uniform float planet_radius : hint_range(0.05, 0.3) = 0.18;
uniform float grid_density : hint_range(3.0, 15.0) = 8.0;
uniform float circuit_brightness : hint_range(0.5, 5.0) = 2.5;
uniform float pulse_speed : hint_range(0.0, 3.0) = 1.0;
uniform float energy_flow : hint_range(0.0, 1.0) = 0.6;

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
		float nz = sqrt(max(1.0 - sphere_t * sphere_t, 0.0));
		vec3 normal = normalize(vec3(d / planet_radius, nz));
		float angle = atan(normal.y, normal.x);

		// ── Surface grid (latitude/longitude on sphere) ──
		float lat = normal.y * grid_density;
		float lon = angle * grid_density / PI;

		float lat_line = abs(fract(lat) - 0.5);
		float lon_line = abs(fract(lon) - 0.5);

		float lat_grid = smoothstep(0.04, 0.01, lat_line);
		float lon_grid = smoothstep(0.04, 0.01, lon_line);
		float grid = max(lat_grid, lon_grid);

		// Softer glow around lines
		float lat_glow = exp(-lat_line * lat_line * 200.0) * 0.3;
		float lon_glow = exp(-lon_line * lon_line * 200.0) * 0.3;
		float glow = max(lat_glow, lon_glow);

		// ── Circuit traces within cells ──
		vec2 cell_id = floor(vec2(lon, lat));
		float cell_hash = hash(cell_id);
		vec2 cell_fract = fract(vec2(lon, lat));

		// Random circuit segments within each cell
		float circuit = 0.0;
		if (cell_hash > 0.4) {
			// Horizontal trace
			float trace_y = 0.3 + hash(cell_id + 11.0) * 0.4;
			float trace = smoothstep(0.02, 0.005, abs(cell_fract.y - trace_y));
			float trace_extent = hash(cell_id + 22.0);
			trace *= step(cell_fract.x, trace_extent);
			circuit += trace * 0.6;
		}
		if (cell_hash > 0.6) {
			// Vertical trace
			float trace_x = 0.3 + hash(cell_id + 33.0) * 0.4;
			float trace = smoothstep(0.02, 0.005, abs(cell_fract.x - trace_x));
			float trace_extent = hash(cell_id + 44.0);
			trace *= step(cell_fract.y, trace_extent);
			circuit += trace * 0.6;
		}

		// Node dots at intersections
		if (cell_hash > 0.7) {
			vec2 node_pos = vec2(hash(cell_id + 55.0), hash(cell_id + 66.0)) * 0.6 + 0.2;
			float nd = length(cell_fract - node_pos);
			circuit += exp(-nd * nd / 0.002) * 0.8;
		}

		// ── Energy flow pulse ──
		float flow_pulse = sin(lat * 2.0 - TIME * pulse_speed * 3.0 + cell_hash * 6.28) * 0.5 + 0.5;
		float flow_pulse2 = sin(lon * 3.0 + TIME * pulse_speed * 2.0 + cell_hash * 4.0) * 0.5 + 0.5;
		float pulse = mix(1.0, max(flow_pulse, flow_pulse2), energy_flow);

		// ── Lighting ──
		vec3 light_dir = normalize(vec3(-0.4, -0.3, 0.8));
		float ndotl = max(dot(normal, light_dir), 0.0);

		// ── Compose ──
		vec3 surface = surface_color * (0.15 + ndotl * 0.5);
		// Circuit lines
		surface += circuit_color * (grid + glow) * circuit_brightness * hdr_intensity * 0.3 * pulse;
		// Circuit traces
		surface += energy_color * circuit * circuit_brightness * hdr_intensity * 0.25 * pulse;

		// Fresnel rim
		float fresnel = pow(1.0 - nz, 3.0);
		surface += circuit_color * fresnel * hdr_intensity * 0.3;

		float edge = smoothstep(planet_radius, planet_radius - 0.003, dist);
		col = mix(col, surface, edge);
	}

	// ── Atmosphere with tech glow ──
	float atmo = exp(-max(dist - planet_radius, 0.0) * 18.0) * 0.4;
	float atmo_pulse = sin(TIME * pulse_speed * 0.5) * 0.15 + 0.85;
	col += circuit_color * atmo * hdr_intensity * 0.25 * atmo_pulse;

	COLOR = vec4(col, 1.0);
}
