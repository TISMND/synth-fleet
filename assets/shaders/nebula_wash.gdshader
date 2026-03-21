shader_type canvas_item;
// Nebula wash — flat colored circle with soft radial falloff. No noise, just tint.

uniform vec4 nebula_color : source_color = vec4(0.3, 0.4, 0.9, 1.0);
uniform float radial_spread : hint_range(0.05, 1.0) = 0.2;

void fragment() {
	float modulate_alpha = COLOR.a;
	vec2 center = UV - 0.5;
	float dist = length(center) * 2.0;
	float wide_spread = min(radial_spread * 3.0, 0.95);
	float falloff = smoothstep(1.0, 1.0 - wide_spread, dist);
	COLOR = vec4(nebula_color.rgb, falloff * nebula_color.a * modulate_alpha);
}
