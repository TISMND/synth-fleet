shader_type canvas_item;
// Diamond plate floor — raised diamond pattern on steel, industrial anti-slip surface.

uniform vec3 base_color : source_color = vec3(0.10, 0.11, 0.13);
uniform vec3 diamond_color : source_color = vec3(0.16, 0.17, 0.20);
uniform float tile_size : hint_range(10.0, 40.0) = 16.0;
uniform float diamond_ratio : hint_range(0.2, 0.8) = 0.55;
uniform float highlight : hint_range(0.0, 0.3) = 0.08;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
	           mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 px = UV * vec2(textureSize(TEXTURE, 0));

	// Diamond pattern — rotated 45 degree grid
	vec2 rot_px = vec2(px.x + px.y, px.x - px.y) * 0.7071;
	vec2 cell = mod(rot_px, tile_size);
	vec2 cell_center = cell - tile_size * 0.5;
	// Diamond shape: |x| + |y| < threshold
	float diamond_dist = (abs(cell_center.x) + abs(cell_center.y)) / tile_size;
	float on_diamond = step(diamond_dist, diamond_ratio);

	// Raised diamond has highlight on top-left edge
	float edge_highlight = smoothstep(diamond_ratio, diamond_ratio - 0.08, diamond_dist);
	float edge_shadow = smoothstep(diamond_ratio - 0.02, diamond_ratio, diamond_dist);

	vec3 col = mix(base_color, diamond_color, on_diamond);
	// Top-left light catch
	float light_dir = (cell_center.x - cell_center.y) / tile_size;
	col += on_diamond * highlight * smoothstep(0.0, -0.3, light_dir);
	// Bottom-right shadow
	col -= on_diamond * highlight * 0.5 * smoothstep(0.0, 0.3, light_dir);

	// Subtle surface grime
	float grime = noise(px * 0.05) * 0.02;
	col -= grime;

	// Wear on high points
	float wear = noise(px * 0.008);
	col += on_diamond * smoothstep(0.5, 0.7, wear) * 0.02;

	COLOR = vec4(col, 1.0);
}
