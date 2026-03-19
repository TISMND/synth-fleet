shader_type canvas_item;

uniform vec4 nebula_color : source_color = vec4(1.0, 0.6, 0.2, 1.0);
uniform float brightness : hint_range(0.5, 4.0) = 2.0;
uniform float animation_speed : hint_range(0.0, 3.0) = 0.5;
uniform float density : hint_range(0.5, 4.0) = 2.0;
uniform float seed_offset : hint_range(0.0, 1000.0) = 0.0;

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
	float modulate_alpha = COLOR.a;
	float t = TIME * animation_speed;
	vec2 uv = UV;
	vec2 offset_uv = UV + seed_offset;
	vec2 center = UV - 0.5;
	float dist = length(center) * 2.0;
	float angle = atan(center.y, center.x);

	// Base nebula cloud
	float cloud = fbm(offset_uv * 3.0 + vec2(t * 0.06, -t * 0.04));
	cloud = pow(cloud, 2.5 - density * 0.3);
	float falloff = smoothstep(1.0, 0.2, dist);

	// Radial flare rays — noise-modulated angular brightness
	float ray_noise = noise(vec2(angle * 3.0 + t * 0.3, seed_offset + 1.0));
	float ray_noise2 = noise(vec2(angle * 5.0 - t * 0.4, seed_offset + 20.0));
	float rays = pow(ray_noise, 2.0) * 0.7 + pow(ray_noise2, 3.0) * 0.4;
	// Rays fade with distance from center
	float ray_falloff = smoothstep(0.8, 0.1, dist);
	rays *= ray_falloff;

	// Pulsing flare events at random positions
	float pulse_cycle = t * 0.7;
	float pulse_id = floor(pulse_cycle);
	float pulse_phase = fract(pulse_cycle);
	float pulse_env = smoothstep(0.0, 0.05, pulse_phase) * smoothstep(0.6, 0.05, pulse_phase);

	vec2 flare_pos = vec2(0.3 + hash(vec2(pulse_id, seed_offset + 10.0)) * 0.4,
						  0.3 + hash(vec2(pulse_id, seed_offset + 11.0)) * 0.4);
	float flare_dist = length(uv - flare_pos);
	float flare = exp(-flare_dist * flare_dist * 40.0) * pulse_env;

	// Second flare, offset timing
	float pulse_phase2 = fract(pulse_cycle + 0.45);
	float pulse_env2 = smoothstep(0.0, 0.05, pulse_phase2) * smoothstep(0.5, 0.05, pulse_phase2);
	float pulse_id2 = floor(pulse_cycle + 0.45);
	vec2 flare_pos2 = vec2(0.25 + hash(vec2(pulse_id2, seed_offset + 20.0)) * 0.5,
						   0.25 + hash(vec2(pulse_id2, seed_offset + 21.0)) * 0.5);
	float flare2 = exp(-length(uv - flare_pos2) * length(uv - flare_pos2) * 50.0) * pulse_env2;

	float total_flare = flare + flare2 * 0.7;

	// Combine
	float nebula = cloud * falloff;
	vec3 col = nebula_color.rgb * nebula * brightness * 1.2;
	col += nebula_color.rgb * rays * brightness * 1.5;
	// Flares are white-hot center, tinted outer
	col += vec3(1.0) * total_flare * brightness * 1.5;
	col += nebula_color.rgb * total_flare * brightness * 0.8;
	// Flares illuminate nearby cloud
	col += nebula_color.rgb * cloud * (flare * 0.5 + flare2 * 0.3) * brightness;

	float alpha = max(nebula + rays * 0.5, total_flare * 0.8) * nebula_color.a;
	alpha *= smoothstep(1.0, 0.35, dist);
	alpha = clamp(alpha, 0.0, 1.0);
	COLOR = vec4(col, alpha * modulate_alpha);
}
