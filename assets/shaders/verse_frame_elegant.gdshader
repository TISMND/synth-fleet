shader_type canvas_item;
// Elegant frame — hairline double border with subtle inner glow.
// Refined, thin, minimal. Feels like a premium UI panel.

uniform float hdr_intensity : hint_range(0.5, 6.0) = 2.0;
uniform float whiteness : hint_range(0.0, 1.0) = 0.2;
uniform vec3 frame_color : source_color = vec3(0.3, 0.6, 0.9);
uniform float outer_width : hint_range(0.001, 0.005) = 0.002;
uniform float inner_width : hint_range(0.001, 0.005) = 0.0015;
uniform float gap : hint_range(0.005, 0.025) = 0.012;
uniform float breath_speed : hint_range(0.0, 2.0) = 0.8;

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	float modulate_alpha = COLOR.a;

	float edge_x = min(uv.x, 1.0 - uv.x);
	float edge_y = min(uv.y, 1.0 - uv.y);
	float edge_dist = min(edge_x, edge_y);

	// Gentle breathing
	float breath = 0.8 + 0.2 * sin(t * breath_speed * TAU);

	// Outer hairline
	float outer_pos = 0.0;
	float outer_line = smoothstep(outer_pos + outer_width + 0.001, outer_pos + outer_width, edge_dist)
	                  * smoothstep(outer_pos - 0.001, outer_pos, edge_dist);

	// Inner hairline (inset by gap)
	float inner_pos = gap;
	float inner_line = smoothstep(inner_pos + inner_width + 0.001, inner_pos + inner_width, edge_dist)
	                  * smoothstep(inner_pos - 0.001, inner_pos, edge_dist);

	// Subtle fill between the two lines
	float between = smoothstep(outer_pos + outer_width, outer_pos + outer_width + 0.002, edge_dist)
	              * smoothstep(inner_pos + 0.002, inner_pos, edge_dist);

	float combined = outer_line + inner_line * breath + between * 0.06 * breath;

	// Very soft inner glow
	float inner_glow = smoothstep(gap + 0.04, gap, edge_dist) * 0.05 * breath;

	vec3 white_mix = mix(frame_color, vec3(1.0), whiteness * outer_line);
	vec3 col = white_mix * (combined + inner_glow) * hdr_intensity;

	// Corner accents — small bright dots at corners
	float cx = min(uv.x, 1.0 - uv.x);
	float cy = min(uv.y, 1.0 - uv.y);
	float corner = smoothstep(0.015, 0.0, cx) * smoothstep(0.015, 0.0, cy);
	col += mix(frame_color, vec3(1.0), whiteness * 0.8) * corner * 1.5 * hdr_intensity * breath;

	float alpha = clamp(combined + inner_glow * 3.0 + corner, 0.0, 1.0);
	COLOR = vec4(col, alpha * modulate_alpha);
}
