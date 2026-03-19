shader_type canvas_item;

uniform vec4 nebula_color : source_color = vec4(0.6, 0.2, 0.9, 1.0);
uniform vec4 secondary_color : source_color = vec4(0.1, 0.8, 0.6, 1.0);
uniform float brightness : hint_range(0.5, 4.0) = 1.5;
uniform float animation_speed : hint_range(0.0, 3.0) = 0.2;
uniform float density : hint_range(0.5, 4.0) = 2.0;
uniform float seed_offset : hint_range(0.0, 1000.0) = 0.0;

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
	vec2 uv = UV + seed_offset;

	// Domain warping — primary color layer
	vec2 q1 = vec2(fbm(uv * 3.0 + t * 0.1), fbm(uv * 3.0 + vec2(5.2, 1.3) + t * 0.15));
	vec2 r1 = vec2(fbm(uv * 3.0 + 4.0 * q1 + vec2(1.7, 9.2) + t * 0.05),
				   fbm(uv * 3.0 + 4.0 * q1 + vec2(8.3, 2.8) + t * 0.08));
	float swirl1 = fbm(uv * 3.0 + 3.0 * r1);

	// Domain warping — secondary color layer, offset and counter-flowing
	vec2 q2 = vec2(fbm(uv * 2.8 - t * 0.08 + 40.0), fbm(uv * 2.8 + vec2(3.1, 7.4) - t * 0.12 + 40.0));
	vec2 r2 = vec2(fbm(uv * 2.8 + 3.5 * q2 + vec2(6.1, 4.3) - t * 0.04 + 40.0),
				   fbm(uv * 2.8 + 3.5 * q2 + vec2(2.7, 8.1) - t * 0.06 + 40.0));
	float swirl2 = fbm(uv * 2.8 + 3.0 * r2 + 40.0);

	swirl1 = pow(swirl1, 2.0 - density * 0.3);
	swirl2 = pow(swirl2, 2.0 - density * 0.3);

	vec2 center = UV - 0.5;
	float dist = length(center) * 2.0;
	float falloff = smoothstep(1.0, 0.15, dist);

	// Additive dual color blend
	vec3 col1 = nebula_color.rgb * swirl1 * brightness;
	vec3 col2 = secondary_color.rgb * swirl2 * brightness;
	vec3 col = (col1 + col2) * falloff * 2.0;
	// Warping variation tint
	col += nebula_color.rgb * vec3(r1.x * 0.15) * falloff;
	col += secondary_color.rgb * vec3(r2.y * 0.15) * falloff;

	float alpha = max(swirl1, swirl2) * falloff * nebula_color.a;
	COLOR = vec4(col, alpha * modulate_alpha);
}
