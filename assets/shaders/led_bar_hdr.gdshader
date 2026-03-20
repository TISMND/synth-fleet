shader_type canvas_item;

uniform int segment_count : hint_range(4, 40) = 20;
uniform float segment_gap : hint_range(0.0, 0.12) = 0.04;
// Inner glow
uniform float inner_intensity : hint_range(0.0, 2.0) = 0.3;
uniform float inner_softness : hint_range(0.1, 3.0) = 1.0;
// Smudge
uniform float smudge_blur : hint_range(0.0, 0.03) = 0.008;
// Core
uniform vec4 fill_color : source_color = vec4(0.15, 0.7, 0.3, 1.0);
uniform vec4 bg_color : source_color = vec4(0.05, 0.05, 0.08, 1.0);
uniform float fill_ratio : hint_range(0.0, 1.0) = 0.75;
// Vertical mode: 0 = horizontal (default), 1 = vertical (bottom-to-top fill)
uniform int vertical : hint_range(0, 1) = 0;
// HDR multiplier — values > 1.0 trigger engine bloom via WorldEnvironment glow
uniform float hdr_multiplier : hint_range(1.0, 4.0) = 1.8;
// Rolling wave animations (per-segment directional glow)
uniform float gain_wave_pos : hint_range(-1.0, 2.0) = -1.0;
uniform float drain_wave_pos : hint_range(-1.0, 2.0) = -1.0;
uniform float wave_intensity : hint_range(0.0, 1.5) = 0.5;
uniform float wave_width : hint_range(0.02, 0.4) = 0.15;

// Returns 1.0 if bar_uv_x is inside a lit segment, 0.0 otherwise.
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
// Aspect ratio derived from TEXTURE_PIXEL_SIZE for isotropic gradient.
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

// Compute wave glow contribution for a segment at normalized position seg_pos.
float wave_glow(float seg_pos, float wave_pos) {
	if (wave_pos < -0.5) return 0.0;
	float dist = abs(seg_pos - wave_pos);
	float half_w = wave_width * 0.5;
	if (dist > half_w) return 0.0;
	float t = dist / half_w;
	return (1.0 - t * t) * wave_intensity;
}

void fragment() {
	float modulate_alpha = COLOR.a;
	vec2 uv = UV;
	if (vertical == 1) {
		uv = vec2(1.0 - uv.y, uv.x);
	}
	// UV maps directly to bar — no padding remapping needed
	vec2 bar_uv = uv;

	// Derive aspect ratio from pixel size (long axis / short axis)
	vec2 pixel_size = TEXTURE_PIXEL_SIZE;
	float bar_aspect;
	if (vertical == 1) {
		bar_aspect = pixel_size.x / max(pixel_size.y, 0.0001);
	} else {
		bar_aspect = pixel_size.y / max(pixel_size.x, 0.0001);
	}

	// Smudge: horizontal blur of the base lit signal
	float base = 0.0;
	if (smudge_blur > 0.0001) {
		float acc = 0.0;
		float wt = 0.0;
		for (int i = -4; i <= 4; i++) {
			float ox = float(i) * smudge_blur * 0.5;
			float sx = clamp(bar_uv.x + ox, 0.0, 1.0);
			float w = exp(-float(i * i) * 0.5);
			acc += is_lit(sx) * w;
			wt += w;
		}
		base = acc / wt;
	} else {
		base = is_lit(bar_uv.x);
	}

	// Inner intensity: per-segment radial white gradient
	float inner = 0.0;
	if (inner_intensity > 0.0) {
		float seg_dist = segment_center_dist(bar_uv, bar_aspect);
		if (seg_dist >= 0.0) {
			float radial = pow(1.0 - seg_dist, inner_softness);
			inner = radial * inner_intensity;
		}
	}

	// Vertical softness (top/bottom edge fade)
	float vert_soft = smoothstep(0.0, 0.12, bar_uv.y) * smoothstep(1.0, 0.88, bar_uv.y);

	// Rolling wave glow (per-segment)
	float gain_glow = 0.0;
	float drain_glow = 0.0;
	float seg_width = 1.0 / float(segment_count);
	int seg_idx = clamp(int(floor(bar_uv.x / seg_width)), 0, segment_count - 1);
	float seg_pos = (float(seg_idx) + 0.5) / float(segment_count);
	bool is_filled = seg_pos <= fill_ratio;
	float fill_mult = is_filled ? 1.0 : 0.3;
	gain_glow = wave_glow(seg_pos, gain_wave_pos) * fill_mult;
	drain_glow = wave_glow(seg_pos, drain_wave_pos) * fill_mult;

	// Combine colors
	vec3 base_col = fill_color.rgb * base * vert_soft;
	vec3 inner_col = mix(fill_color.rgb, vec3(1.0), 0.7) * inner * vert_soft;

	vec3 lit_total = base_col + inner_col;

	// Apply gain wave: brighten toward white
	vec3 gain_col = mix(fill_color.rgb, vec3(1.0), 0.6) * gain_glow * vert_soft;
	lit_total += gain_col;

	// Apply drain wave: shift toward red/warning
	vec3 drain_col = vec3(1.0, 0.2, 0.1) * drain_glow * vert_soft;
	lit_total += drain_col;

	float wave_alpha = (gain_glow + drain_glow) * 0.6;
	float alpha = clamp(base + wave_alpha, 0.0, 1.0);

	// Mix lit segments with background, apply HDR multiplier for engine bloom
	vec3 final_color = mix(bg_color.rgb, lit_total * hdr_multiplier, alpha) * vert_soft
				+ bg_color.rgb * (1.0 - vert_soft);

	COLOR = vec4(final_color, modulate_alpha);
}
