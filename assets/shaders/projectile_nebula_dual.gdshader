shader_type canvas_item;

uniform vec4 weapon_color : source_color = vec4(0.2, 0.5, 1.0, 1.0);
uniform vec4 secondary_color : source_color = vec4(1.0, 0.3, 0.5, 1.0);
uniform float density : hint_range(0.5, 4.0) = 2.0;
uniform sampler2D mask_texture : hint_default_white;
uniform bool use_mask = false;

// Universal params
uniform float brightness : hint_range(0.5, 4.0) = 1.5;
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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
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

	float layer1 = fbm(UV * 3.5 + vec2(t * 0.2, -t * 0.15));
	float layer2 = fbm(UV * 3.0 + vec2(-t * 0.15, t * 0.2) + 100.0);

	layer1 = pow(layer1, 2.0 - density * 0.25);
	layer2 = pow(layer2, 2.0 - density * 0.25);

	// Circular falloff for projectile shape
	float soft = mix(0.5, 0.9, edge_softness);
	float falloff = smoothstep(1.0, soft, dist);

	// Additive blend of two colored layers
	vec3 base1 = mix(weapon_color.rgb, vec3(1.0), color_mix);
	vec3 base2 = mix(secondary_color.rgb, vec3(1.0), color_mix);
	vec3 col = (base1 * layer1 + base2 * layer2) * falloff * 2.0 * brightness;

	// White-hot core
	float core = smoothstep(0.6, 0.0, dist);
	col += vec3(1.0) * core * 0.3;

	float alpha = max(layer1, layer2) * falloff * weapon_color.a;

	if (use_mask) {
		float mask_alpha = texture(mask_texture, UV).a;
		alpha *= mask_alpha;
	}

	COLOR = vec4(col, alpha * modulate_alpha);
}
