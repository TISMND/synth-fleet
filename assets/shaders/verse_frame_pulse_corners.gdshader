shader_type canvas_item;
// Pulse corners frame — slender L-shaped corner brackets that breathe and pulse.
// Minimal, elegant, no full border. Corners feel like a targeting reticle.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 2.5;
uniform float whiteness : hint_range(0.0, 1.0) = 0.3;
uniform vec3 frame_color : source_color = vec3(0.2, 0.7, 1.0);
uniform float line_width : hint_range(0.001, 0.008) = 0.003;
uniform float bracket_len : hint_range(0.05, 0.3) = 0.15;
uniform float pulse_speed : hint_range(0.05, 4.0) = 0.25;
uniform float stagger : hint_range(0.0, 1.0) = 0.4;
uniform float pulse_min : hint_range(0.0, 1.0) = 0.6;
uniform float pulse_max : hint_range(0.0, 1.0) = 0.85;
// Inset brackets from the overlay edge (0 = at edge, brackets just outside viewport)
uniform float inset : hint_range(0.0, 0.15) = 0.0;

float bracket(vec2 uv, float blen, float lw, float ins) {
	// Remap UV so brackets start at inset distance from edges
	float x0 = ins;
	float x1 = 1.0 - ins;
	float y0 = ins;
	float y1 = 1.0 - ins;
	// Top-left L
	float tl = 0.0;
	tl += step(uv.x, x0 + blen) * step(x0, uv.x) * step(uv.y, y0 + lw) * step(y0, uv.y);
	tl += step(uv.y, y0 + blen) * step(y0, uv.y) * step(uv.x, x0 + lw) * step(x0, uv.x);
	// Top-right L
	float tr = 0.0;
	tr += step(x1 - blen, uv.x) * step(uv.x, x1) * step(uv.y, y0 + lw) * step(y0, uv.y);
	tr += step(uv.y, y0 + blen) * step(y0, uv.y) * step(x1 - lw, uv.x) * step(uv.x, x1);
	// Bottom-left L
	float bl = 0.0;
	bl += step(uv.x, x0 + blen) * step(x0, uv.x) * step(y1 - lw, uv.y) * step(uv.y, y1);
	bl += step(y1 - blen, uv.y) * step(uv.y, y1) * step(uv.x, x0 + lw) * step(x0, uv.x);
	// Bottom-right L
	float br = 0.0;
	br += step(x1 - blen, uv.x) * step(uv.x, x1) * step(y1 - lw, uv.y) * step(uv.y, y1);
	br += step(y1 - blen, uv.y) * step(uv.y, y1) * step(x1 - lw, uv.x) * step(uv.x, x1);
	return clamp(tl + tr + bl + br, 0.0, 1.0);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	float modulate_alpha = COLOR.a;

	// Slow breathing pulse with compressed opacity range
	float raw1 = 0.5 + 0.5 * sin(t * pulse_speed * TAU);
	float raw2 = 0.5 + 0.5 * sin(t * pulse_speed * TAU + stagger * TAU);
	float pulse1 = mix(pulse_min, pulse_max, raw1);
	float pulse2 = mix(pulse_min, pulse_max, raw2);

	float b1 = bracket(uv, bracket_len, line_width, inset);
	float b2 = bracket(uv, bracket_len * 0.7, line_width * 0.6, inset + 0.005);

	float combined = b1 * pulse1 + b2 * pulse2 * 0.5;

	vec3 white_mix = mix(frame_color, vec3(1.0), whiteness * combined);
	vec3 col = white_mix * combined * hdr_intensity;

	float alpha = clamp(combined, 0.0, 1.0);
	COLOR = vec4(col, alpha * modulate_alpha);
}
