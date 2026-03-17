shader_type canvas_item;

uniform vec4 weapon_color : source_color = vec4(1.0, 0.0, 0.5, 1.0);
uniform float block_size : hint_range(2.0, 20.0) = 8.0;
uniform float glitch_rate : hint_range(1.0, 12.0) = 6.0;
uniform float rgb_split : hint_range(0.0, 0.15) = 0.05;
uniform float intensity : hint_range(0.2, 1.0) = 0.7;
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
	float t = TIME * animation_speed;
	vec2 uv = UV - 0.5;
	float dist = length(uv) * 2.0;

	// Quantized time for block artifacts
	float block_time = floor(t * glitch_rate) / glitch_rate;

	// Block displacement
	vec2 block_uv = floor(UV * block_size) / block_size;
	float block_hash = hash(block_uv + block_time);
	float block_active = step(1.0 - intensity, block_hash);

	// Horizontal displacement for active blocks
	float h_disp = (hash(vec2(block_uv.y, block_time)) - 0.5) * 0.3 * block_active;
	vec2 displaced_uv = UV + vec2(h_disp, 0.0);

	// RGB split
	float split = rgb_split * (0.5 + block_active * 0.5);
	vec2 uv_r = displaced_uv + vec2(split, 0.0);
	vec2 uv_g = displaced_uv;
	vec2 uv_b = displaced_uv - vec2(split, 0.0);

	// Base circular shape at each offset
	float shape_r = smoothstep(1.0, 0.4, length(uv_r - 0.5) * 2.0);
	float shape_g = smoothstep(1.0, 0.4, length(uv_g - 0.5) * 2.0);
	float shape_b = smoothstep(1.0, 0.4, length(uv_b - 0.5) * 2.0);

	// Digital noise overlay
	float digital_noise = hash(UV * 100.0 + block_time);
	digital_noise = step(0.85, digital_noise) * 0.4 * intensity;

	vec3 base_col = mix(weapon_color.rgb, vec3(1.0), color_mix);
	vec3 col;
	col.r = base_col.r * shape_r;
	col.g = base_col.g * shape_g;
	col.b = base_col.b * shape_b;

	col *= 2.0 * brightness;
	col += vec3(digital_noise); // random pixel noise

	// Core brightness
	float core = smoothstep(0.6, 0.0, dist);
	col += base_col * core * 0.5;

	float soft = mix(0.6, 0.95, edge_softness);
	float alpha = smoothstep(1.0, soft, dist) * weapon_color.a;
	alpha = max(alpha, (shape_r + shape_g + shape_b) * 0.3 * weapon_color.a);

	if (use_mask) {
		float mask_alpha = texture(mask_texture, UV).a;
		alpha *= mask_alpha;
	}

	COLOR = vec4(col, alpha);
}
