shader_type canvas_item;

// Applies CRT scanlines to text. Preserves HDR modulate for bloom.
void fragment() {
	vec4 mod_color = COLOR;  // Holds modulate (HDR values > 1.0 for bloom)
	vec4 tex = texture(TEXTURE, UV);

	// Scanlines based on screen position
	float scanline = 0.5 + 0.5 * sin(SCREEN_UV.y * 800.0);
	float line_darken = 1.0 - scanline * 0.2;

	// Multiply texture by modulate color AND scanline darkening
	COLOR = vec4(tex.rgb * mod_color.rgb * line_darken, tex.a * mod_color.a);
}
