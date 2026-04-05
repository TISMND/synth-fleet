shader_type canvas_item;
// Industrial metal grating floor — open mesh grid over dark void below.
// Feels like a ship's engineering deck or maintenance walkway.

uniform vec3 bar_color : source_color = vec3(0.15, 0.16, 0.18);
uniform vec3 void_color : source_color = vec3(0.01, 0.01, 0.02);
uniform float bar_width : hint_range(2.0, 10.0) = 4.0;
uniform float cell_size : hint_range(10.0, 40.0) = 20.0;
uniform float depth_glow : hint_range(0.0, 0.1) = 0.015;

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

	vec2 cell_uv = mod(px, cell_size);

	// Grid bars
	float on_bar_x = step(cell_uv.x, bar_width) + step(cell_size - bar_width, cell_uv.x);
	float on_bar_y = step(cell_uv.y, bar_width) + step(cell_size - bar_width, cell_uv.y);
	float on_bar = clamp(on_bar_x + on_bar_y, 0.0, 1.0);

	// Bar surface variation
	float bar_noise = noise(px * 0.3) * 0.03;
	// Edge highlight on bars
	float edge_x = min(cell_uv.x, cell_size - cell_uv.x);
	float edge_y = min(cell_uv.y, cell_size - cell_uv.y);
	float bar_edge = smoothstep(bar_width, bar_width - 1.0, min(edge_x, edge_y)) * on_bar * 0.04;

	vec3 bar_col = bar_color + bar_noise + bar_edge;

	// Void below — very dark with faint blue-ish depth glow
	float void_noise = noise(px * 0.02) * depth_glow;
	vec3 void_col = void_color + vec3(0.0, 0.01, 0.03) * void_noise;

	vec3 col = mix(void_col, bar_col, on_bar);

	// Rust spots on bars
	float rust = noise(px * 0.08);
	rust = smoothstep(0.65, 0.7, rust) * on_bar * 0.03;
	col += vec3(rust * 0.8, rust * 0.3, 0.0);

	COLOR = vec4(col, 1.0);
}
