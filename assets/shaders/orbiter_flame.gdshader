shader_type canvas_item;

uniform vec4 orb_color : source_color = vec4(1.0, 0.4, 0.0, 1.0);
uniform float brightness : hint_range(0.5, 6.0) = 2.0;
uniform float animation_speed : hint_range(0.0, 5.0) = 1.5;
uniform int shape_type : hint_range(0, 5) = 0;
uniform float pulse_intensity : hint_range(0.0, 1.0) = 0.0;

// Flame-specific
uniform float flame_height : hint_range(0.2, 1.0) = 0.5;
uniform float turbulence : hint_range(0.5, 4.0) = 2.0;
uniform float core_heat : hint_range(0.5, 3.0) = 1.5;

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
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

float sdf_circle(vec2 p) { return length(p); }
float sdf_diamond(vec2 p) { p = abs(p); return (p.x + p.y) * 0.7071; }
float sdf_triangle(vec2 p) {
	p.y += 0.15;
	float k = sqrt(3.0);
	p.x = abs(p.x) - 0.5;
	p.y = p.y + 0.5 / k;
	if (p.x + k * p.y > 0.0) p = vec2(p.x - k * p.y, -k * p.x - p.y) * 0.5;
	p.x -= clamp(p.x, -1.0, 0.0);
	return -length(p) * sign(p.y);
}
float sdf_star(vec2 p) {
	float a = atan(p.y, p.x) + 0.7854;
	float r = length(p);
	float k = abs(fract(a * 0.6366 + 0.25) - 0.5) * 2.0;
	return r * (0.6 + 0.4 * k);
}
float sdf_crescent(vec2 p) {
	float d1 = length(p);
	float d2 = length(p - vec2(0.2, 0.0));
	return max(d1, -(d2 - 0.35));
}
float sdf_hexagon(vec2 p) {
	p = abs(p);
	return max(dot(p, normalize(vec2(1.0, 1.732))), p.x);
}

float get_sdf(vec2 p, int shape) {
	if (shape == 1) return sdf_diamond(p);
	if (shape == 2) return sdf_triangle(p);
	if (shape == 3) return sdf_star(p);
	if (shape == 4) return sdf_crescent(p);
	if (shape == 5) return sdf_hexagon(p);
	return sdf_circle(p);
}

void fragment() {
	float modulate_alpha = COLOR.a;
	float t = TIME * animation_speed;
	vec2 uv = (UV - 0.5) * 2.0;

	// Distort UVs with turbulence for flame effect
	vec2 flame_uv = uv;
	flame_uv.y -= t * 0.5; // upward drift
	float n = fbm(flame_uv * turbulence + vec2(t * 0.7, 0.0));

	float d = get_sdf(uv, shape_type);

	// Flame envelope — noise erodes the edge
	float envelope = smoothstep(flame_height + n * 0.3, 0.0, d);

	// Hot core
	float core = smoothstep(0.3, 0.0, d) * core_heat;

	float intensity = (envelope + core) * brightness;
	intensity += intensity * pulse_intensity * 1.5;

	// Color shift: core is white-hot, outer is orb_color
	vec3 hot = vec3(1.0, 0.95, 0.8);
	vec3 col = mix(orb_color.rgb, hot, core / max(core_heat, 0.01)) * intensity;

	float alpha = clamp(envelope * 0.9, 0.0, 1.0);

	COLOR = vec4(col, alpha * modulate_alpha);
}
