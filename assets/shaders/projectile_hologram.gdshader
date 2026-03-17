shader_type canvas_item;

uniform vec4 weapon_color : source_color = vec4(0.0, 0.8, 1.0, 1.0);
uniform float scan_speed : hint_range(1.0, 10.0) = 4.0;
uniform float scan_density : hint_range(4.0, 40.0) = 20.0;
uniform float aberration : hint_range(0.0, 0.1) = 0.03;
uniform float flicker_rate : hint_range(0.0, 8.0) = 3.0;
uniform sampler2D mask_texture : hint_default_white;
uniform bool use_mask = false;

// Universal params
uniform float brightness : hint_range(0.5, 4.0) = 1.0;
uniform float color_mix : hint_range(0.0, 1.0) = 0.0;
uniform float animation_speed : hint_range(0.1, 3.0) = 1.0;
uniform float edge_softness : hint_range(0.0, 1.0) = 0.5;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	float t = TIME * animation_speed;
	vec2 uv = UV - 0.5;
	float dist = length(uv) * 2.0;

	// Horizontal scanlines
	float scan_y = UV.y * scan_density + t * scan_speed;
	float scanline = 0.7 + 0.3 * sin(scan_y * TAU);

	// Chromatic aberration — offset R and B channels
	float r_offset = aberration;
	float b_offset = -aberration;
	vec2 uv_r = UV + vec2(r_offset, 0.0);
	vec2 uv_b = UV + vec2(b_offset, 0.0);

	// Base shape (circular)
	float shape = smoothstep(1.0, 0.5, dist);
	float shape_r = smoothstep(1.0, 0.5, length(uv_r - 0.5) * 2.0);
	float shape_b = smoothstep(1.0, 0.5, length(uv_b - 0.5) * 2.0);

	// Flicker
	float flicker = 1.0;
	if (flicker_rate > 0.0) {
		float flicker_hash = hash(vec2(floor(t * flicker_rate), 0.0));
		flicker = flicker_hash > 0.1 ? 1.0 : 0.3; // occasional dropout
	}

	// Combine with chromatic split
	vec3 base_col = mix(weapon_color.rgb, vec3(1.0), color_mix);
	vec3 col;
	col.r = base_col.r * shape_r * 1.2;
	col.g = base_col.g * shape;
	col.b = base_col.b * shape_b * 1.2;

	col *= scanline * flicker * 2.0 * brightness;

	// Core glow
	float core = smoothstep(0.6, 0.0, dist);
	col += vec3(1.0) * core * 0.3;

	float soft = mix(0.6, 0.95, edge_softness);
	float alpha = smoothstep(1.0, soft, dist) * weapon_color.a * flicker;
	alpha *= (scanline * 0.5 + 0.5); // scanlines modulate alpha slightly

	if (use_mask) {
		float mask_alpha = texture(mask_texture, UV).a;
		alpha *= mask_alpha;
	}

	COLOR = vec4(col, alpha);
}
