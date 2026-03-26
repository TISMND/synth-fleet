shader_type canvas_item;

// Dark metallic dashboard panel shader.
// Gaussian highlight band technique adapted from text_chrome.gdshader.

uniform vec4 base_color : source_color = vec4(0.12, 0.13, 0.18, 1.0);
uniform float highlight_pos : hint_range(0.0, 1.0) = 0.3;
uniform float highlight_width : hint_range(0.01, 0.5) = 0.15;
uniform float highlight_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float edge_brightness : hint_range(0.0, 0.5) = 0.12;
uniform float divider_y : hint_range(0.0, 1.0) = 0.5;
uniform float divider_thickness : hint_range(0.0, 0.02) = 0.003;
uniform vec4 divider_color : source_color = vec4(0.35, 0.38, 0.45, 0.8);

// Vertical gradient endpoints
uniform float chrome_top_brightness : hint_range(0.0, 1.0) = 0.7;
uniform float chrome_base_brightness : hint_range(0.0, 1.0) = 0.4;

// Heat effect: 0.0 = cold, 1.0 = white hot
uniform float heat_intensity : hint_range(0.0, 1.0) = 0.0;

// Heat color ramp — 4 stage colors (HDR values OK, >1.0 triggers bloom)
uniform vec3 heat_color_1 = vec3(0.6, 0.02, 0.0);   // Stage 1: dark cherry red (0.0-0.3)
uniform vec3 heat_color_2 = vec3(1.0, 0.3, 0.0);     // Stage 2: bright orange (0.3-0.6)
uniform vec3 heat_color_3 = vec3(1.5, 0.8, 0.05);    // Stage 3: orange-yellow HDR (0.6-0.8)
uniform vec3 heat_color_4 = vec3(2.5, 2.0, 1.5);     // Stage 4: white hot HDR (0.8-1.0)

void fragment() {
	// Capture modulate alpha per CLAUDE.md shader gotcha
	float mod_a = COLOR.a;

	float y = UV.y;
	float x = UV.x;

	// Base: vertical gradient
	float base = mix(chrome_top_brightness, chrome_base_brightness, y);
	vec3 col = base_color.rgb * base;

	// Gaussian highlight band
	float highlight = exp(-pow((y - highlight_pos) / highlight_width, 2.0));
	col += vec3(highlight * highlight_intensity);

	// Edge brightening: left and right UV edges
	float left_edge = smoothstep(0.0, 0.15, x);
	float right_edge = smoothstep(1.0, 0.85, x);
	float edge_factor = (1.0 - left_edge) + (1.0 - right_edge);
	col += vec3(edge_factor * edge_brightness);

	// Divider line: anti-aliased horizontal line at divider_y
	float dist = abs(y - divider_y);
	float half_thick = divider_thickness * 0.5;
	float line_alpha = smoothstep(half_thick, half_thick * 0.3, dist);
	col = mix(col, divider_color.rgb, line_alpha * divider_color.a);

	// Heat effect: dark metal → dull red → bright orange → white hot
	// Uses uniform colors so stages are tunable from the audition screen
	if (heat_intensity > 0.0) {
		float h = heat_intensity;
		// Interpolate through 4-stage color ramp
		vec3 heat_color;
		if (h < 0.3) {
			float t = h / 0.3;
			heat_color = heat_color_1 * t;
		} else if (h < 0.6) {
			float t = (h - 0.3) / 0.3;
			heat_color = mix(heat_color_1, heat_color_2, t);
		} else if (h < 0.8) {
			float t = (h - 0.6) / 0.2;
			heat_color = mix(heat_color_2, heat_color_3, t);
		} else {
			float t = (h - 0.8) / 0.2;
			heat_color = mix(heat_color_3, heat_color_4, t);
		}
		// Variation: edges and highlight areas heat faster (thinner metal)
		float edge_heat = (1.0 - left_edge) * 0.3 + (1.0 - right_edge) * 0.3;
		float heat_variation = 1.0 + edge_heat + highlight * 0.2;
		col = mix(col, heat_color * heat_variation, smoothstep(0.0, 0.15, h));
	}

	COLOR = vec4(col, base_color.a * mod_a);
}
