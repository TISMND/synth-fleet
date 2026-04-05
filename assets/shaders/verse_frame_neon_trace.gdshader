shader_type canvas_item;
// Neon trace frame — bright neon lines that trace along the border edges
// like a circuit path being drawn. HDR bloom with white-hot core.

uniform float hdr_intensity : hint_range(0.5, 12.0) = 5.0;
uniform float whiteness : hint_range(0.0, 1.0) = 0.7;
uniform vec3 neon_color : source_color = vec3(0.05, 0.4, 1.0);
uniform float line_width : hint_range(0.002, 0.015) = 0.005;
uniform float trace_speed : hint_range(0.1, 2.0) = 0.5;
uniform float trace_length : hint_range(0.05, 0.5) = 0.2;
uniform float base_alpha : hint_range(0.0, 0.5) = 0.15;

// Map UV to perimeter position [0..1), going clockwise from top-left
float perimeter_pos(vec2 uv) {
	// Top edge: left to right
	// Right edge: top to bottom
	// Bottom edge: right to left
	// Left edge: bottom to top
	float total = 4.0;
	float pos = 0.0;
	float edge_x = min(uv.x, 1.0 - uv.x);
	float edge_y = min(uv.y, 1.0 - uv.y);

	if (edge_y <= edge_x) {
		if (uv.y < 0.5) {
			// Top edge
			pos = uv.x;
		} else {
			// Bottom edge
			pos = 2.0 + (1.0 - uv.x);
		}
	} else {
		if (uv.x > 0.5) {
			// Right edge
			pos = 1.0 + uv.y;
		} else {
			// Left edge
			pos = 3.0 + (1.0 - uv.y);
		}
	}
	return pos / total;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	float modulate_alpha = COLOR.a;

	float edge_x = min(uv.x, 1.0 - uv.x);
	float edge_y = min(uv.y, 1.0 - uv.y);
	float edge_dist = min(edge_x, edge_y);

	// Border mask — only draw near edges
	float border = smoothstep(line_width + 0.003, line_width, edge_dist)
	             * smoothstep(max(line_width - 0.01, 0.0), line_width - 0.003, edge_dist);

	// Base dim border line (always visible)
	float base = border * base_alpha;

	// Two traces moving at different speeds around the perimeter
	float ppos = perimeter_pos(uv);
	float trace1_head = fract(t * trace_speed);
	float trace2_head = fract(t * trace_speed * 0.7 + 0.5);

	float d1 = fract(ppos - trace1_head);
	float trace1 = smoothstep(trace_length, 0.0, d1) * border;

	float d2 = fract(ppos - trace2_head);
	float trace2 = smoothstep(trace_length * 0.6, 0.0, d2) * border;

	float combined = max(base, max(trace1, trace2 * 0.6));

	// Inner glow from traces
	float glow_dist = smoothstep(line_width + 0.03, line_width, edge_dist);
	float glow = glow_dist * (trace1 + trace2 * 0.4) * 0.15;

	vec3 white_mix = mix(neon_color, vec3(1.0), whiteness * combined);
	vec3 col = white_mix * (combined + glow) * hdr_intensity;

	float alpha = clamp(combined + glow * 2.0, 0.0, 1.0);
	COLOR = vec4(col, alpha * modulate_alpha);
}
