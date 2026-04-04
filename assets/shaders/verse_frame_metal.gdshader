shader_type canvas_item;
// Brushed metal frame overlay — industrial gunmetal border with
// rivet bolts at corners and subtle anisotropic reflection.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 1.5;
uniform vec3 metal_base : source_color = vec3(0.25, 0.27, 0.3);
uniform vec3 metal_light : source_color = vec3(0.55, 0.58, 0.65);
uniform vec3 rivet_color : source_color = vec3(0.4, 0.42, 0.48);
uniform float border_width : hint_range(0.02, 0.1) = 0.04;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
	           mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	float modulate_alpha = COLOR.a;

	float edge_x = min(uv.x, 1.0 - uv.x);
	float edge_y = min(uv.y, 1.0 - uv.y);
	float edge_dist = min(edge_x, edge_y);

	// Frame mask
	float frame_mask = smoothstep(border_width + 0.002, border_width - 0.001, edge_dist);

	// Brushed metal texture — anisotropic along the nearest edge
	vec2 brush_dir;
	if (edge_y < edge_x) {
		brush_dir = vec2(1.0, 0.0); // horizontal brush on top/bottom
	} else {
		brush_dir = vec2(0.0, 1.0); // vertical brush on left/right
	}
	float brush = noise(uv * 200.0 * brush_dir + uv * 20.0) * 0.3 +
	              noise(uv * 400.0 * brush_dir + uv * 10.0) * 0.15;

	// Base metal color with brush variation
	vec3 col = mix(metal_base, metal_light, brush);

	// Subtle reflection shift (slow pan based on TIME)
	float reflect_pos = sin(t * 0.2) * 0.5 + 0.5;
	float reflect_dist;
	if (edge_y < edge_x) {
		reflect_dist = abs(uv.x - reflect_pos);
	} else {
		reflect_dist = abs(uv.y - reflect_pos);
	}
	float reflection = smoothstep(0.4, 0.0, reflect_dist) * 0.15;
	col += metal_light * reflection;

	// Inner bevel (lighter edge near content)
	float inner_bevel = smoothstep(border_width + 0.001, border_width - 0.005, edge_dist);
	float inner_highlight = smoothstep(border_width - 0.005, border_width - 0.01, edge_dist);
	col += metal_light * (inner_bevel - inner_highlight) * 0.3;

	// Outer bevel (darker edge)
	float outer_dark = smoothstep(0.005, 0.0, edge_dist) * 0.3;
	col -= vec3(outer_dark);
	col = max(col, vec3(0.0));

	// Rivet bolts at corners and mid-edges
	float rivet_r = 0.008;
	vec2 rivets[8];
	float bw = border_width * 0.5;
	rivets[0] = vec2(bw, bw);
	rivets[1] = vec2(1.0 - bw, bw);
	rivets[2] = vec2(bw, 1.0 - bw);
	rivets[3] = vec2(1.0 - bw, 1.0 - bw);
	rivets[4] = vec2(0.5, bw);
	rivets[5] = vec2(0.5, 1.0 - bw);
	rivets[6] = vec2(bw, 0.5);
	rivets[7] = vec2(1.0 - bw, 0.5);

	for (int i = 0; i < 8; i++) {
		float d = length(uv - rivets[i]);
		float rivet_body = smoothstep(rivet_r, rivet_r - 0.002, d);
		float rivet_highlight = smoothstep(rivet_r * 0.3, 0.0, length(uv - rivets[i] - vec2(-0.002, -0.002)));
		float rivet_shadow = smoothstep(rivet_r + 0.003, rivet_r, d) * 0.2;

		col = mix(col, rivet_color, rivet_body);
		col += metal_light * rivet_highlight * rivet_body * 0.3;
		col -= vec3(rivet_shadow);
		col = max(col, vec3(0.0));
	}

	// Edge groove line (dark line just inside the border)
	float groove = smoothstep(border_width + 0.001, border_width, edge_dist)
	             * smoothstep(border_width - 0.004, border_width - 0.002, edge_dist);
	col -= vec3(groove * 0.15);
	col = max(col, vec3(0.0));

	col *= hdr_intensity * 0.6;

	COLOR = vec4(col, frame_mask * modulate_alpha);
}
