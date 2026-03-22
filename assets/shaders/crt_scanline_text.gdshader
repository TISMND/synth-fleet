shader_type canvas_item;

// Applies CRT scanlines to text. Runs on the reboot label.
void fragment() {
	float modulate_alpha = COLOR.a;
	vec4 tex = texture(TEXTURE, UV);

	// Scanlines based on screen position
	float scanline = 0.5 + 0.5 * sin(SCREEN_UV.y * 800.0);
	float line_darken = 1.0 - scanline * 0.2;

	COLOR = vec4(tex.rgb * line_darken, tex.a * modulate_alpha);
}
