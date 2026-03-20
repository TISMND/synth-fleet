shader_type canvas_item;

uniform int segment_count : hint_range(4, 40) = 20;
uniform float segment_gap : hint_range(0.0, 0.12) = 0.04;
// Inner glow
uniform float inner_intensity : hint_range(0.0, 2.0) = 0.3;
uniform float inner_softness : hint_range(0.1, 3.0) = 1.0;
// Smudge
uniform float smudge_blur : hint_range(0.0, 0.03) = 0.008;
// Core
uniform vec4 fill_color : source_color = vec4(0.3, 0.8, 1.0, 1.0);
uniform vec4 bg_color : source_color = vec4(0.05, 0.05, 0.08, 1.0);
uniform float fill_ratio : hint_range(0.0, 1.0) = 0.75;
// HDR multiplier — values > 1.0 trigger engine bloom via WorldEnvironment glow
uniform float hdr_multiplier : hint_range(1.0, 4.0) = 1.8;

// Supercharged animation uniforms
uniform float animation_speed : hint_range(0.1, 5.0) = 1.5;
uniform float pulse_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float energy_distortion : hint_range(0.0, 0.5) = 0.15;

float is_lit(float bx) {
	if (bx < 0.0 || bx > 1.0) return 0.0;
	float seg_width = 1.0 / float(segment_count);
	float half_gap = segment_gap * 0.5;

	int seg_index = int(floor(bx / seg_width));
	float seg_start = float(seg_index) * seg_width;
	float seg_end = seg_start + seg_width;

	if (bx - seg_start < half_gap || seg_end - bx < half_gap) {
		return 0.0;
	}

	float seg_mid = (float(seg_index) + 0.5) / float(segment_count);
	return seg_mid <= fill_ratio ? 1.0 : 0.0;
}

// Per-segment radial distance with aspect correction
float segment_center_dist(vec2 bar_uv, float bar_aspect) {
	if (bar_uv.x < 0.0 || bar_uv.x > 1.0 || bar_uv.y < 0.0 || bar_uv.y > 1.0) return -1.0;
	float seg_width = 1.0 / float(segment_count);
	float half_gap = segment_gap * 0.5;

	int seg_index = int(floor(bar_uv.x / seg_width));
	if (seg_index < 0 || seg_index >= segment_count) return -1.0;

	float seg_start = float(seg_index) * seg_width;
	float seg_end = seg_start + seg_width;

	if (bar_uv.x - seg_start < half_gap || seg_end - bar_uv.x < half_gap) return -1.0;

	float seg_mid_x = (float(seg_index) + 0.5) / float(segment_count);
	if (seg_mid_x > fill_ratio) return -1.0;

	float inner_start = seg_start + half_gap;
	float inner_end = seg_end - half_gap;
	float inner_width = inner_end - inner_start;
	float nx = abs(bar_uv.x - (inner_start + inner_width * 0.5)) / (inner_width * 0.5);
	float ny = abs(bar_uv.y - 0.5) * 2.0 / bar_aspect;

	return clamp(sqrt(nx * nx + ny * ny), 0.0, 1.0);
}

void fragment() {
	float modulate_alpha = COLOR.a;
	vec2 bar_uv = UV;

	// Derive aspect ratio from pixel size
	float bar_aspect = TEXTURE_PIXEL_SIZE.y / max(TEXTURE_PIXEL_SIZE.x, 0.0001);

	float t = TIME * animation_speed;

	// Energy sweep: bright pulse scrolling left-to-right across fill area
	float sweep_pos = fract(t * 0.4);
	float sweep_width = 0.15 + energy_distortion * 0.1;
	float sweep = exp(-pow((bar_uv.x - sweep_pos) / sweep_width, 2.0) * 2.0);
	float sweep2_pos = fract(t * 0.4 + 0.5);
	float sweep2 = exp(-pow((bar_uv.x - sweep2_pos) / (sweep_width * 1.3), 2.0) * 2.0) * 0.5;

	// Color shimmer
	float shimmer = sin(bar_uv.x * 12.0 + t * 2.0) * 0.5 + 0.5;
	float shimmer2 = sin(bar_uv.x * 7.0 - t * 1.5 + bar_uv.y * 4.0) * 0.5 + 0.5;

	// Distortion
	vec2 distorted_bar_uv = bar_uv;
	if (energy_distortion > 0.001) {
		distorted_bar_uv.x += sin(bar_uv.y * 8.0 + t * 4.0) * energy_distortion * 0.02;
	}

	// Base lit computation with smudge
	float base = 0.0;
	if (smudge_blur > 0.0001) {
		float acc = 0.0;
		float wt = 0.0;
		for (int i = -4; i <= 4; i++) {
			float ox = float(i) * smudge_blur * 0.5;
			float sx = clamp(distorted_bar_uv.x + ox, 0.0, 1.0);
			float w = exp(-float(i * i) * 0.5);
			acc += is_lit(sx) * w;
			wt += w;
		}
		base = acc / wt;
	} else {
		base = is_lit(distorted_bar_uv.x);
	}

	// Inner intensity with sweep boost
	float inner = 0.0;
	if (inner_intensity > 0.0) {
		float seg_dist = segment_center_dist(bar_uv, bar_aspect);
		if (seg_dist >= 0.0) {
			float radial = pow(1.0 - seg_dist, inner_softness);
			float sweep_boost = 1.0 + (sweep + sweep2) * pulse_intensity;
			inner = radial * inner_intensity * sweep_boost;
		}
	}

	// Vertical softness
	float vert_soft = smoothstep(0.0, 0.12, bar_uv.y) * smoothstep(1.0, 0.88, bar_uv.y);

	// Animated color: shift hue slightly based on shimmer
	vec3 base_color = fill_color.rgb;
	vec3 shimmer_color = mix(base_color, base_color.gbr, shimmer * 0.15 * pulse_intensity);
	shimmer_color = mix(shimmer_color, vec3(1.0), shimmer2 * 0.08 * pulse_intensity);

	// Sweep highlight color
	vec3 sweep_color = mix(shimmer_color, vec3(1.0), 0.4);
	float total_sweep = clamp((sweep + sweep2) * pulse_intensity, 0.0, 1.0);

	// Combine
	vec3 base_col = shimmer_color * base * vert_soft;
	vec3 inner_col = mix(shimmer_color, vec3(1.0), 0.7) * inner * vert_soft;
	vec3 sweep_highlight = sweep_color * total_sweep * base * vert_soft * 0.6;

	vec3 lit_total = base_col + inner_col + sweep_highlight;
	float alpha = clamp(base + total_sweep * base * 0.3, 0.0, 1.0);

	// Mix with bg, apply HDR multiplier for engine bloom
	vec3 final_color = mix(bg_color.rgb, lit_total * hdr_multiplier, alpha) * vert_soft
				+ bg_color.rgb * (1.0 - vert_soft);

	COLOR = vec4(final_color, modulate_alpha);
}
