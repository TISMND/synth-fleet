shader_type canvas_item;
// Mid-layer scrolling background: deep-sea bioluminescent reef.
// Softened voronoi with blend transitions, no particles (those belong on flight layer).

uniform vec4 deep_color : source_color = vec4(0.0, 0.02, 0.06, 1.0);
uniform vec4 coral_color : source_color = vec4(0.0, 0.6, 0.9, 0.8);
uniform float scroll_speed : hint_range(0.0, 200.0) = 25.0;
uniform float density : hint_range(0.2, 4.0) = 4.0;
uniform float softness : hint_range(0.0, 1.0) = 0.24;
uniform bool manual_scroll = false;
uniform float scroll_offset : hint_range(0.0, 100000.0) = 0.0;

// Cell/strand controls
uniform float cell_scale : hint_range(0.3, 4.0) = 0.75;
uniform float strand_thickness : hint_range(0.01, 0.5) = 0.04;
uniform float fine_strand_thickness : hint_range(0.01, 0.5) = 0.01;
uniform float strand_sharpness : hint_range(0.0, 1.0) = 0.56;
uniform float fine_strand_sharpness : hint_range(0.0, 1.0) = 1.0;
uniform float fine_strand_blur : hint_range(0.0, 1.0) = 0.12;
uniform float strand_brightness : hint_range(0.0, 5.0) = 1.95;
uniform float strand_hdr : hint_range(1.0, 6.0) = 6.0;
uniform float fine_strand_mix : hint_range(0.0, 1.0) = 0.02;

// Tendril controls
uniform float tendril_intensity : hint_range(0.0, 1.0) = 0.06;
uniform vec4 tendril_color : source_color = vec4(0.1, 0.9, 0.6, 1.0);

// Background controls
uniform float bg_brightness : hint_range(0.0, 2.0) = 0.0;
uniform float depth_intensity : hint_range(0.0, 1.0) = 0.98;
uniform float caustic_intensity : hint_range(0.0, 1.0) = 0.22;

// Drift animation
uniform float drift_speed : hint_range(0.0, 1.0) = 0.14;

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

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float val = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		val += amp * noise(p);
		p *= 2.1;
		amp *= 0.48;
	}
	return val;
}

void fragment() {
	vec2 uv = FRAGCOORD.xy;
	float y_scroll = manual_scroll ? -scroll_offset : -TIME * scroll_speed;
	// Background texture coords — density only
	vec2 bg_pos = (uv + vec2(0.0, y_scroll)) * 0.008 * density;
	// Cell coords — cell_scale only, independent of density
	vec2 cell_pos = (uv + vec2(0.0, y_scroll)) * 0.008 * cell_scale;

	// Multi-scale voronoi for organic branching
	vec3 vor1 = voronoi_smooth(cell_pos * 3.0, drift_speed);
	vec3 vor2 = voronoi_smooth(cell_pos * 5.0 + vec2(13.7, 7.3), drift_speed * 0.7);

	// Edge detection — thickness controls the band width, sharpness controls falloff
	float edge1_raw = vor1.y - vor1.x;
	float edge2_raw = vor2.y - vor2.x;
	float strand_falloff = mix(0.6, 0.05, strand_sharpness);
	float edge1 = smoothstep(strand_thickness + strand_thickness * strand_falloff, max(strand_thickness * 0.1, 0.005), edge1_raw);
	float fine_falloff = mix(0.6, 0.05, fine_strand_sharpness);
	float fine_outer = fine_strand_thickness + fine_strand_thickness * fine_falloff;
	// Blur widens the outer edge and raises the inner edge, creating a broad soft gradient
	fine_outer += fine_strand_blur * 0.4;
	float fine_inner = max(fine_strand_thickness * 0.1, 0.005) + fine_strand_blur * 0.1;
	float edge2 = smoothstep(fine_outer, fine_inner, edge2_raw);

	// Blended coral branches
	float coral_branch = edge1 * 0.6 + edge2 * fine_strand_mix;

	// Organic noise layer for texture variation (uses bg_pos)
	float org = fbm(bg_pos * 2.0 + vec2(TIME * 0.03, TIME * 0.01));
	float org2 = fbm(bg_pos * 4.0 - vec2(TIME * 0.02, 0.0));

	// Tendril wisps — soft organic bands
	float tendril1 = smoothstep(0.42, 0.58, org) * 0.25;
	float tendril2 = smoothstep(0.48, 0.52, org2) * 0.15;

	// Depth variation — some areas darker (deeper water)
	float depth = fbm(bg_pos * 0.5) * depth_intensity;

	// ── Compose ──
	// bg_brightness: 0 = pure black, 1 = deep_color, >1 = brighter
	vec3 col = deep_color.rgb * bg_brightness * (1.0 - depth * 0.5);

	// Coral structure with HDR glow
	vec3 strand_col = coral_color.rgb * strand_hdr;
	col += strand_col * coral_branch * strand_brightness;

	// Tendrils
	col += coral_color.rgb * tendril1 * tendril_intensity;
	col += tendril_color.rgb * tendril2 * tendril_intensity * 0.5;

	// Ambient caustics — uses coral_color tint so they're actually visible
	float caustic = fbm(bg_pos * 3.0 + vec2(TIME * 0.08, TIME * 0.05));
	col += coral_color.rgb * caustic * caustic_intensity * 0.15;

	COLOR = vec4(col, 1.0);
}
