shader_type canvas_item;

// Stars rendered on the root viewport so post-process bloom creates the halos.
// White-hot HDR core, star_color revealed in the bloom.

uniform float star_density : hint_range(0.85, 0.99) = 0.94;
uniform float star_size : hint_range(0.001, 0.008) = 0.003;
uniform float star_hdr : hint_range(1.0, 8.0) = 3.0;
uniform float star_twinkle : hint_range(0.0, 1.0) = 0.6;
uniform vec3 star_color : source_color = vec3(0.7, 0.85, 1.0);
uniform float star_core_white : hint_range(0.0, 1.0) = 0.85;

// Masking (synced from planet shader)
uniform float horizon : hint_range(0.3, 0.65) = 0.50;
uniform float planet_x : hint_range(0.35, 0.85) = 0.63;
uniform float planet_radius : hint_range(0.03, 0.2) = 0.08;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = UV;
	float ar = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float planet_cy = horizon;
	float dist_from_horizon = abs(uv.y - horizon) / max(horizon, 1.0 - horizon);

	vec3 col = vec3(0.0);
	float alpha = 0.0;
	vec3 star_white = mix(star_color, vec3(1.0), star_core_white);

	for (int layer = 0; layer < 2; layer++) {
		float grid_scale = (layer == 0) ? 100.0 : 160.0;
		float layer_offset = float(layer) * 333.0;
		vec2 cell = floor(uv * vec2(grid_scale, grid_scale * 0.5));
		float h = hash(cell + layer_offset);
		float threshold = (layer == 0) ? star_density : star_density + (1.0 - star_density) * 0.4;
		if (h > threshold) {
			vec2 soff = vec2(hash(cell + layer_offset + 111.0), hash(cell + layer_offset + 222.0));
			vec2 sp = (cell + soff) / vec2(grid_scale, grid_scale * 0.5);
			vec2 delta = (uv - sp) * vec2(ar, 1.0);
			float d_star = length(delta);

			float size_var = 0.5 + hash(cell + layer_offset + 333.0) * 0.8;
			float this_size = star_size * size_var;

			float tw_speed = 1.0 + h * 3.0;
			float tw_phase = h * 6.283;
			float tw = sin(TIME * tw_speed + tw_phase);
			float tw_amount = 0.5 + (1.0 - star_twinkle) * 0.5 + star_twinkle * tw * 0.5;

			// Tight gaussian core — bloom does the rest
			float core = exp(-d_star * d_star / max(this_size * this_size * 0.15, 0.0000001));

			float mask = tw_amount;
			mask *= 0.6 + uv.x * 0.8;
			float planet_prox = length(vec2((uv.x - planet_x) * ar, uv.y - planet_cy));
			mask *= smoothstep(planet_radius * 1.5, planet_radius * 4.0, planet_prox);
			mask *= smoothstep(0.0, 0.08, dist_from_horizon);

			float intensity = core * mask;
			// White-hot center, color in the bloom halo
			col += star_white * intensity * star_hdr;
			alpha = max(alpha, intensity);
		}
	}

	alpha = clamp(alpha, 0.0, 1.0);
	COLOR = vec4(col, alpha);
}
