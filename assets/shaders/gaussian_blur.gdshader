shader_type canvas_item;

uniform float blur_amount : hint_range(0.0, 10.0) = 3.0;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec2 ps = SCREEN_PIXEL_SIZE * blur_amount;
	vec4 col = vec4(0.0);
	// 9-tap gaussian kernel
	col += texture(screen_texture, SCREEN_UV + vec2(-2.0, -2.0) * ps) * 0.0162;
	col += texture(screen_texture, SCREEN_UV + vec2(-1.0, -2.0) * ps) * 0.0540;
	col += texture(screen_texture, SCREEN_UV + vec2(0.0, -2.0) * ps) * 0.0540;
	col += texture(screen_texture, SCREEN_UV + vec2(1.0, -2.0) * ps) * 0.0540;
	col += texture(screen_texture, SCREEN_UV + vec2(2.0, -2.0) * ps) * 0.0162;

	col += texture(screen_texture, SCREEN_UV + vec2(-2.0, -1.0) * ps) * 0.0540;
	col += texture(screen_texture, SCREEN_UV + vec2(-1.0, -1.0) * ps) * 0.0798;
	col += texture(screen_texture, SCREEN_UV + vec2(0.0, -1.0) * ps) * 0.0798;
	col += texture(screen_texture, SCREEN_UV + vec2(1.0, -1.0) * ps) * 0.0798;
	col += texture(screen_texture, SCREEN_UV + vec2(2.0, -1.0) * ps) * 0.0540;

	col += texture(screen_texture, SCREEN_UV + vec2(-2.0, 0.0) * ps) * 0.0540;
	col += texture(screen_texture, SCREEN_UV + vec2(-1.0, 0.0) * ps) * 0.0798;
	col += texture(screen_texture, SCREEN_UV + vec2(0.0, 0.0) * ps) * 0.0798;
	col += texture(screen_texture, SCREEN_UV + vec2(1.0, 0.0) * ps) * 0.0798;
	col += texture(screen_texture, SCREEN_UV + vec2(2.0, 0.0) * ps) * 0.0540;

	col += texture(screen_texture, SCREEN_UV + vec2(-2.0, 1.0) * ps) * 0.0540;
	col += texture(screen_texture, SCREEN_UV + vec2(-1.0, 1.0) * ps) * 0.0798;
	col += texture(screen_texture, SCREEN_UV + vec2(0.0, 1.0) * ps) * 0.0798;
	col += texture(screen_texture, SCREEN_UV + vec2(1.0, 1.0) * ps) * 0.0798;
	col += texture(screen_texture, SCREEN_UV + vec2(2.0, 1.0) * ps) * 0.0540;

	col += texture(screen_texture, SCREEN_UV + vec2(-2.0, 2.0) * ps) * 0.0162;
	col += texture(screen_texture, SCREEN_UV + vec2(-1.0, 2.0) * ps) * 0.0540;
	col += texture(screen_texture, SCREEN_UV + vec2(0.0, 2.0) * ps) * 0.0540;
	col += texture(screen_texture, SCREEN_UV + vec2(1.0, 2.0) * ps) * 0.0540;
	col += texture(screen_texture, SCREEN_UV + vec2(2.0, 2.0) * ps) * 0.0162;

	COLOR = col;
}
