shader_type canvas_item;

uniform vec4 weapon_color : source_color = vec4(0.3, 0.8, 1.0, 1.0);
uniform float ridge_sharpness : hint_range(0.5, 4.0) = 2.0;
uniform float density : hint_range(0.5, 4.0) = 2.0;
uniform sampler2D mask_texture : hint_default_white;
uniform bool use_mask = false;

// Universal params
uniform float brightness : hint_range(0.5, 4.0) = 1.8;
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

float ridged_noise(vec2 p) {
	return 1.0 - abs(noise(p) * 2.0 - 1.0);
}

float ridged_fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * ridged_noise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	float modulate_alpha = COLOR.a;
	float t = TIME * animation_speed;
	vec2 uv = UV - 0.5;
	float dist = length(uv) * 2.0;

	float ridge1 = ridged_fbm(UV * 4.0 + vec2(t * 0.2, -t * 0.3));
	float ridge2 = ridged_fbm(UV * 3.0 + vec2(-t * 0.15, t * 0.25) + 50.0);

	float combined = ridge1 * 0.6 + ridge2 * 0.5;
	combined = pow(combined, 2.0 - density * 0.3);

	// Circular falloff
	float soft = mix(0.5, 0.9, edge_softness);
	float falloff = smoothstep(1.0, soft, dist);

	float cloud = combined * falloff;
	vec3 base_col = mix(weapon_color.rgb, vec3(1.0), color_mix);
	vec3 col = base_col * cloud * brightness * 2.0;
	// Bright filament highlights from ridge sharpness
	col += vec3(1.0) * pow(ridge1, ridge_sharpness) * 0.4 * falloff * brightness;

	// White-hot core
	float core = smoothstep(0.4, 0.0, dist);
	col += vec3(1.0) * core * 0.2;

	float alpha = cloud * weapon_color.a;

	if (use_mask) {
		float mask_alpha = texture(mask_texture, UV).a;
		alpha *= mask_alpha;
	}

	COLOR = vec4(col, alpha * modulate_alpha);
}
