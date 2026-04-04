shader_type canvas_item;
// Neon tube frame overlay — thick glowing border tubes with
// corner accent circles and pulsing hot pink/cyan glow.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 2.5;
uniform vec3 neon_a : source_color = vec3(1.0, 0.1, 0.5);
uniform vec3 neon_b : source_color = vec3(0.0, 0.8, 1.0);
uniform float border_width : hint_range(0.01, 0.08) = 0.025;
uniform float glow_size : hint_range(0.01, 0.15) = 0.06;

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	float modulate_alpha = COLOR.a;

	float edge_x = min(uv.x, 1.0 - uv.x);
	float edge_y = min(uv.y, 1.0 - uv.y);
	float edge_dist = min(edge_x, edge_y);

	vec3 col = vec3(0.0);
	float alpha = 0.0;

	// Pick color based on which edge we're closest to (top/bottom = pink, left/right = cyan)
	vec3 edge_color = (edge_y < edge_x) ? neon_a : neon_b;

	// Neon tube core
	float tube_dist = abs(edge_dist - border_width);
	float tube_core = smoothstep(0.004, 0.0, tube_dist);
	float tube_inner = smoothstep(0.01, 0.0, tube_dist);
	float tube_glow = smoothstep(glow_size, 0.0, tube_dist);

	// Pulsing intensity
	float pulse = 0.85 + 0.15 * sin(t * 2.5);

	// White-hot core
	col += vec3(1.0, 0.95, 0.98) * tube_core * 1.5 * hdr_intensity * pulse;
	alpha += tube_core * 1.0;

	// Colored inner
	col += edge_color * tube_inner * 0.8 * hdr_intensity * pulse;
	alpha += tube_inner * 0.9;

	// Wide colored glow
	col += edge_color * tube_glow * 0.25 * hdr_intensity;
	alpha += tube_glow * 0.35;

	// Corner accent circles
	float corner_r = 0.025;
	vec2 corners[4];
	corners[0] = vec2(border_width, border_width);
	corners[1] = vec2(1.0 - border_width, border_width);
	corners[2] = vec2(border_width, 1.0 - border_width);
	corners[3] = vec2(1.0 - border_width, 1.0 - border_width);

	for (int i = 0; i < 4; i++) {
		float d = length(uv - corners[i]);
		float circle_core = smoothstep(corner_r * 0.4, 0.0, d);
		float circle_glow = smoothstep(corner_r * 2.0, 0.0, d);
		float corner_pulse = 0.8 + 0.2 * sin(t * 3.0 + float(i) * 1.57);

		vec3 c_col = (i < 2) ? neon_a : neon_b;
		col += c_col * circle_core * 1.0 * hdr_intensity * corner_pulse;
		col += c_col * circle_glow * 0.2 * hdr_intensity;
		alpha += circle_core * 0.9;
		alpha += circle_glow * 0.25;
	}

	// Traveling light along the border
	float travel = fract(t * 0.3);
	// Perimeter position (0-1 around the border)
	float perim = 0.0;
	float total_perim = 2.0 + 2.0; // normalized
	if (edge_y <= edge_x) {
		// Top or bottom edge
		if (uv.y < 0.5) {
			perim = uv.x / total_perim; // top: 0 to 0.5
		} else {
			perim = (2.0 + (1.0 - uv.x)) / total_perim; // bottom
		}
	} else {
		// Left or right edge
		if (uv.x > 0.5) {
			perim = (1.0 + uv.y) / total_perim; // right
		} else {
			perim = (3.0 + (1.0 - uv.y)) / total_perim; // left
		}
	}
	float travel_dist = abs(fract(perim) - travel);
	travel_dist = min(travel_dist, 1.0 - travel_dist);
	float travel_glow = smoothstep(0.08, 0.0, travel_dist) * tube_inner;
	col += vec3(1.0) * travel_glow * 0.5 * hdr_intensity;
	alpha += travel_glow * 0.4;

	alpha = clamp(alpha, 0.0, 1.0);
	COLOR = vec4(col, alpha * modulate_alpha);
}
