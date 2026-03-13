shader_type canvas_item;

uniform float time_offset : hint_range(0.0, 100.0) = 0.0;
uniform float pulse : hint_range(0.0, 2.0) = 0.0;
uniform float hue_speed : hint_range(0.0, 5.0) = 0.5;

vec3 hsv_to_rgb(float h, float s, float v) {
	vec3 c = vec3(h, s, v);
	vec3 rgb = clamp(abs(mod(c.x * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
	return c.z * mix(vec3(1.0), rgb, c.y);
}

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	if (tex_color.a < 0.01) {
		discard;
	}
	float hue = fract(UV.x * 0.5 + UV.y * 0.3 + time_offset * hue_speed);
	float sat = 0.7 + pulse * 0.3;
	float val = 0.6 + pulse * 0.4;
	vec3 rainbow = hsv_to_rgb(hue, sat, val);
	COLOR = vec4(rainbow * tex_color.a, tex_color.a);
}
