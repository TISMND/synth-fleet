shader_type canvas_item;

uniform vec4 orb_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float brightness : hint_range(0.5, 6.0) = 2.0;
uniform float animation_speed : hint_range(0.0, 5.0) = 1.0;
uniform int shape_type : hint_range(0, 5) = 0; // 0=circle, 1=diamond, 2=triangle, 3=star, 4=crescent, 5=hexagon
uniform float pulse_intensity : hint_range(0.0, 1.0) = 0.0;

// Glow-specific
uniform float core_size : hint_range(0.1, 0.8) = 0.4;
uniform float glow_falloff : hint_range(0.5, 4.0) = 1.5;
uniform float flicker_amount : hint_range(0.0, 0.5) = 0.05;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float sdf_circle(vec2 p) {
	return length(p);
}

float sdf_diamond(vec2 p) {
	p = abs(p);
	return (p.x + p.y) * 0.7071;
}

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
	float a = atan(p.y, p.x) + 0.7854; // offset 45 deg
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
	float d = dot(p, normalize(vec2(1.0, 1.732)));
	return max(d, p.x);
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

	float d = get_sdf(uv, shape_type);

	// Soft glow
	float core = smoothstep(core_size, core_size * 0.3, d);
	float glow = exp(-d * glow_falloff * 3.0);

	// Subtle flicker
	float flicker = 1.0 + sin(t * 7.3) * cos(t * 11.1) * flicker_amount;

	float intensity = (core + glow * 0.6) * brightness * flicker;
	intensity += intensity * pulse_intensity * 1.5;

	vec3 col = orb_color.rgb * intensity;
	col += vec3(1.0) * core * 0.3;

	float alpha = clamp(intensity * 0.8, 0.0, 1.0);

	COLOR = vec4(col, alpha * modulate_alpha);
}
