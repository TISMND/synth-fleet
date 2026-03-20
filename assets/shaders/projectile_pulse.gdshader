shader_type canvas_item;

uniform vec4 weapon_color : source_color = vec4(1.0, 0.5, 0.0, 1.0);
uniform float ring_count : hint_range(2.0, 10.0) = 5.0;
uniform float ring_speed : hint_range(0.5, 4.0) = 2.0;
uniform float ring_width : hint_range(0.02, 0.2) = 0.08;
uniform float fade_rate : hint_range(0.5, 3.0) = 1.5;
uniform sampler2D mask_texture : hint_default_white;
uniform bool use_mask = false;

// Universal params
uniform float brightness : hint_range(0.5, 4.0) = 1.0;
uniform float color_mix : hint_range(0.0, 1.0) = 0.0;
uniform float animation_speed : hint_range(0.1, 3.0) = 1.0;
uniform float edge_softness : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	float modulate_alpha = COLOR.a;
	float t = TIME * animation_speed;
	vec2 uv = UV - 0.5;
	float dist = length(uv) * 2.0;

	// Expanding concentric rings
	float rings = 0.0;
	for (float i = 0.0; i < 10.0; i++) {
		if (i >= ring_count) break;
		// Each ring expands outward over time
		float phase = fract(t * ring_speed / ring_count + i / ring_count);
		float ring_radius = phase;
		float ring_dist = abs(dist - ring_radius);
		float ring = smoothstep(ring_width, ring_width * 0.2, ring_dist);
		// Fade as ring expands
		float ring_fade = pow(1.0 - phase, fade_rate);
		rings += ring * ring_fade;
	}

	rings = clamp(rings, 0.0, 1.0);

	// Central dot
	float core = smoothstep(0.2, 0.0, dist);

	float total = rings + core;

	vec3 base_col = mix(weapon_color.rgb, vec3(1.0), color_mix);
	vec3 col = base_col * total * 2.5 * brightness;
	col += vec3(1.0) * core * 0.4; // white center

	float soft = mix(0.6, 0.95, edge_softness);
	float alpha = smoothstep(1.0, soft, dist) * weapon_color.a;
	alpha *= smoothstep(0.0, 0.05, total);

	if (use_mask) {
		float mask_alpha = texture(mask_texture, UV).a;
		alpha *= mask_alpha;
	}

	COLOR = vec4(col, alpha * modulate_alpha);
}
