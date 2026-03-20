shader_type canvas_item;

uniform vec4 weapon_color : source_color = vec4(0.6, 0.2, 0.9, 1.0);
uniform float warp_strength : hint_range(1.0, 6.0) = 4.0;
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
	for (int i = 0; i < 6; i++) {
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

	// Domain warping: FBM offset by FBM
	vec2 q = vec2(fbm(UV * 3.0 + t * 0.1), fbm(UV * 3.0 + vec2(5.2, 1.3) + t * 0.15));
	vec2 r = vec2(fbm(UV * 3.0 + warp_strength * q + vec2(1.7, 9.2) + t * 0.05),
				  fbm(UV * 3.0 + warp_strength * q + vec2(8.3, 2.8) + t * 0.08));
	float swirl = fbm(UV * 3.0 + 3.0 * r);
	swirl = pow(swirl, 2.0 - density * 0.3);

	// Circular falloff
	float soft = mix(0.5, 0.9, edge_softness);
	float falloff = smoothstep(1.0, soft, dist);

	float cloud = swirl * falloff;
	vec3 base_col = mix(weapon_color.rgb, vec3(1.0), color_mix);
	vec3 col = base_col * cloud * brightness * 2.0;
	// Color variation from warping
	col += base_col * vec3(r.x, r.y, q.x) * 0.3 * falloff;

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
