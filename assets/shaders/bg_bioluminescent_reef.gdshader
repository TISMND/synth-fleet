shader_type canvas_item;
// Mid-layer scrolling background: deep-sea bioluminescent reef.
// Softened voronoi with blend transitions, no particles (those belong on flight layer).

uniform vec4 deep_color : source_color = vec4(0.0, 0.02, 0.06, 1.0);
uniform vec4 coral_color : source_color = vec4(0.0, 0.6, 0.9, 0.8);
uniform vec4 glow_color_a : source_color = vec4(0.1, 0.9, 0.6, 1.0);
uniform vec4 glow_color_b : source_color = vec4(0.8, 0.2, 0.9, 1.0);
uniform float scroll_speed : hint_range(0.0, 200.0) = 25.0;
uniform float density : hint_range(0.5, 4.0) = 1.5;
uniform float pulse_speed : hint_range(0.0, 4.0) = 1.2;
uniform float brightness : hint_range(0.0, 3.0) = 1.0;
uniform float softness : hint_range(0.0, 1.0) = 0.4;
uniform bool manual_scroll = false;
uniform float scroll_offset : hint_range(0.0, 100000.0) = 0.0;

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
vec3 voronoi_smooth(vec2 p) {
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
			point = 0.5 + 0.4 * sin(TIME * 0.2 + 6.2831 * point);
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
	vec2 pos = (uv + vec2(0.0, y_scroll)) * 0.008 * density;

	// Multi-scale voronoi for organic branching
	vec3 vor1 = voronoi_smooth(pos * 3.0);
	vec3 vor2 = voronoi_smooth(pos * 5.0 + vec2(13.7, 7.3));

	// Soft edge detection — blend between cells instead of hard lines
	float edge1_raw = vor1.y - vor1.x;
	float edge2_raw = vor2.y - vor2.x;
	// Smooth the edges with softness control
	float edge1 = smoothstep(softness * 0.3, 0.02, edge1_raw);
	float edge2 = smoothstep(softness * 0.25, 0.03, edge2_raw);

	// Blended coral branches — smooth transitions
	float coral_branch = edge1 * 0.6 + edge2 * 0.3;

	// Organic noise layer for texture variation
	float org = fbm(pos * 2.0 + vec2(TIME * 0.03, TIME * 0.01));
	float org2 = fbm(pos * 4.0 - vec2(TIME * 0.02, 0.0));

	// Pulsing glow nodes at cell centers — each cell pulses independently
	float cell_hash1 = vor1.z;
	float pulse1 = 0.5 + 0.5 * sin(cell_hash1 * 6.28 + TIME * pulse_speed);
	float node_glow1 = exp(-vor1.x * vor1.x * 40.0) * pulse1;

	float cell_hash2 = vor2.z;
	float pulse2 = 0.5 + 0.5 * sin(cell_hash2 * 6.28 + TIME * pulse_speed * 0.7 + 2.0);
	float node_glow2 = exp(-vor2.x * vor2.x * 50.0) * pulse2;

	// Tendril wisps — soft organic bands
	float tendril1 = smoothstep(0.42, 0.58, org) * 0.25;
	float tendril2 = smoothstep(0.48, 0.52, org2) * 0.15;

	// Depth variation — some areas darker (deeper water)
	float depth = fbm(pos * 0.5) * 0.3;

	// ── Compose ──
	vec3 col = deep_color.rgb * (1.0 - depth * 0.5);

	// Coral structure — blended, no hard seams
	col += coral_color.rgb * coral_branch * 0.5;

	// Tendrils
	col += coral_color.rgb * tendril1 * 0.4;
	col += glow_color_a.rgb * tendril2 * 0.2;

	// Bioluminescent glow at nodes — two-tone
	vec3 node_col1 = mix(glow_color_a.rgb, glow_color_b.rgb, cell_hash1);
	col += node_col1 * node_glow1 * brightness;

	vec3 node_col2 = mix(glow_color_b.rgb, glow_color_a.rgb, cell_hash2);
	col += node_col2 * node_glow2 * brightness * 0.6;

	// Subtle ambient caustics (soft moving light patterns)
	float caustic = fbm(pos * 3.0 + vec2(TIME * 0.08, TIME * 0.05));
	col += deep_color.rgb * caustic * 0.15 + vec3(0.0, 0.015, 0.03) * caustic;

	COLOR = vec4(col, 1.0);
}
