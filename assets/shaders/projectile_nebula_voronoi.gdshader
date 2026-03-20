shader_type canvas_item;

uniform vec4 weapon_color : source_color = vec4(0.4, 0.9, 0.5, 1.0);
uniform float cell_scale : hint_range(2.0, 8.0) = 4.0;
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

vec2 hash2(vec2 p) {
	return vec2(hash(p), hash(p + vec2(127.1, 311.7)));
}

float voronoi(vec2 p, float t) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float min_dist = 1.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 point = hash2(i + neighbor);
			point = 0.5 + 0.5 * sin(t + 6.2831 * point);
			float d = length(neighbor + point - f);
			min_dist = min(min_dist, d);
		}
	}
	return min_dist;
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
	for (int i = 0; i < 4; i++) {
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

	float cells = voronoi(UV * cell_scale, t);
	float cloud = fbm(UV * 3.0 + t * 0.1);

	float combined = (1.0 - cells) * 0.7 + cloud * 0.5;
	combined = pow(combined, 2.0 - density * 0.3);

	// Circular falloff
	float soft = mix(0.5, 0.9, edge_softness);
	float falloff = smoothstep(1.0, soft, dist);

	float result = combined * falloff;
	vec3 base_col = mix(weapon_color.rgb, vec3(1.0), color_mix);
	vec3 col = base_col * result * brightness * 2.0;
	// Edge glow on cells
	col += base_col * smoothstep(0.3, 0.0, cells) * 0.3 * falloff;

	// White-hot core
	float core = smoothstep(0.4, 0.0, dist);
	col += vec3(1.0) * core * 0.2;

	float alpha = result * weapon_color.a;

	if (use_mask) {
		float mask_alpha = texture(mask_texture, UV).a;
		alpha *= mask_alpha;
	}

	COLOR = vec4(col, alpha * modulate_alpha);
}
