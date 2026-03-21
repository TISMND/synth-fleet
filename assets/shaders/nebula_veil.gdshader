shader_type canvas_item;
// Top-veil nebula overlay — emphasizes cloud edges rippling across the ship.
// Uses the same FBM noise as classic_fbm but with edge contrast control.

uniform vec4 nebula_color : source_color = vec4(0.3, 0.4, 0.9, 1.0);
uniform float brightness : hint_range(0.5, 4.0) = 1.5;
uniform float animation_speed : hint_range(0.0, 3.0) = 0.3;
uniform float density : hint_range(0.5, 4.0) = 2.0;
uniform float seed_offset : hint_range(0.0, 1000.0) = 0.0;
uniform float radial_spread : hint_range(0.05, 1.0) = 0.2;
uniform float veil_contrast : hint_range(0.0, 1.0) = 0.5;

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

	float layer1 = fbm(uv * 3.0 + vec2(t * 0.2, -t * 0.15));
	float layer2 = fbm(uv * 4.5 + vec2(-t * 0.1, t * 0.25) + 50.0);
	float combined = (layer1 + layer2 * 0.7) / 1.7;
	combined = pow(combined, 2.5 - density * 0.4);

	// Radial falloff — much wider than the bottom layer so the veil covers
	// the full nebula radius. The bottom layer concentrates at center;
	// the veil spreads out so the ship sees cloud edges everywhere.
	vec2 center = UV - 0.5;
	float dist = length(center) * 2.0;
	float wide_spread = min(radial_spread * 3.0, 0.95);
	float falloff = smoothstep(1.0, 1.0 - wide_spread, dist);

	float cloud = combined * falloff;

	// Edge contrast: sharpen the alpha curve to emphasize cloud boundaries.
	// At veil_contrast=0 this behaves like the original smooth overlay.
	// At veil_contrast=1 it approaches a hard cutoff — you see distinct cloud edges.
	float edge_power = mix(1.0, 5.0, veil_contrast);
	float edge_threshold = mix(0.0, 0.3, veil_contrast);
	float edge_alpha = smoothstep(edge_threshold, edge_threshold + 0.15, cloud);
	edge_alpha = pow(edge_alpha, edge_power);
	// Blend between smooth original and edge-emphasized version
	float final_alpha = mix(cloud, edge_alpha, veil_contrast);

	vec3 col = nebula_color.rgb * brightness * 1.5;

	COLOR = vec4(col, final_alpha * nebula_color.a * modulate_alpha);
}
