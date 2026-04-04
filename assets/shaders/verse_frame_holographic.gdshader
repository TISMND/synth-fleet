shader_type canvas_item;
// Holographic frame overlay — transparent center, glitchy scan-line border
// with flickering bracket corners and data-stream edges.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 2.0;
uniform vec3 frame_color : source_color = vec3(0.2, 0.7, 1.0);
uniform float border_width : hint_range(0.01, 0.1) = 0.035;
uniform float glitch_amount : hint_range(0.0, 1.0) = 0.4;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	float modulate_alpha = COLOR.a;

	float edge_x = min(uv.x, 1.0 - uv.x);
	float edge_y = min(uv.y, 1.0 - uv.y);
	float edge_dist = min(edge_x, edge_y);

	// Frame region mask
	float frame_mask = smoothstep(border_width + 0.005, border_width - 0.002, edge_dist);

	vec3 col = vec3(0.0);
	float alpha = 0.0;

	// Main border line
	float border_line = smoothstep(border_width + 0.003, border_width, edge_dist)
	                   * smoothstep(border_width - 0.015, border_width - 0.008, edge_dist);
	col += frame_color * border_line * 0.8 * hdr_intensity;
	alpha += border_line * 0.9;

	// Inner glow edge
	float inner_glow = smoothstep(border_width + 0.015, border_width, edge_dist) * 0.3;
	col += frame_color * inner_glow * 0.3 * hdr_intensity;
	alpha += inner_glow * 0.4;

	// Corner brackets — L-shaped marks at each corner
	float bracket_len = 0.12;
	float bracket_w = 0.003;
	float bracket = 0.0;
	// Top-left
	if (uv.x < bracket_len && uv.y < border_width + bracket_w)
		bracket = 1.0;
	if (uv.y < bracket_len && uv.x < border_width + bracket_w)
		bracket = 1.0;
	// Top-right
	if (uv.x > 1.0 - bracket_len && uv.y < border_width + bracket_w)
		bracket = 1.0;
	if (uv.y < bracket_len && uv.x > 1.0 - border_width - bracket_w)
		bracket = 1.0;
	// Bottom-left
	if (uv.x < bracket_len && uv.y > 1.0 - border_width - bracket_w)
		bracket = 1.0;
	if (uv.y > 1.0 - bracket_len && uv.x < border_width + bracket_w)
		bracket = 1.0;
	// Bottom-right
	if (uv.x > 1.0 - bracket_len && uv.y > 1.0 - border_width - bracket_w)
		bracket = 1.0;
	if (uv.y > 1.0 - bracket_len && uv.x > 1.0 - border_width - bracket_w)
		bracket = 1.0;

	col += frame_color * bracket * 1.2 * hdr_intensity;
	alpha += bracket * 0.95;

	// Scan lines across frame
	float scan = sin(uv.y * 300.0) * 0.5 + 0.5;
	col *= 0.85 + 0.15 * scan;

	// Horizontal sweep
	float sweep_y = fract(t * 0.4);
	float sweep = smoothstep(0.01, 0.0, abs(uv.y - sweep_y)) * frame_mask;
	col += frame_color * sweep * 0.5 * hdr_intensity;
	alpha += sweep * 0.6;

	// Glitch flicker
	float flicker = 0.9 + 0.1 * sin(t * 25.0) * sin(t * 17.0);
	col *= flicker;

	// Glitch bands
	float gt = floor(t * 6.0);
	float band_y = hash(vec2(gt, 3.0));
	float band_h = 0.005 + hash(vec2(gt, 4.0)) * 0.015;
	float in_band = step(band_y, uv.y) * step(uv.y, band_y + band_h) * frame_mask;
	col += frame_color * in_band * 0.6 * glitch_amount * hdr_intensity;
	alpha += in_band * 0.5 * glitch_amount;

	alpha = clamp(alpha * frame_mask, 0.0, 1.0);
	COLOR = vec4(col, alpha * modulate_alpha);
}
