shader_type canvas_item;
// Gravity well — particles stream inward from the edge toward the center,
// creating a "pulling in" effect like a tractor beam or black hole.

uniform vec4 field_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float brightness : hint_range(0.0, 4.0) = 1.0;
uniform float animation_speed : hint_range(0.0, 3.0) = 1.0;
uniform float radius_ratio : hint_range(0.0, 1.0) = 0.8;
uniform float pulse_intensity : hint_range(0.0, 4.0) = 0.0;
uniform float pulse_tint : hint_range(0.0, 1.0) = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

// Per-shader params
uniform float stream_count : hint_range(1.0, 24.0) = 10.0;
uniform float stream_speed : hint_range(0.0, 4.0) = 1.5;
uniform float stream_width : hint_range(0.01, 0.4) = 0.15;
uniform float curl_amount : hint_range(0.0, 3.0) = 0.8;
uniform float fade_sharpness : hint_range(0.5, 4.0) = 2.0;
uniform float outer_radius : hint_range(0.0, 1.0) = 0.95;

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
	float raw_dist = length(uv) * 2.0;
	float dist = raw_dist / max(outer_radius, 0.01);
	float angle = atan(uv.y, uv.x);

	// Curl the angle based on distance — closer to center = more spiral
	float curled_angle = angle + curl_amount * (1.0 - dist);

	float sc = max(stream_count, 1.0);
	float total = 0.0;

	// Inward-streaming particles along radial lines
	for (float i = 0.0; i < 24.0; i++) {
		if (i >= stream_count) break;
		float base_angle = i / sc * TAU;
		float speed_var = 0.8 + hash(vec2(i, 7.0)) * 0.4;

		// Angular distance to this stream
		float ang_diff = curled_angle - base_angle;
		ang_diff = mod(ang_diff + PI, TAU) - PI;
		float sw = max(stream_width, 0.001);
		float stream = smoothstep(sw, sw * 0.2, abs(ang_diff));

		// Inward motion — particles travel from outer edge toward center
		float phase = fract(dist * 2.0 + t * stream_speed * speed_var + hash(vec2(i, 3.0)));

		// Particle-like bright spots along the stream
		float particle = pow(phase, fade_sharpness) * (1.0 - phase);
		particle *= 4.0; // normalize brightness

		// Fade out at center and at outer edge
		float radial_fade = smoothstep(0.0, 0.15, dist) * smoothstep(1.05, 0.85, dist);

		total += stream * particle * radial_fade;
	}

	// Soft core glow
	float core = pow(max(0.0, 1.0 - dist * 1.2), 3.0) * 0.3;

	float intensity = (total + core) * brightness;
	intensity += intensity * pulse_intensity * 1.5;

	vec3 col = field_color.rgb * intensity;
	col += vec3(1.0) * total * 0.1;

	float alpha = clamp(intensity * 0.8, 0.0, 1.0) * opacity;
	if (raw_dist > 1.0) alpha = 0.0;

	float pt = pulse_tint * smoothstep(0.0, 0.3, pulse_intensity);
	col = mix(col, field_color.rgb * max(max(col.r, col.g), col.b), pt);
	COLOR = vec4(col, alpha * modulate_alpha);
}
