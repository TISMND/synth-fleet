shader_type canvas_item;

uniform float inner_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float aura_size : hint_range(0.0, 8.0) = 0.0;
uniform float aura_intensity : hint_range(0.0, 2.0) = 0.0;
uniform float bloom_size : hint_range(0.0, 20.0) = 0.0;
uniform float bloom_intensity : hint_range(0.0, 1.5) = 0.0;
uniform float smudge_blur : hint_range(0.0, 4.0) = 0.0;

// Vertex color carries the label's font_color — pass it to fragment.
varying vec4 vert_color;

void vertex() {
	vert_color = COLOR;
}

void fragment() {
	vec2 ps = SCREEN_PIXEL_SIZE;
	vec4 tex = texture(TEXTURE, UV);

	// Font atlas is white glyphs with alpha; actual color is vertex color.
	vec3 text_col = vert_color.rgb;
	float alpha = tex.a * vert_color.a;

	// Inner intensity: brighten glyph centers toward white.
	// Estimate "center-ness" by sampling how much alpha surrounds this pixel.
	// Edge pixels have low surrounding alpha → stay colored; deep interior → whiten.
	vec3 col = text_col;
	if (inner_intensity > 0.0 && alpha > 0.5) {
		float min_neighbor = 1.0;
		for (int y = -2; y <= 2; y++) {
			for (int x = -2; x <= 2; x++) {
				if (x == 0 && y == 0) continue;
				vec2 off = vec2(float(x), float(y)) * ps * 1.5;
				float na = texture(TEXTURE, UV + off).a;
				min_neighbor = min(min_neighbor, na);
			}
		}
		// min_neighbor is ~1 deep inside glyphs, drops toward 0 at edges
		float center = smoothstep(0.1, 0.9, min_neighbor);
		col = mix(text_col, vec3(1.0), inner_intensity * center);
	}

	// Smudge: horizontal-only blur of the base text
	float smudge_alpha = 0.0;
	if (smudge_blur > 0.01) {
		float sw = 0.0;
		for (int i = -6; i <= 6; i++) {
			float ox = float(i) * smudge_blur * ps.x;
			vec4 s = texture(TEXTURE, UV + vec2(ox, 0.0));
			float w = exp(-float(i * i) * 0.18);
			smudge_alpha += s.a * w;
			sw += w;
		}
		smudge_alpha /= sw;
	}

	// Aura: tight glow kernel (13x13)
	float aura_alpha = 0.0;
	if (aura_size > 0.01) {
		float aw = 0.0;
		for (int y = -6; y <= 6; y++) {
			for (int x = -6; x <= 6; x++) {
				vec2 off = vec2(float(x), float(y)) * aura_size * ps;
				vec4 s = texture(TEXTURE, UV + off);
				float d2 = float(x * x + y * y);
				float w = exp(-d2 / (aura_size * aura_size * 0.3));
				aura_alpha += s.a * w;
				aw += w;
			}
		}
		aura_alpha /= aw;
		aura_alpha *= aura_intensity;
	}

	// Bloom: wide soft glow kernel (11x11 with larger step)
	float bloom_alpha = 0.0;
	if (bloom_size > 0.01) {
		float bw = 0.0;
		for (int y = -5; y <= 5; y++) {
			for (int x = -5; x <= 5; x++) {
				vec2 off = vec2(float(x), float(y)) * bloom_size * ps * 2.0;
				vec4 s = texture(TEXTURE, UV + off);
				float d2 = float(x * x + y * y);
				float w = exp(-d2 / (bloom_size * bloom_size * 0.15));
				bloom_alpha += s.a * w;
				bw += w;
			}
		}
		bloom_alpha /= bw;
		bloom_alpha *= bloom_intensity;
	}

	// Combine: all glow uses the text color, just with extended alpha
	float glow_alpha = clamp(smudge_alpha * 0.5 + aura_alpha + bloom_alpha * 0.6, 0.0, 1.0);

	// Final composite: glow behind, sharp text on top
	vec3 final_col = mix(text_col * glow_alpha, col, alpha);
	float final_alpha = clamp(alpha + glow_alpha, 0.0, 1.0);

	COLOR = vec4(final_col, final_alpha);
}
