shader_type canvas_item;

uniform vec4 field_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float brightness : hint_range(0.5, 4.0) = 1.0;
uniform float animation_speed : hint_range(0.1, 3.0) = 1.0;
uniform float radius_ratio : hint_range(0.0, 1.0) = 0.8;
uniform float pulse_intensity : hint_range(0.0, 4.0) = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

// Per-shader params
uniform float hex_size : hint_range(0.02, 0.2) = 0.08;
uniform float line_thickness : hint_range(0.01, 0.15) = 0.06;
uniform float scroll_speed : hint_range(0.1, 3.0) = 0.5;
uniform float edge_density : hint_range(0.0, 1.0) = 0.5;
uniform float outer_radius : hint_range(0.5, 1.0) = 0.95;

// Hex distance function
float hex_dist(vec2 p) {
	p = abs(p);
	return max(dot(p, normalize(vec2(1.0, 1.73))), p.x);
}

vec4 hex_coords(vec2 uv_hex) {
	vec2 r = vec2(1.0, 1.73);
	vec2 h = r * 0.5;
	vec2 a = mod(uv_hex, r) - h;
	vec2 b = mod(uv_hex - h, r) - h;
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

	// Kill outside circle
	if (dist > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
		return;
	}

	// Hex tiling — covers the full area
	vec2 hex_uv = uv / hex_size;
	hex_uv.y += t * scroll_speed;
	vec4 hc = hex_coords(hex_uv);

	// Hex edge lines — controllable thickness
	float line_half = line_thickness * 0.5 / hex_size;
	float hex_edge = smoothstep(0.5, 0.5 - line_half, hc.z);

	// Fill interior with subtle hex cell color
	float hex_fill = smoothstep(0.5 - line_half, 0.3, hc.z) * 0.15;

	// Outward pulse wave
	float wave_pos = fract(t * scroll_speed * 0.3);
	float wave = smoothstep(wave_pos - 0.08, wave_pos, dist) * smoothstep(wave_pos + 0.08, wave_pos, dist);

	// Outer shell: densified solid ring at outer_radius
	float shell_start = outer_radius - 0.08;
	float shell = smoothstep(shell_start, outer_radius, dist);
	// Soften at very edge
	float edge_fade = smoothstep(1.0, 0.92, dist);

	// Edge density: blend hex into solid at the ring
	float edge_solid = shell * edge_density;

	// Inner mask: fade hex near center based on radius_ratio
	float inner_fade = smoothstep(radius_ratio * 0.3, radius_ratio * 0.3 + 0.15, dist);

	// Combine: hex pattern everywhere inside, solid shell at edge
	float hex_pattern = max(hex_edge, hex_fill) * inner_fade;
	float combined = mix(hex_pattern, max(hex_pattern, edge_solid), shell);
	combined = max(combined, edge_solid * 0.8); // ensure shell is visible

	float intensity = combined * brightness * edge_fade;
	intensity += wave * 0.4 * edge_fade;
	intensity += intensity * pulse_intensity * 1.5;

	vec3 col = field_color.rgb * intensity;
	// White highlight for HDR bloom on hex edges
	col += vec3(1.0) * hex_edge * inner_fade * 0.2 * brightness * edge_fade;
	// Shell glow
	col += field_color.rgb * shell * edge_density * 0.5 * brightness;

	float alpha = clamp((combined * 0.8 + wave * 0.2 + shell * edge_density * 0.3) * opacity * edge_fade, 0.0, 1.0);

	COLOR = vec4(col, alpha * modulate_alpha);
}
