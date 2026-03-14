shader_type canvas_item;

uniform vec4 line_color : source_color = vec4(0.15, 0.35, 0.6, 0.4);
uniform vec4 bg_color : source_color = vec4(0.02, 0.02, 0.06, 1.0);
uniform float spacing : hint_range(16.0, 256.0) = 64.0;
uniform float scroll_speed : hint_range(0.0, 100.0) = 20.0;
uniform float glow_intensity : hint_range(0.0, 2.0) = 0.6;
uniform float line_width : hint_range(0.5, 4.0) = 1.0;

void fragment() {
	vec2 uv_px = FRAGCOORD.xy;
	float y_offset = TIME * scroll_speed;

	// Horizontal lines (scroll vertically)
	float h_dist = mod(uv_px.y + y_offset, spacing);
	h_dist = min(h_dist, spacing - h_dist);

	// Vertical lines (static)
	float v_dist = mod(uv_px.x, spacing);
	v_dist = min(v_dist, spacing - v_dist);

	// Minimum distance to any line
	float d = min(h_dist, v_dist);

	// Sharp line core
	float line_alpha = 1.0 - smoothstep(0.0, line_width, d);

	// Gaussian glow falloff around lines
	float glow = exp(-d * d / (spacing * 0.15)) * glow_intensity;

	// Combine
	float total = clamp(line_alpha + glow, 0.0, 1.0);
	vec3 final_color = mix(bg_color.rgb, line_color.rgb, total);

	COLOR = vec4(final_color, 1.0);
}
