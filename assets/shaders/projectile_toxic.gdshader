shader_type canvas_item;

uniform vec4 weapon_color : source_color = vec4(0.2, 1.0, 0.1, 1.0);
uniform float bubble_speed : hint_range(0.5, 4.0) = 2.0;
uniform float bubble_density : hint_range(1.0, 8.0) = 4.0;
uniform float drip_intensity : hint_range(0.0, 1.0) = 0.5;
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
	float modulate_alpha = COLOR.a;
	float t = TIME * animation_speed;
	vec2 uv = UV - 0.5;
	float dist = length(uv) * 2.0;

	// Bubbling: multiple noise layers scrolling upward at different speeds
	vec2 bubble_uv = UV * bubble_density;
	float b1 = noise(bubble_uv + vec2(0.0, -t * bubble_speed));
	float b2 = noise(bubble_uv * 1.7 + vec2(5.0, -t * bubble_speed * 1.3));
	float bubbles = b1 * b2;
	bubbles = smoothstep(0.15, 0.4, bubbles); // sharpen into blobs

	// Dripping upward motion (inverse drip)
	float drip_uv_y = UV.y + t * bubble_speed * 0.5;
	float drip = noise(vec2(UV.x * 6.0, drip_uv_y * 3.0));
	drip = pow(drip, 2.0) * drip_intensity;

	// Core glow
	float core = smoothstep(0.8, 0.0, dist);

	// Combine: globby toxic mass
	float intensity = (core * 0.5 + bubbles * 0.7 + drip * 0.4);
	intensity *= smoothstep(1.0, 0.5, dist); // fade at edges

	vec3 base_col = mix(weapon_color.rgb, vec3(1.0), color_mix);
	vec3 col = base_col * intensity * 2.5 * brightness;
	// Toxic highlight: brighter spots where bubbles are dense
	col += base_col * bubbles * bubbles * 1.0;
	col += vec3(1.0) * core * 0.2; // slight white-hot center

	float soft = mix(0.6, 0.95, edge_softness);
	float alpha = smoothstep(1.0, soft, dist) * weapon_color.a;
	alpha *= smoothstep(0.0, 0.15, intensity);

	if (use_mask) {
		float mask_alpha = texture(mask_texture, UV).a;
		alpha *= mask_alpha;
	}

	COLOR = vec4(col, alpha * modulate_alpha);
}
