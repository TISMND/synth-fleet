shader_type canvas_item;

uniform vec4 weapon_color : source_color = vec4(0.6, 0.6, 0.7, 1.0);
uniform float flow_speed : hint_range(0.5, 4.0) = 1.5;
uniform float density : hint_range(1.0, 6.0) = 3.0;
uniform float wisp_scale : hint_range(1.0, 8.0) = 4.0;
uniform float turbulence : hint_range(0.0, 1.0) = 0.5;
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
	float t = TIME * animation_speed;
	vec2 uv = UV - 0.5;
	float dist = length(uv) * 2.0;

	// Flowing smoke layers
	vec2 flow1 = UV * wisp_scale + vec2(t * flow_speed * 0.3, -t * flow_speed * 0.5);
	vec2 flow2 = UV * wisp_scale * 1.5 + vec2(-t * flow_speed * 0.4, t * flow_speed * 0.2) + 50.0;

	// Turbulence distortion
	float turb = noise(UV * 4.0 + t * 0.5) * turbulence * 0.3;
	flow1 += turb;
	flow2 -= turb;

	float smoke1 = fbm(flow1);
	float smoke2 = fbm(flow2);

	// Combine smoke layers with density control
	float smoke = (smoke1 + smoke2) * 0.5;
	smoke = pow(smoke, 2.0 - density * 0.25);

	// Wispy edges
	float wisp = smoothstep(0.8, 0.2, dist) * smoke;

	// Core nebula glow
	float core = smoothstep(0.6, 0.0, dist) * 0.5;
	float total = wisp + core;

	vec3 base_col = mix(weapon_color.rgb, vec3(1.0), color_mix);
	vec3 col = base_col * total * 2.0 * brightness;
	col += vec3(1.0) * core * 0.2;

	float soft = mix(0.6, 0.95, edge_softness);
	float alpha = smoothstep(1.0, soft, dist) * weapon_color.a;
	alpha *= smoothstep(0.05, 0.2, total);

	if (use_mask) {
		float mask_alpha = texture(mask_texture, UV).a;
		alpha *= mask_alpha;
	}

	COLOR = vec4(col, alpha);
}
