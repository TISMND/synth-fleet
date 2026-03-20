shader_type canvas_item;

uniform vec4 weapon_color : source_color = vec4(0.5, 0.0, 1.0, 1.0);
uniform float pulse_speed : hint_range(0.5, 4.0) = 1.5;
uniform float edge_width : hint_range(0.05, 0.4) = 0.15;
uniform float inner_darkness : hint_range(0.5, 1.0) = 0.9;
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
	float modulate_alpha = COLOR.a;
	float t = TIME * animation_speed;
	vec2 uv = UV - 0.5;
	float dist = length(uv) * 2.0;

	// Rotating edge noise
	float angle = atan(uv.y, uv.x);
	float rotating_angle = angle + t * pulse_speed * 0.5;
	float edge_noise = noise(vec2(rotating_angle * 3.0, dist * 5.0 + t * pulse_speed));

	// Pulsing edge ring
	float pulse = 0.9 + 0.1 * sin(t * pulse_speed * TAU);
	float edge_inner = 1.0 - edge_width * 2.0;
	float edge_outer = 1.0;

	float edge_ring = smoothstep(edge_inner - 0.05, edge_inner + 0.05, dist * pulse);
	edge_ring *= smoothstep(edge_outer + 0.05, edge_outer - 0.05, dist * pulse);
	edge_ring += edge_noise * 0.3 * smoothstep(edge_inner - 0.1, edge_inner + 0.1, dist);

	// Dark center (inverse glow)
	float dark_core = smoothstep(edge_inner, 0.0, dist) * inner_darkness;

	// Bright glowing edge
	float glow = edge_ring * (1.5 + edge_noise * 0.5);

	// Outer fade
	float soft = mix(0.8, 1.1, edge_softness);
	float outer_alpha = smoothstep(soft + 0.1, soft - 0.2, dist);

	// Color: bright edge, dark center
	vec3 base_col = mix(weapon_color.rgb, vec3(1.0), color_mix);
	vec3 edge_col = base_col * glow * 3.0 * brightness;
	edge_col += vec3(1.0) * edge_ring * 0.4; // white highlights on edge

	// Dark center absorbs color
	vec3 center_col = vec3(0.02, 0.0, 0.05) * dark_core;

	vec3 col = edge_col + center_col;

	// Alpha: visible where there's edge glow or dark core
	float alpha = max(glow * 0.8, dark_core * 0.9) * outer_alpha * weapon_color.a;

	if (use_mask) {
		float mask_alpha = texture(mask_texture, UV).a;
		alpha *= mask_alpha;
	}

	COLOR = vec4(col, alpha * modulate_alpha);
}
