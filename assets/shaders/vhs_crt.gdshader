shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.15;
uniform float scanline_spacing : hint_range(1.0, 8.0) = 2.0;
uniform float chromatic_aberration : hint_range(0.0, 5.0) = 1.5;
uniform float barrel_distortion : hint_range(0.0, 0.5) = 0.0;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.3;
uniform float noise_intensity : hint_range(0.0, 0.5) = 0.05;
uniform float color_bleed : hint_range(0.0, 5.0) = 0.0;
uniform float roll_speed : hint_range(0.0, 2.0) = 0.0;
uniform float roll_strength : hint_range(0.0, 0.1) = 0.0;

// Hash function for noise
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 apply_barrel(vec2 uv, float amount) {
	vec2 centered = uv - 0.5;
	float r2 = dot(centered, centered);
	vec2 distorted = centered * (1.0 + amount * r2);
	return distorted + 0.5;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	bool out_of_bounds = false;

	// Barrel distortion
	if (barrel_distortion > 0.001) {
		uv = apply_barrel(uv, barrel_distortion);
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
			out_of_bounds = true;
		}
	}

	if (out_of_bounds) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		// VHS roll distortion
		vec2 roll_uv = uv;
		if (roll_speed > 0.001 && roll_strength > 0.001) {
			float roll_line = fract(TIME * roll_speed);
			float dist_to_roll = abs(uv.y - roll_line);
			dist_to_roll = min(dist_to_roll, 1.0 - dist_to_roll);
			float roll_effect = smoothstep(0.05, 0.0, dist_to_roll);
			roll_uv.x += roll_effect * roll_strength * sin(TIME * 13.0);
		}

		// Chromatic aberration — offset R and B channels
		vec2 texel_size = SCREEN_PIXEL_SIZE;
		vec2 ca_offset = vec2(chromatic_aberration * texel_size.x, 0.0);

		float r = texture(screen_texture, roll_uv - ca_offset).r;
		float g = texture(screen_texture, roll_uv).g;
		float b = texture(screen_texture, roll_uv + ca_offset).b;

		// Color bleed — horizontal smear
		if (color_bleed > 0.001) {
			float bleed_offset = color_bleed * texel_size.x;
			r = mix(r, texture(screen_texture, roll_uv - vec2(bleed_offset, 0.0)).r, 0.5);
			b = mix(b, texture(screen_texture, roll_uv + vec2(bleed_offset, 0.0)).b, 0.5);
		}

		vec3 col = vec3(r, g, b);

		// Scanlines
		if (scanline_strength > 0.001) {
			float scanline = sin(FRAGCOORD.y * PI * scanline_spacing) * 0.5 + 0.5;
			col *= 1.0 - scanline_strength * (1.0 - scanline);
		}

		// Noise / grain
		if (noise_intensity > 0.001) {
			float n = hash(FRAGCOORD.xy + fract(TIME * 43.0)) * 2.0 - 1.0;
			col += vec3(n) * noise_intensity;
		}

		// Vignette
		if (vignette_strength > 0.001) {
			vec2 vig_uv = uv * (1.0 - uv);
			float vig = vig_uv.x * vig_uv.y * 15.0;
			vig = clamp(pow(vig, 0.25), 0.0, 1.0);
			col *= mix(1.0, vig, vignette_strength);
		}

		COLOR = vec4(clamp(col, vec3(0.0), vec3(1.0)), 1.0);
	}
}
