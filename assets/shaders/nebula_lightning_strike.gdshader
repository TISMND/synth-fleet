shader_type canvas_item;
// Stormy cloud base — sharp-edged turbulent nebula.
// Lightning is handled exclusively by the storm overlay layer.

uniform vec4 nebula_color : source_color = vec4(0.5, 0.6, 1.0, 1.0);
uniform float brightness : hint_range(0.5, 4.0) = 2.0;
uniform float animation_speed : hint_range(0.0, 3.0) = 1.0;
uniform float density : hint_range(0.5, 4.0) = 2.0;
uniform float seed_offset : hint_range(0.0, 1000.0) = 0.0;
uniform float radial_spread : hint_range(0.05, 1.0) = 0.2;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
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
	vec2 offset_uv = UV + seed_offset;

	// Turbulent cloud with sharp edges — gives that stormy thunderhead feel
	float cloud = fbm(offset_uv * 3.0 + vec2(t * 0.05, -t * 0.03));
	cloud = pow(cloud, 2.5 - density * 0.3);

	vec2 center = UV - 0.5;
	float dist = length(center) * 2.0;
	float falloff = smoothstep(1.0, 1.0 - radial_spread, dist);

	float nebula = cloud * falloff;
	vec3 col = nebula_color.rgb * nebula * brightness;

	float alpha = nebula * nebula_color.a;
	alpha *= smoothstep(1.0, 0.4, dist);
	COLOR = vec4(col, alpha * modulate_alpha);
}
