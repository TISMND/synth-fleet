shader_type canvas_item;

uniform vec4 weapon_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float beam_speed : hint_range(0.5, 5.0) = 3.0;
uniform float beam_width : hint_range(0.1, 0.8) = 0.3;
uniform float flicker_rate : hint_range(0.0, 10.0) = 4.0;
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

void fragment() {
	float t = TIME * animation_speed;
	vec2 uv = UV;

	// Beam runs vertically (x = width, y = length)
	float center_dist = abs(uv.x - 0.5) * 2.0; // 0 at center, 1 at edge

	// Animated noise distortion along beam
	float n = noise(vec2(uv.y * 4.0 - t * beam_speed, uv.x * 2.0));
	float distorted_dist = center_dist + (n - 0.5) * 0.3;

	// Core beam
	float beam = smoothstep(beam_width + 0.2, beam_width * 0.5, distorted_dist);

	// Hot center
	float core = smoothstep(beam_width * 0.5, 0.0, distorted_dist);

	// Flickering energy
	float flicker = 0.85 + 0.15 * sin(t * flicker_rate * TAU + uv.y * 20.0);

	// Edge energy wisps
	float wisps = noise(vec2(uv.y * 8.0 - t * beam_speed * 1.5, center_dist * 3.0));
	float wisp_edge = mix(beam_width + 0.2, beam_width + 0.5, edge_softness);
	wisps *= smoothstep(wisp_edge, beam_width, center_dist) * 0.5;

	// HDR output
	float intensity = (beam * 2.0 + core * 1.5 + wisps) * flicker;
	vec3 base_col = mix(weapon_color.rgb, vec3(1.0), color_mix);
	vec3 col = base_col * intensity * brightness;
	col += vec3(1.0) * core * 0.4 * flicker; // white hot core

	float alpha = max(beam, wisps * 0.8) * weapon_color.a;

	if (use_mask) {
		float mask_alpha = texture(mask_texture, UV).a;
		alpha *= mask_alpha;
	}

	COLOR = vec4(col, alpha);
}
