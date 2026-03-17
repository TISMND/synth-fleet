shader_type canvas_item;

uniform vec4 weapon_color : source_color = vec4(1.0, 0.4, 0.1, 1.0);
uniform float scroll_speed : hint_range(0.5, 5.0) = 2.0;
uniform float heat_distortion : hint_range(0.0, 0.3) = 0.1;
uniform float flame_detail : hint_range(1.0, 6.0) = 3.0;
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

float fbm(vec2 p, int octaves) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < octaves; i++) {
		v += a * noise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	float t = TIME * animation_speed;
	vec2 uv = UV;

	// Vertical gradient: hot at bottom, fading at top
	float vertical_grad = 1.0 - uv.y;

	// Heat distortion
	float distort = noise(uv * 8.0 + t * 3.0) * heat_distortion;
	vec2 distorted_uv = uv + vec2(distort, 0.0);

	// Upward-scrolling FBM noise for flame shape
	vec2 flame_uv = distorted_uv * vec2(3.0, 4.0);
	flame_uv.y -= t * scroll_speed;
	float flame = fbm(flame_uv, int(flame_detail));

	// Second layer for detail
	vec2 detail_uv = distorted_uv * vec2(5.0, 6.0);
	detail_uv.y -= t * scroll_speed * 1.3;
	float detail = fbm(detail_uv + 50.0, int(flame_detail));

	float combined = (flame * 0.6 + detail * 0.4) * vertical_grad;
	combined = pow(combined, 0.7);

	// Hot core at center
	float center_dist = abs(uv.x - 0.5) * 2.0;
	float core = smoothstep(0.8, 0.2, center_dist) * vertical_grad;
	combined = max(combined, core * 0.5);

	// Color: weapon_color base, white-hot core
	vec3 base_col = mix(weapon_color.rgb, vec3(1.0), color_mix);
	vec3 col = base_col * combined * 2.5 * brightness;
	col += vec3(1.0, 0.95, 0.8) * core * combined * 0.8;

	// Alpha with soft edges
	float soft_thresh = mix(0.2, 0.05, edge_softness);
	float alpha = smoothstep(0.05, soft_thresh + 0.15, combined) * weapon_color.a;
	alpha *= smoothstep(0.0, 0.1, uv.y) * smoothstep(1.0, 0.85, uv.y);

	if (use_mask) {
		float mask_alpha = texture(mask_texture, UV).a;
		alpha *= mask_alpha;
	}

	COLOR = vec4(col, alpha);
}
