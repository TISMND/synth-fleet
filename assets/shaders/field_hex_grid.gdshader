shader_type canvas_item;

uniform vec4 field_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float brightness : hint_range(0.5, 4.0) = 1.0;
uniform float animation_speed : hint_range(0.1, 3.0) = 1.0;
uniform float radius_ratio : hint_range(0.0, 1.0) = 0.8;
uniform float pulse_intensity : hint_range(0.0, 4.0) = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

// Per-shader params
uniform float hex_size : hint_range(0.02, 0.2) = 0.08;
uniform float gap_width : hint_range(0.001, 0.02) = 0.005;
uniform float scroll_speed : hint_range(0.1, 3.0) = 0.5;

// Hex distance function
float hex_dist(vec2 p) {
	p = abs(p);
	return max(dot(p, normalize(vec2(1.0, 1.73))), p.x);
}

vec4 hex_coords(vec2 uv, float size) {
	vec2 r = vec2(1.0, 1.73);
	vec2 h = r * 0.5;
	vec2 a = mod(uv, r) - h;
	vec2 b = mod(uv - h, r) - h;
	vec2 gv;
	if (length(a) < length(b)) {
		gv = a;
	} else {
		gv = b;
	}
	float d = hex_dist(gv);
	return vec4(gv, d, 0.0);
}

void fragment() {
	float modulate_alpha = COLOR.a;
	float t = TIME * animation_speed;
	vec2 uv = UV - 0.5;
	float dist = length(uv) * 2.0;

	// Hex tiling
	vec2 hex_uv = uv / hex_size;
	hex_uv.y += t * scroll_speed;
	vec4 hc = hex_coords(hex_uv, 1.0);

	// Hex edge lines
	float hex_edge = smoothstep(0.5 - gap_width, 0.5, hc.z);

	// Ring mask
	float outer = smoothstep(1.0, 0.98, dist);
	float inner = smoothstep(radius_ratio - 0.02, radius_ratio, dist);
	float ring = outer * inner;

	// Outward pulse wave
	float wave_pos = fract(t * scroll_speed * 0.3);
	float wave = smoothstep(wave_pos - 0.1, wave_pos, dist) * smoothstep(wave_pos + 0.1, wave_pos, dist);
	wave *= ring;

	float intensity = hex_edge * ring * brightness;
	intensity += wave * 0.5;
	intensity += intensity * pulse_intensity * 1.5;

	vec3 col = field_color.rgb * intensity;
	col += vec3(1.0) * hex_edge * ring * 0.15; // white highlight for HDR bloom

	float alpha = clamp(intensity * 0.9, 0.0, 1.0) * opacity;

	if (dist > 1.0) alpha = 0.0;

	COLOR = vec4(col, alpha * modulate_alpha);
}
