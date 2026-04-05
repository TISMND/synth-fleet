shader_type canvas_item;
// Top-veil nebula overlay — scattered cloud tufts that the ship weaves through.
// High-frequency FBM at large scale produces many small pockets across the full radius.

uniform vec4 nebula_color : source_color = vec4(0.3, 0.4, 0.9, 1.0);
uniform float brightness : hint_range(0.5, 4.0) = 1.5;
uniform float animation_speed : hint_range(0.0, 3.0) = 0.3;
uniform float density : hint_range(0.5, 4.0) = 2.0;
uniform float seed_offset : hint_range(0.0, 1000.0) = 0.0;
uniform float radial_spread : hint_range(0.05, 1.0) = 0.2;
uniform float veil_contrast : hint_range(0.0, 1.0) = 0.5;
uniform float tuft_scale : hint_range(2.0, 20.0) = 8.0;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float ang_a = hash(i) * 6.2832;
	float ang_b = hash(i + vec2(1.0, 0.0)) * 6.2832;
	float ang_c = hash(i + vec2(0.0, 1.0)) * 6.2832;
	float ang_d = hash(i + vec2(1.0, 1.0)) * 6.2832;
	float a = dot(vec2(cos(ang_a), sin(ang_a)), f);
	float b = dot(vec2(cos(ang_b), sin(ang_b)), f - vec2(1.0, 0.0));
	float c = dot(vec2(cos(ang_c), sin(ang_c)), f - vec2(0.0, 1.0));
	float d = dot(vec2(cos(ang_d), sin(ang_d)), f - vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 0.5 + 0.5;
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 6; i++) {
		v += a * noise(p);
		p = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p * 2.0;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	float modulate_alpha = COLOR.a;
	float t = TIME * animation_speed;
	vec2 uv = UV + seed_offset;

	// High-frequency tufts — many small cloud pockets scattered evenly
	float tufts1 = fbm(uv * tuft_scale + vec2(t * 0.15, -t * 0.1));
	float tufts2 = fbm(uv * tuft_scale * 1.3 + vec2(-t * 0.12, t * 0.18) + 77.0);
	float combined = (tufts1 + tufts2 * 0.6) / 1.6;
	combined = pow(combined, 2.5 - density * 0.4);

	// Gentle radial falloff — very wide so tufts appear everywhere
	vec2 center = UV - 0.5;
	float dist = length(center) * 2.0;
	float falloff = smoothstep(1.0, 0.05, dist);

	float cloud = combined * falloff;

	// Edge contrast: gentle sharpening to define tuft boundaries without hard lines
	float edge_power = mix(1.0, 2.5, veil_contrast);
	float edge_threshold = mix(0.0, 0.2, veil_contrast);
	float edge_width = mix(0.5, 0.3, veil_contrast);
	float edge_alpha = smoothstep(edge_threshold, edge_threshold + edge_width, cloud);
	edge_alpha = pow(edge_alpha, edge_power);
	float final_alpha = mix(cloud, edge_alpha, veil_contrast);

	vec3 col = nebula_color.rgb * brightness * 1.5;

	COLOR = vec4(col, final_alpha * nebula_color.a * modulate_alpha);
}
