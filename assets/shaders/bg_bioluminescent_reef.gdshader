shader_type canvas_item;
// Mid-layer scrolling background: deep-sea bioluminescent reef.
// Softened voronoi with blend transitions, no particles (those belong on flight layer).

uniform vec4 deep_color : source_color = vec4(0.0, 0.02, 0.06, 1.0);
uniform vec4 coral_color : source_color = vec4(0.0, 0.6, 0.9, 0.8);
uniform float scroll_speed : hint_range(0.0, 200.0) = 25.0;
uniform bool manual_scroll = false;
uniform float scroll_offset : hint_range(0.0, 100000.0) = 0.0;

// Cell/strand controls
uniform float cell_scale : hint_range(0.3, 4.0) = 0.3;
uniform float strand_thickness : hint_range(0.01, 0.5) = 0.035;
uniform float fine_strand_thickness : hint_range(0.01, 0.5) = 0.035;
uniform float strand_sharpness : hint_range(0.0, 1.0) = 0.0;
uniform float fine_strand_sharpness : hint_range(0.0, 1.0) = 1.0;
uniform float fine_strand_blur : hint_range(0.0, 1.0) = 0.04;
uniform float strand_brightness : hint_range(0.0, 5.0) = 0.8;
uniform float strand_hdr : hint_range(1.0, 6.0) = 4.9;
uniform float fine_strand_mix : hint_range(0.0, 1.0) = 0.8;

// Neon white-out: 0 = pure coral_color, 1 = white-hot core (color lives in bloom only)
uniform float strand_white : hint_range(0.0, 1.0) = 0.1;

// Density: lower = fewer, larger cells = more dark space
uniform float density : hint_range(0.5, 6.0) = 1.4;

// Drift animation
uniform float drift_speed : hint_range(0.0, 1.0) = 0.12;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash22(vec2 p) {
	return vec2(
		fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453),
		fract(sin(dot(p, vec2(269.5, 183.3))) * 43758.5453)
	);
}

// Smooth voronoi — blended edges instead of hard cell boundaries
// Returns: x=dist to nearest, y=dist to 2nd nearest, z=cell hash
vec3 voronoi_smooth(vec2 p, float spd) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float min_d1 = 10.0;
	float min_d2 = 10.0;
	vec2 closest = vec2(0.0);
	// Extended search radius for smoother blending
	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 point = hash22(i + neighbor);
			// Gentle organic drift
			point = 0.5 + 0.4 * sin(TIME * spd + 6.2831 * point);
			vec2 diff = neighbor + point - f;
			float d = length(diff);
			if (d < min_d1) {
				min_d2 = min_d1;
				min_d1 = d;
				closest = i + neighbor;
			} else if (d < min_d2) {
				min_d2 = d;
			}
		}
	}
	return vec3(min_d1, min_d2, hash21(closest));
}


void fragment() {
	vec2 uv = FRAGCOORD.xy;
	float y_scroll = manual_scroll ? -scroll_offset : -TIME * scroll_speed;
	vec2 cell_pos = (uv + vec2(0.0, y_scroll)) * 0.008 * cell_scale;

	// Multi-scale voronoi for organic branching — density scales cell count
	vec3 vor1 = voronoi_smooth(cell_pos * density, drift_speed);
	vec3 vor2 = voronoi_smooth(cell_pos * (density * 1.667) + vec2(13.7, 7.3), drift_speed * 0.7);

	// Edge detection — thickness controls the band width, sharpness controls falloff
	float edge1_raw = vor1.y - vor1.x;
	float edge2_raw = vor2.y - vor2.x;
	float strand_falloff = mix(0.6, 0.05, strand_sharpness);
	float edge1 = smoothstep(strand_thickness + strand_thickness * strand_falloff, max(strand_thickness * 0.1, 0.005), edge1_raw);
	float fine_falloff = mix(0.6, 0.05, fine_strand_sharpness);
	float fine_outer = fine_strand_thickness + fine_strand_thickness * fine_falloff;
	fine_outer += fine_strand_blur * 0.4;
	float fine_inner = max(fine_strand_thickness * 0.1, 0.005) + fine_strand_blur * 0.1;
	float edge2 = smoothstep(fine_outer, fine_inner, edge2_raw);

	// Blended coral branches
	float coral_branch = edge1 * 0.6 + edge2 * fine_strand_mix;

	// ── Compose ──
	vec3 col = deep_color.rgb;

	// Coral strands with white-hot core + HDR bloom
	vec3 white_core = mix(coral_color.rgb, vec3(1.0), strand_white);
	vec3 strand_col = white_core * strand_hdr;
	col += strand_col * coral_branch * strand_brightness;

	COLOR = vec4(col, 1.0);
}
