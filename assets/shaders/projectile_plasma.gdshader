shader_type canvas_item;

uniform vec4 weapon_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float turbulence_speed : hint_range(0.5, 5.0) = 2.0;
uniform float pulse_rate : hint_range(0.5, 4.0) = 1.5;
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

	// Two noise layers scrolling in different directions
	float ts = t * turbulence_speed;
	float n1 = noise(uv * 6.0 + vec2(ts * 0.7, -ts * 0.5));
	float n2 = noise(uv * 8.0 + vec2(-ts * 0.6, ts * 0.8) + 50.0);
	float combined = (n1 + n2) * 0.5;

	// Pulsing intensity
	float pulse = 0.8 + 0.2 * sin(t * pulse_rate * TAU);

	// Bright plasma core
	float core = smoothstep(0.8, 0.0, dist);
	float plasma = combined * core * pulse;

	// Bright rim for edge detection
	float rim = smoothstep(0.6, 0.85, dist) * smoothstep(1.05, 0.85, dist);
	rim *= 2.0 * pulse;

	// HDR color output
	vec3 base_col = mix(weapon_color.rgb, vec3(1.0), color_mix);
	vec3 col = base_col * (plasma * 2.5 + rim * 1.8) * brightness;
	col += vec3(1.0, 0.95, 0.9) * core * plasma * 0.5; // hot white center

	float soft = mix(0.55, 0.9, edge_softness);
	float alpha = smoothstep(1.0, soft, dist) * weapon_color.a;

	if (use_mask) {
		float mask_alpha = texture(mask_texture, UV).a;
		alpha *= mask_alpha;
	}

	COLOR = vec4(col, alpha);
}
