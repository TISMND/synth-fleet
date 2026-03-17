shader_type canvas_item;

uniform int segment_count : hint_range(4, 40) = 20;
uniform float segment_gap : hint_range(0.005, 0.04) = 0.015;
uniform float inner_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float aura_size : hint_range(0.0, 0.06) = 0.02;
uniform float aura_intensity : hint_range(0.0, 2.0) = 0.8;
uniform float bloom_size : hint_range(0.0, 0.15) = 0.05;
uniform float bloom_intensity : hint_range(0.0, 1.5) = 0.4;
uniform float smudge_blur : hint_range(0.0, 0.03) = 0.008;
uniform vec4 fill_color : source_color = vec4(0.3, 0.8, 1.0, 1.0);
uniform vec4 bg_color : source_color = vec4(0.05, 0.05, 0.08, 1.0);
uniform float fill_ratio : hint_range(0.0, 1.0) = 0.75;
uniform float pad_x : hint_range(0.0, 0.5) = 0.05;
uniform float pad_y : hint_range(0.0, 0.5) = 0.2;

// Supercharged animation uniforms
uniform float animation_speed : hint_range(0.1, 5.0) = 1.5;
uniform float pulse_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float energy_distortion : hint_range(0.0, 0.5) = 0.15;

vec2 to_bar_uv(vec2 uv) {
	return vec2(
		(uv.x - pad_x) / max(1.0 - 2.0 * pad_x, 0.001),
		(uv.y - pad_y) / max(1.0 - 2.0 * pad_y, 0.001)
	);
}

bool in_bar(vec2 bar_uv) {
	return bar_uv.x >= 0.0 && bar_uv.x <= 1.0 && bar_uv.y >= 0.0 && bar_uv.y <= 1.0;
}

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

// Per-segment radial distance: 0.0 at center, 1.0 at edge, -1.0 if not in a lit segment.
float segment_center_dist(vec2 bar_uv) {
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
	float ny = abs(bar_uv.y - 0.5) * 2.0;

	return clamp(sqrt(nx * nx + ny * ny), 0.0, 1.0);
}

float sdf_lit(vec2 bar_uv) {
	float seg_width = 1.0 / float(segment_count);
	float half_gap = segment_gap * 0.5;
	float min_dist = 999.0;

	int center_seg = int(floor(clamp(bar_uv.x, 0.0, 0.999) / seg_width));
	for (int offset = -3; offset <= 3; offset++) {
		int si = center_seg + offset;
		if (si < 0 || si >= segment_count) continue;

		float seg_mid = (float(si) + 0.5) / float(segment_count);
		if (seg_mid > fill_ratio) continue;

		float sx0 = float(si) * seg_width + half_gap;
		float sx1 = float(si + 1) * seg_width - half_gap;

		float dx = max(max(sx0 - bar_uv.x, bar_uv.x - sx1), 0.0);
		float dy = max(max(0.0 - bar_uv.y, bar_uv.y - 1.0), 0.0);
		float d = sqrt(dx * dx + dy * dy);
		min_dist = min(min_dist, d);
	}
	return min_dist;
}

