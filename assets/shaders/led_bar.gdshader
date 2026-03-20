shader_type canvas_item;

uniform int segment_count : hint_range(4, 40) = 20;
uniform float segment_gap : hint_range(0.0, 0.12) = 0.04;
// Inner glow
uniform float inner_intensity : hint_range(0.0, 2.0) = 0.3;
uniform float inner_softness : hint_range(0.1, 3.0) = 1.0;
// Aura (tight glow around segments)
uniform float aura_size : hint_range(0.0, 0.15) = 0.02;
uniform float aura_intensity : hint_range(0.0, 3.0) = 0.8;
uniform float aura_falloff : hint_range(0.1, 4.0) = 1.0;
// Bloom (wide soft glow)
uniform float bloom_size : hint_range(0.0, 0.3) = 0.05;
uniform float bloom_intensity : hint_range(0.0, 2.0) = 0.4;
uniform float bloom_falloff : hint_range(0.1, 4.0) = 1.0;
// Smudge
uniform float smudge_blur : hint_range(0.0, 0.03) = 0.008;
// Core
uniform vec4 fill_color : source_color = vec4(0.15, 0.7, 0.3, 1.0);
uniform vec4 bg_color : source_color = vec4(0.05, 0.05, 0.08, 1.0);
uniform float fill_ratio : hint_range(0.0, 1.0) = 0.75;
// Padding: fraction of total overlay rect that is glow margin
uniform float pad_x : hint_range(0.0, 0.5) = 0.05;
uniform float pad_y : hint_range(0.0, 0.5) = 0.2;
// Aspect ratio (bar_width / bar_height) for isotropic glow
uniform float bar_aspect : hint_range(0.01, 30.0) = 5.0;
// Vertical mode: 0 = horizontal (default), 1 = vertical (bottom-to-top fill)
uniform int vertical : hint_range(0, 1) = 0;
// Rolling wave animations (per-segment directional glow)
uniform float gain_wave_pos : hint_range(-1.0, 2.0) = -1.0;  // upward roll position (-1 = inactive)
uniform float drain_wave_pos : hint_range(-1.0, 2.0) = -1.0; // downward roll position (-1 = inactive)
uniform float wave_intensity : hint_range(0.0, 1.5) = 0.5;   // brightness boost at wave peak
uniform float wave_width : hint_range(0.02, 0.4) = 0.15;     // width of the glow wave (normalized)

// Remap UV from overlay space to bar space.
// Bar occupies [pad_x, 1-pad_x] x [pad_y, 1-pad_y] in overlay UV.
vec2 to_bar_uv(vec2 uv) {
	return vec2(
		(uv.x - pad_x) / max(1.0 - 2.0 * pad_x, 0.001),
		(uv.y - pad_y) / max(1.0 - 2.0 * pad_y, 0.001)
	);
}

bool in_bar(vec2 bar_uv) {
	return bar_uv.x >= 0.0 && bar_uv.x <= 1.0 && bar_uv.y >= 0.0 && bar_uv.y <= 1.0;
}

// Returns 1.0 if bar_uv_x is inside a lit segment, 0.0 otherwise.
float is_lit(float bx) {
	if (bx < 0.0 || bx > 1.0) return 0.0;
	float seg_width = 1.0 / float(segment_count);
	float half_gap = segment_gap * 0.5;

	int seg_index = int(floor(bx / seg_width));
	float seg_start = float(seg_index) * seg_width;
	float seg_end = seg_start + seg_width;

	// Inside gap?
	if (bx - seg_start < half_gap || seg_end - bx < half_gap) {
		return 0.0;
	}

	// Lit if segment midpoint is within fill range
	float seg_mid = (float(seg_index) + 0.5) / float(segment_count);
	return seg_mid <= fill_ratio ? 1.0 : 0.0;
}

// Per-segment radial distance: 0.0 at center, 1.0 at edge, -1.0 if not in a lit segment.
// Uses aspect ratio so the gradient is circular in pixel space.
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
	// Normalize y by aspect so the gradient is circular in pixel space
	float ny = abs(bar_uv.y - 0.5) * 2.0 / bar_aspect;

	return clamp(sqrt(nx * nx + ny * ny), 0.0, 1.0);
}

// Pixel-isotropic SDF to nearest lit segment surface.
// dy is scaled by 1/aspect so vertical and horizontal distances match in pixels.
float sdf_lit(vec2 bar_uv) {
	float seg_width = 1.0 / float(segment_count);
	float half_gap = segment_gap * 0.5;
	float min_dist = 999.0;

	int center_seg = int(floor(clamp(bar_uv.x, 0.0, 0.999) / seg_width));
	for (int offset = -3; offset <= 3; offset++) {
		int si = center_seg + offset;
		if (si < 0 || si >= segment_count) continue;

		float seg_mid = (float(si) + 0.5) / float(segment_count);
		if (seg_mid > fill_ratio) continue; // unlit

		// Segment rect in bar UV: x=[seg_start+half_gap, seg_end-half_gap], y=[0,1]
		float sx0 = float(si) * seg_width + half_gap;
		float sx1 = float(si + 1) * seg_width - half_gap;

		// Box SDF — normalize dy by aspect for isotropic pixel distance
		float dx = max(max(sx0 - bar_uv.x, bar_uv.x - sx1), 0.0);
		float dy = max(max(0.0 - bar_uv.y, bar_uv.y - 1.0), 0.0) / bar_aspect;
		float d = sqrt(dx * dx + dy * dy);
		min_dist = min(min_dist, d);
	}
	return min_dist;
}

