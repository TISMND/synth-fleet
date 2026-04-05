shader_type canvas_item;
// Neon glow frame — thick HDR neon border with blooming inner/outer glow.
// Hot cyan/blue tubes with white-hot core controlled by hdr_intensity.

uniform float hdr_intensity : hint_range(0.5, 12.0) = 4.0;
uniform float whiteness : hint_range(0.0, 1.0) = 0.6;
uniform vec3 neon_color : source_color = vec3(0.1, 0.5, 1.0);
uniform float border_width : hint_range(0.005, 0.06) = 0.018;
uniform float glow_spread : hint_range(0.01, 0.15) = 0.06;
uniform float pulse_speed : hint_range(0.0, 4.0) = 1.2;

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	float modulate_alpha = COLOR.a;

	float edge_x = min(uv.x, 1.0 - uv.x);
	float edge_y = min(uv.y, 1.0 - uv.y);
	float edge_dist = min(edge_x, edge_y);

	// Breathing pulse
	float pulse = 0.85 + 0.15 * sin(t * pulse_speed * TAU);

	// Core neon line — sharp bright center
	float core = smoothstep(border_width + 0.003, border_width, edge_dist)
	           * smoothstep(max(border_width - 0.012, 0.0), border_width - 0.004, edge_dist);

	// Inner glow — soft spread inward
	float inner = smoothstep(border_width + glow_spread, border_width, edge_dist);
	inner *= inner; // quadratic falloff

	// Outer glow — soft spread outward (into the transparent border zone)
	float outer = smoothstep(max(border_width - glow_spread * 0.5, 0.0), border_width, edge_dist);
	outer = (1.0 - outer) * step(edge_dist, border_width);

	// Combine
	float intensity = core * 1.0 + inner * 0.25 + outer * 0.15;
	intensity *= pulse;

	// White-hot core blend: mix neon_color toward white based on whiteness and core strength
	vec3 white_core = mix(neon_color, vec3(1.0), whiteness * core);
	vec3 col = white_core * intensity * hdr_intensity;

	// Traveling light along border
	float travel = fract(t * 0.3);
	float perimeter = (uv.x + uv.y + (1.0 - uv.x) + (1.0 - uv.y)); // proxy
	float along = mod(uv.x * 2.0 + uv.y * 2.0 + travel * 4.0, 4.0) / 4.0;
	float spark = smoothstep(0.02, 0.0, abs(along - travel)) * core;
	col += vec3(1.0) * spark * 0.5 * hdr_intensity * whiteness;

	float alpha = clamp(intensity * 1.5, 0.0, 1.0);
	COLOR = vec4(col, alpha * modulate_alpha);
}
