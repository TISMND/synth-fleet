shader_type canvas_item;

uniform vec4 weapon_color : source_color = vec4(0.3, 0.6, 1.0, 1.0);
uniform float branch_density : hint_range(1.0, 8.0) = 4.0;
uniform float flicker_speed : hint_range(2.0, 16.0) = 8.0;
uniform float arc_width : hint_range(0.02, 0.2) = 0.1;
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
	float center_x = uv.x - 0.5;

	// Flickering time
	float flicker = floor(t * flicker_speed) / flicker_speed;

	// Multiple lightning branches
	float lightning = 0.0;
	for (float b = 0.0; b < 3.0; b += 1.0) {
		// Each branch has its own offset and noise
		float branch_offset = (b - 1.0) * 0.15;
		vec2 noise_uv = vec2(uv.y * branch_density + b * 7.0, flicker + b * 3.0);
		float displacement = (noise(noise_uv * 3.0) - 0.5) * 0.4;
		displacement += (noise(noise_uv * 8.0) - 0.5) * 0.15;

		float dist = abs(center_x - displacement - branch_offset);
		float aw = mix(arc_width * 0.8, arc_width * 1.5, edge_softness);
		float branch_line = smoothstep(aw, aw * 0.2, dist);

		// Intensity varies per branch
		float branch_intensity = 0.5 + 0.5 * noise(vec2(b * 5.0, flicker));
		lightning += branch_line * branch_intensity;
	}

	lightning = clamp(lightning, 0.0, 1.0);

	// Ambient electric glow around center
	float glow = smoothstep(0.5, 0.0, abs(center_x)) * 0.3;
	float flicker_pulse = 0.7 + 0.3 * sin(t * flicker_speed * 0.7);

	// Combine
	float intensity = lightning + glow * flicker_pulse;

	// HDR color
	vec3 base_col = mix(weapon_color.rgb, vec3(1.0), color_mix);
	vec3 col = base_col * intensity * 2.5 * brightness;
	col += vec3(1.0) * lightning * lightning * 0.6; // white-hot arcs

	float alpha = smoothstep(0.01, 0.1, intensity) * weapon_color.a;

	if (use_mask) {
		float mask_alpha = texture(mask_texture, UV).a;
		alpha *= mask_alpha;
	}

	COLOR = vec4(col, alpha);
}
