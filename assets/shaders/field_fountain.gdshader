shader_type canvas_item;
// Particle fountain — particles erupt outward from the center and fade,
// like a firework or radial emitter. Continuous stream of outbound sparks.

uniform vec4 field_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float brightness : hint_range(0.0, 4.0) = 1.0;
uniform float animation_speed : hint_range(0.0, 3.0) = 1.0;
uniform float radius_ratio : hint_range(0.0, 1.0) = 0.8;
uniform float pulse_intensity : hint_range(0.0, 4.0) = 0.0;
uniform float pulse_tint : hint_range(0.0, 1.0) = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

// Per-shader params
uniform float particle_count : hint_range(4.0, 48.0) = 20.0;
uniform float emit_speed : hint_range(0.2, 4.0) = 1.2;
uniform float particle_size : hint_range(0.005, 0.08) = 0.03;
uniform float spread : hint_range(0.0, 1.0) = 0.3;
uniform float lifetime_variance : hint_range(0.0, 1.0) = 0.5;
uniform float outer_radius : hint_range(0.0, 1.0) = 0.95;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	float modulate_alpha = COLOR.a;
	float t = TIME * animation_speed;
	vec2 uv = UV - 0.5;
	float raw_dist = length(uv) * 2.0;

	vec2 scaled_uv = uv / max(outer_radius, 0.01);
	float total = 0.0;
	float pc = max(particle_count, 1.0);

	for (float i = 0.0; i < 48.0; i++) {
		if (i >= particle_count) break;

		// Each particle has a unique angle and timing
		float seed1 = hash(vec2(i, 0.0));
		float seed2 = hash(vec2(i, 1.0));
		float seed3 = hash(vec2(i, 2.0));

		float base_angle = seed1 * TAU;
		// Slight angular wobble over time
		float angle = base_angle + sin(t * 0.7 + i * 1.3) * spread;

		// Stagger emission — each particle has its own cycle
		float cycle_length = 1.0 / max(emit_speed, 0.01);
		float life_var = 1.0 - lifetime_variance * 0.5 + lifetime_variance * seed2;
		float particle_t = fract(t * emit_speed / pc + seed1);

		// Particle position: starts at center, moves outward
		float radius = particle_t * 0.48 * life_var;
		vec2 pos = vec2(cos(angle), sin(angle)) * radius;

		// Brightness fades as particle ages
		float age_fade = 1.0 - particle_t;
		age_fade = pow(age_fade, 1.5);

		// Size grows slightly then shrinks
		float size_mod = sin(particle_t * PI);
		float ps = max(particle_size * (0.5 + size_mod * 0.5), 0.001);

		float d = length(scaled_uv - pos);
		float glow = smoothstep(ps, 0.0, d);
		glow = pow(glow, 1.3);

		total += glow * age_fade;
	}

	// Soft center emission point
	float center_dist = length(scaled_uv) * 2.0;
	float emitter = pow(max(0.0, 1.0 - center_dist * 4.0), 2.0) * 0.2;

	float intensity = (total + emitter) * brightness;
	intensity += intensity * pulse_intensity * 1.5;

	vec3 col = field_color.rgb * intensity;
	col += vec3(1.0) * total * 0.1;

	float alpha = clamp(intensity * 0.9, 0.0, 1.0) * opacity;
	if (raw_dist > 1.0) alpha = 0.0;

	float pt = pulse_tint * smoothstep(0.0, 0.3, pulse_intensity);
	col = mix(col, field_color.rgb * max(max(col.r, col.g), col.b), pt);
	COLOR = vec4(col, alpha * modulate_alpha);
}
