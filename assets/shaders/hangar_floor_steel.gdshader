shader_type canvas_item;
// Steel plating floor — tiled metal panels with seams, subtle brushed texture, rivets.

uniform vec3 base_color : source_color = vec3(0.12, 0.13, 0.15);
uniform vec3 seam_color : source_color = vec3(0.04, 0.04, 0.05);
uniform float tile_size : hint_range(20.0, 200.0) = 80.0;
uniform float seam_width : hint_range(0.5, 4.0) = 1.5;
uniform float brush_intensity : hint_range(0.0, 0.3) = 0.08;
uniform float rivet_brightness : hint_range(0.0, 0.5) = 0.2;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 px = UV * vec2(textureSize(TEXTURE, 0));
	vec2 tile_uv = mod(px, tile_size);
	vec2 tile_id = floor(px / tile_size);

	// Seam lines
	float sx = smoothstep(0.0, seam_width, tile_uv.x) * smoothstep(0.0, seam_width, tile_size - tile_uv.x);
	float sy = smoothstep(0.0, seam_width, tile_uv.y) * smoothstep(0.0, seam_width, tile_size - tile_uv.y);
	float seam = sx * sy;

	// Per-tile brightness variation
	float tile_var = hash(tile_id) * 0.06 - 0.03;

	// Brushed metal texture (directional noise)
	float brush = (noise(vec2(px.x * 0.5, px.y * 4.0)) - 0.5) * brush_intensity;

	// Surface scratches
	float scratch = noise(px * 0.3) * noise(px * 0.7);
	scratch = smoothstep(0.6, 0.65, scratch) * 0.05;

	vec3 col = base_color + tile_var + brush + scratch;
	col = mix(seam_color, col, seam);

	// Rivets at corners of each tile
	float rivet_r = 2.5;
	float rivet_margin = 8.0;
	for (int ry = 0; ry < 2; ry++) {
		for (int rx = 0; rx < 2; rx++) {
			vec2 rp = vec2(rivet_margin + float(rx) * (tile_size - rivet_margin * 2.0),
			               rivet_margin + float(ry) * (tile_size - rivet_margin * 2.0));
			float d = length(tile_uv - rp);
			float rivet = smoothstep(rivet_r, rivet_r - 1.0, d);
			col += rivet * rivet_brightness;
		}
	}

	COLOR = vec4(col, 1.0);
}
