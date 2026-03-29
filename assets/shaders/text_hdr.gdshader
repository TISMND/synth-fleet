shader_type canvas_item;
// Simple HDR text shader: outputs text color multiplied by hdr_multiplier.
// When multiplier > 1.0, the pixels exceed LDR range and Godot's
// WorldEnvironment glow picks them up for natural bloom — no rectangular
// sampling kernels, no boxy artifacts.

uniform float hdr_multiplier : hint_range(0.0, 4.0) = 1.0;

varying vec4 vert_color;

void vertex() {
	vert_color = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float alpha = tex.a * vert_color.a;
	vec3 col = vert_color.rgb * hdr_multiplier;
	COLOR = vec4(col * alpha, alpha);
}