// Pseudo-random hash for shimmer
float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	vec2 bar_uv = to_bar_uv(UV);
	bool inside = in_bar(bar_uv);

	float t = TIME * animation_speed;

	// Energy sweep: bright pulse scrolling left-to-right across fill area
	float sweep_pos = fract(t * 0.4);
	float sweep_width = 0.15 + energy_distortion * 0.1;
	float sweep = exp(-pow((bar_uv.x - sweep_pos) / sweep_width, 2.0) * 2.0);
	// Second sweep at offset for more energy
	float sweep2_pos = fract(t * 0.4 + 0.5);
	float sweep2 = exp(-pow((bar_uv.x - sweep2_pos) / (sweep_width * 1.3), 2.0) * 2.0) * 0.5;

	// Color shimmer: subtle hue shift over time
	float shimmer = sin(bar_uv.x * 12.0 + t * 2.0) * 0.5 + 0.5;
	float shimmer2 = sin(bar_uv.x * 7.0 - t * 1.5 + bar_uv.y * 4.0) * 0.5 + 0.5;

	// Edge glow pulse: aura intensity oscillates
	float glow_pulse = 0.7 + 0.3 * sin(t * 3.0);

	// Distortion: subtle UV wobble on the bar
	vec2 distorted_bar_uv = bar_uv;
	if (inside && energy_distortion > 0.001) {
		distorted_bar_uv.x += sin(bar_uv.y * 8.0 + t * 4.0) * energy_distortion * 0.02;
	}

	// Base lit computation with smudge
	float base = 0.0;
	if (inside) {
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
	}

	// SDF distance for glow
	float d = sdf_lit(bar_uv);

	// Inner intensity: per-segment radial white gradient with sweep boost
	float inner = 0.0;
	if (inner_intensity > 0.0 && inside) {
		float seg_dist = segment_center_dist(bar_uv);
		if (seg_dist >= 0.0) {
			float radial = 1.0 - seg_dist;
			float sweep_boost = 1.0 + (sweep + sweep2) * pulse_intensity;
			inner = radial * inner_intensity * sweep_boost;
		}
	}

	// Aura with glow pulse
	float aura = 0.0;
	float effective_aura_intensity = aura_intensity * glow_pulse;
	if (aura_size > 0.0001 && d > 0.0) {
		aura = exp(-d * d / (aura_size * aura_size * 0.5)) * effective_aura_intensity;
	}
	if (base > 0.5 && aura_intensity > 0.0) {
		aura = max(aura, effective_aura_intensity * 0.3);
	}

	// Bloom with glow pulse
	float bloom = 0.0;
	if (bloom_size > 0.0001 && d > 0.0) {
		bloom = exp(-d * d / (bloom_size * bloom_size * 0.5)) * bloom_intensity * glow_pulse;
	}

	// Vertical softness
	float vert_soft = 1.0;
	if (inside) {
		vert_soft = smoothstep(0.0, 0.12, bar_uv.y) * smoothstep(1.0, 0.88, bar_uv.y);
	}

	// Animated color: shift hue slightly based on shimmer
	vec3 base_color = fill_color.rgb;
	vec3 shimmer_color = mix(base_color, base_color.gbr, shimmer * 0.15 * pulse_intensity);
	shimmer_color = mix(shimmer_color, vec3(1.0), shimmer2 * 0.08 * pulse_intensity);

	// Sweep highlight color (brighter, slightly shifted)
	vec3 sweep_color = mix(shimmer_color, vec3(1.0), 0.4);
	float total_sweep = clamp((sweep + sweep2) * pulse_intensity, 0.0, 1.0);

	// Combine
	vec3 base_col = shimmer_color * base * vert_soft;
	vec3 inner_col = mix(shimmer_color, vec3(1.0), 0.7) * inner * vert_soft;
	vec3 aura_col = shimmer_color * aura;
	vec3 bloom_col = shimmer_color * bloom * 0.6;

	// Add sweep highlight on top of lit segments
	vec3 sweep_highlight = sweep_color * total_sweep * base * vert_soft * 0.6;

	vec3 lit_total = base_col + inner_col + aura_col + bloom_col + sweep_highlight;
	float alpha = clamp(base + aura * 0.8 + bloom * 0.4 + total_sweep * base * 0.3, 0.0, 1.0);

	// Inside bar: mix with bg. Outside bar: glow over transparent.
	vec3 final_color;
	float final_alpha;
	if (inside) {
		final_color = mix(bg_color.rgb, lit_total, alpha) * vert_soft
					+ bg_color.rgb * (1.0 - vert_soft);
		final_alpha = 1.0;
	} else {
		final_color = lit_total;
		final_alpha = clamp(aura * 0.6 + bloom * 0.3, 0.0, 0.9);
	}

	COLOR = vec4(clamp(final_color, vec3(0.0), vec3(1.0)), final_alpha);
}
