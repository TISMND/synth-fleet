shader_type canvas_item;

uniform vec4 line_color : source_color = vec4(0.15, 0.35, 0.6, 0.4);
uniform vec4 bg_color : source_color = vec4(0.02, 0.02, 0.06, 1.0);
uniform float spacing : hint_range(16.0, 256.0) = 64.0;
uniform float scroll_speed : hint_range(0.0, 100.0) = 20.0;
uniform float line_width : hint_range(0.5, 4.0) = 1.0;
uniform float inner_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float aura_size : hint_range(0.0, 8.0) = 4.0;
uniform float aura_intensity : hint_range(0.0, 2.0) = 0.6;
uniform float bloom_size : hint_range(0.0, 20.0) = 12.0;
uniform float bloom_intensity : hint_range(0.0, 1.5) = 0.2;
uniform float smudge_blur : hint_range(0.0, 4.0) = 0.0;

float grid_dist(vec2 uv_px, float y_offset) {
	float h_dist = mod(uv_px.y + y_offset, spacing);
	h_dist = min(h_dist, spacing - h_dist);
	float v_dist = mod(uv_px.x, spacing);
	v_dist = min(v_dist, spacing - v_dist);
	return min(h_dist, v_dist);
}

void fragment() {
	vec2 uv_px = FRAGCOORD.xy;
	float y_offset = TIME * scroll_speed;

	float d = grid_dist(uv_px, y_offset);

	// Sharp line core
	float line_alpha = 1.0 - smoothstep(0.0, line_width, d);

	// Inner intensity: brighten line cores toward white
	float inner = 0.0;
	if (inner_intensity > 0.0 && d < line_width) {
		float core = 1.0 - d / line_width;
		inner = core * inner_intensity;
	}

	// Aura: tight glow falloff
	float aura = 0.0;
	if (aura_size > 0.01 && aura_intensity > 0.0) {
		aura = exp(-d * d / (aura_size * aura_size)) * aura_intensity;
	}

	// Bloom: wide soft glow
	float bloom = 0.0;
	if (bloom_size > 0.01 && bloom_intensity > 0.0) {
		bloom = exp(-d * d / (bloom_size * bloom_size)) * bloom_intensity;
	}

	// Smudge: horizontal blur of the line signal
	float smudge = 0.0;
	if (smudge_blur > 0.01) {
		float sw = 0.0;
		for (int i = -4; i <= 4; i++) {
			float ox = float(i) * smudge_blur;
			float sd = grid_dist(uv_px + vec2(ox, 0.0), y_offset);
			float sig = 1.0 - smoothstep(0.0, line_width, sd);
			float w = exp(-float(i * i) * 0.3);
			smudge += sig * w;
			sw += w;
		}
		smudge /= sw;
	}

	// Combine
	float total = clamp(line_alpha + smudge + aura + bloom, 0.0, 1.0);
	vec3 base_line_col = line_color.rgb;
	if (inner > 0.0) {
		base_line_col = mix(line_color.rgb, vec3(1.0), inner);
	}
	vec3 final_color = mix(bg_color.rgb, base_line_col, total);

	COLOR = vec4(final_color, 1.0);
}
