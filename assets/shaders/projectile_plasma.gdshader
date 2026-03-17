shader_type canvas_item;

uniform vec4 weapon_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float turbulence_speed : hint_range(0.5, 5.0) = 2.0;
uniform float pulse_rate : hint_range(0.5, 4.0) = 1.5;

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
	vec2 uv = UV - 0.5;
	float dist = length(uv) * 2.0;

	// Two noise layers scrolling in different directions
	float t = TIME * turbulence_speed;
	float n1 = noise(uv * 6.0 + vec2(t * 0.7, -t * 0.5));
	float n2 = noise(uv * 8.0 + vec2(-t * 0.6, t * 0.8) + 50.0);
	float combined = (n1 + n2) * 0.5;

	// Pulsing intensity
	float pulse = 0.8 + 0.2 * sin(TIME * pulse_rate * TAU);

	// Bright plasma core
	float core = smoothstep(0.8, 0.0, dist);
	float plasma = combined * core * pulse;

	// Bright rim for edge detection
	float rim = smoothstep(0.6, 0.85, dist) * smoothstep(1.05, 0.85, dist);
	rim *= 2.0 * pulse;

	// HDR color output
	vec3 col = weapon_color.rgb * (plasma * 2.5 + rim * 1.8);
	col += vec3(1.0, 0.95, 0.9) * core * plasma * 0.5; // hot white center

	float alpha = smoothstep(1.0, 0.75, dist) * weapon_color.a;

	COLOR = vec4(col, alpha);
}