// Compute wave glow contribution for a segment at normalized position seg_pos.
// wave_pos is the current wave center (-1 = inactive). Returns 0.0-1.0 glow amount.
float wave_glow(float seg_pos, float wave_pos) {
	if (wave_pos < -0.5) return 0.0;  // inactive
	float dist = abs(seg_pos - wave_pos);
	float half_w = wave_width * 0.5;
	if (dist > half_w) return 0.0;
	// Smooth gaussian-like falloff
	float t = dist / half_w;
	return (1.0 - t * t) * wave_intensity;
}

void fragment() {
	float modulate_alpha = COLOR.a;
	vec2 uv = UV;
	if (vertical == 1) {
		uv = vec2(1.0 - uv.y, uv.x);  // bottom-to-top fill
	}
	vec2 bar_uv = to_bar_uv(uv);
	bool inside = in_bar(bar_uv);

	// Smudge: horizontal blur of the base lit signal (only inside bar)
	float base = 0.0;
	if (inside) {
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
	}

	// SDF distance for glow (works both inside and outside bar rect)
	float d = sdf_lit(bar_uv);

	// Inner intensity: per-segment radial white gradient (stays within segment rects)
	float inner = 0.0;
	if (inner_intensity > 0.0 && inside) {
		float seg_dist = segment_center_dist(bar_uv);
		if (seg_dist >= 0.0) {
			float radial = pow(1.0 - seg_dist, inner_softness);
			inner = radial * inner_intensity;
		}
	}

	// Aura: tight glow around lit segments
	float aura = 0.0;
	if (aura_size > 0.0001 && d > 0.0) {
		aura = exp(-d * d / (aura_size * aura_size * aura_falloff)) * aura_intensity;
	}
	// Also add aura contribution for pixels inside lit segments (edge bloom inward)
	if (base > 0.5 && aura_intensity > 0.0) {
		aura = max(aura, aura_intensity * 0.3);
	}

	// Bloom: wide soft glow extending further
	float bloom = 0.0;
	if (bloom_size > 0.0001 && d > 0.0) {
		bloom = exp(-d * d / (bloom_size * bloom_size * bloom_falloff)) * bloom_intensity;
	}

	// Vertical softness (only for the bar body, not the glow)
	float vert_soft = 1.0;
	if (inside) {
		vert_soft = smoothstep(0.0, 0.12, bar_uv.y) * smoothstep(1.0, 0.88, bar_uv.y);
	}

	// Rolling wave glow (per-segment)
	float gain_glow = 0.0;
	float drain_glow = 0.0;
	if (inside) {
		// Get the normalized segment position for this pixel
		float seg_width = 1.0 / float(segment_count);
		int seg_idx = clamp(int(floor(bar_uv.x / seg_width)), 0, segment_count - 1);
		float seg_pos = (float(seg_idx) + 0.5) / float(segment_count);
		bool is_filled = seg_pos <= fill_ratio;

		// Compute wave contributions — full strength on filled segments, reduced on empty
		float fill_mult = is_filled ? 1.0 : 0.3;
		gain_glow = wave_glow(seg_pos, gain_wave_pos) * fill_mult;
		drain_glow = wave_glow(seg_pos, drain_wave_pos) * fill_mult;
	}

	// Combine
	vec3 base_col = fill_color.rgb * base * vert_soft;
	vec3 inner_col = mix(fill_color.rgb, vec3(1.0), 0.7) * inner * vert_soft;
	vec3 aura_col = fill_color.rgb * aura;
	vec3 bloom_col = fill_color.rgb * bloom * 0.6;

	vec3 lit_total = base_col + inner_col + aura_col + bloom_col;

	// Apply gain wave: brighten toward white
	vec3 gain_col = mix(fill_color.rgb, vec3(1.0), 0.6) * gain_glow * vert_soft;
	lit_total += gain_col;

	// Apply drain wave: shift toward red/warning
	vec3 drain_col = vec3(1.0, 0.2, 0.1) * drain_glow * vert_soft;
	lit_total += drain_col;

	float wave_alpha = (gain_glow + drain_glow) * 0.6;
	float alpha = clamp(base + aura * 0.8 + bloom * 0.4 + wave_alpha, 0.0, 1.0);

	// Inside bar: mix with bg. Outside bar: glow over transparent.
	vec3 final_color;
	float final_alpha;
	if (inside) {
		final_color = mix(bg_color.rgb, lit_total, alpha) * vert_soft
					+ bg_color.rgb * (1.0 - vert_soft);
		final_alpha = 1.0;
	} else {
		// Outside bar rect: only glow, over transparent
		final_color = lit_total;
		final_alpha = clamp(aura * 0.6 + bloom * 0.3, 0.0, 0.9);
	}

	COLOR = vec4(clamp(final_color, vec3(0.0), vec3(1.0)), final_alpha * modulate_alpha);
}
