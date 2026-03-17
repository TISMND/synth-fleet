shader_type canvas_item;

uniform vec4 weapon_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float scroll_speed : hint_range(0.5, 5.0) = 2.0;
uniform float distortion : hint_range(0.0, 0.5) = 0.15;
uniform float edge_glow : hint_range(0.5, 3.0) = 1.5;
uniform sampler2D mask_texture : hint_default_white;
uniform bool use_mask = false;

// Simple hash-based noise (no texture needed)
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
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV - 0.5;
	float dist = length(uv) * 2.0;

	// Swirling noise
	float angle = atan(uv.y, uv.x);
	vec2 noise_uv = vec2(angle * 0.5 + TIME * scroll_speed * 0.3, dist * 3.0 - TIME * scroll_speed);
	float n1 = fbm(noise_uv * 2.0);
	float n2 = fbm(noise_uv * 3.0 + vec2(5.0, 3.0) + TIME * scroll_speed * 0.5);

	// Distorted UV for energy swirl
	vec2 distorted = uv + vec2(n1 - 0.5, n2 - 0.5) * distortion;
	float distorted_dist = length(distorted) * 2.0;

	// Edge glow (fresnel-like)
	float edge = smoothstep(0.3, 0.9, dist);
	float inner = smoothstep(1.0, 0.0, distorted_dist);

	// Core energy
	float energy = mix(n1, n2, 0.5) * inner;
	energy = pow(energy, 0.8);

	// Bright rim
	float rim = smoothstep(0.7, 0.95, dist) * smoothstep(1.1, 0.95, dist) * edge_glow;

	// Combine: HDR weapon color for bloom
	vec3 col = weapon_color.rgb * (energy * 2.0 + rim * 1.5);
	col += vec3(1.0) * energy * 0.3; // white hot core

	// Alpha: circular mask with soft edge
	float alpha = smoothstep(1.0, 0.7, dist) * weapon_color.a;

	if (use_mask) {
		float mask_alpha = texture(mask_texture, UV).a;
		alpha *= mask_alpha;
	}

	COLOR = vec4(col, alpha);
}
