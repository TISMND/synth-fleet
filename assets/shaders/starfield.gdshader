shader_type canvas_item;

uniform float density : hint_range(0.0, 1.0) = 0.2;
uniform float seed : hint_range(0.0, 100.0) = 0.0;
uniform float star_size : hint_range(0.5, 4.0) = 1.5;
uniform float brightness_min : hint_range(0.0, 1.0) = 0.2;
uniform float brightness_max : hint_range(0.0, 1.0) = 0.8;
uniform float twinkle_speed : hint_range(0.0, 4.0) = 1.0;
uniform float cell_count : hint_range(10.0, 200.0) = 80.0;

float hash(vec2 p) {
	return fract(sin(dot(p + seed, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 cell_uv = UV * cell_count;
	vec2 cell_id = floor(cell_uv);
	vec2 cell_local = fract(cell_uv);

	float rand_exist = hash(cell_id);
	if (rand_exist <= density) {
		vec2 star_pos = vec2(hash(cell_id + 10.0), hash(cell_id + 20.0));
		float star_bright = mix(brightness_min, brightness_max, hash(cell_id + 30.0));

		float twinkle = 0.85 + 0.15 * sin(TIME * twinkle_speed + hash(cell_id + 40.0) * 6.2832);
		star_bright *= twinkle;

		float dist = length(cell_local - star_pos) * cell_count;
		float alpha = smoothstep(star_size, star_size * 0.3, dist);

		// Blend star on top of existing COLOR (the ColorRect's color)
		COLOR = mix(COLOR, vec4(vec3(star_bright), 1.0), alpha);
	}
	// else: COLOR stays as the ColorRect's color — opaque black for far, transparent for near
}
