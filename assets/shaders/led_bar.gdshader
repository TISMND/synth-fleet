shader_type canvas_item;

uniform int segment_count : hint_range(4, 40) = 20;
uniform float segment_gap : hint_range(0.005, 0.04) = 0.015;
uniform float inner_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float aura_size : hint_range(0.0, 0.06) = 0.02;
uniform float aura_intensity : hint_range(0.0, 2.0) = 0.8;
uniform float bloom_size : hint_range(0.0, 0.15) = 0.05;
uniform float bloom_intensity : hint_range(0.0, 1.5) = 0.4;
uniform float smudge_blur : hint_range(0.0, 0.03) = 0.008;
uniform vec4 fill_color : source_color = vec4(0.15, 0.7, 0.3, 1.0);
uniform vec4 bg_color : source_color = vec4(0.05, 0.05, 0.08, 1.0);
uniform float fill_ratio : hint_range(0.0, 1.0) = 0.75;
// Padding: fraction of total overlay rect that is glow margin
uniform float pad_x : hint_range(0.0, 0.5) = 0.05;
uniform float pad_y : hint_range(0.0, 0.5) = 0.2;

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
// gap is in absolute bar-UV space.
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

// Signed distance to nearest lit segment surface (negative = inside, positive = outside).
// Works in bar UV space for x, and bar UV space for y.
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

		// Box SDF (2D distance to rectangle)
		float dx = max(max(sx0 - bar_uv.x, bar_uv.x - sx1), 0.0);
		float dy = max(max(0.0 - bar_uv.y, bar_uv.y - 1.0), 0.0);
		float d = sqrt(dx * dx + dy * dy);
		min_dist = min(min_dist, d);
	}
	return min_dist;
}

void fragment() {
	vec2 bar_uv = to_bar_uv(UV);
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

	// Inner intensity: blow out center of lit segments toward white
	float inner = 0.0;
	if (base > 0.5 && inner_intensity > 0.0 && inside) {
		float vert_center = 1.0 - abs(bar_uv.y - 0.5) * 2.0;
		inner = base * vert_center * inner_intensity;
	}

	// Aura: tight glow around lit segments
	float aura = 0.0;
	if (aura_size > 0.0001 && d > 0.0) {
		aura = exp(-d * d / (aura_size * aura_size * 0.5)) * aura_intensity;
	}
	// Also add aura contribution for pixels inside lit segments (edge bloom inward)
	if (base > 0.5 && aura_intensity > 0.0) {
		aura = max(aura, aura_intensity * 0.3);
	}

	// Bloom: wide soft glow extending further
	float bloom = 0.0;
	if (bloom_size > 0.0001 && d > 0.0) {
		bloom = exp(-d * d / (bloom_size * bloom_size * 0.5)) * bloom_intensity;
	}

	// Vertical softness (only for the bar body, not the glow)
	float vert_soft = 1.0;
	if (inside) {
		vert_soft = smoothstep(0.0, 0.12, bar_uv.y) * smoothstep(1.0, 0.88, bar_uv.y);
	}

	// Combine
	vec3 base_col = fill_color.rgb * base * vert_soft;
	vec3 inner_col = mix(fill_color.rgb, vec3(1.0), 0.7) * inner * vert_soft;
	vec3 aura_col = fill_color.rgb * aura;
	vec3 bloom_col = fill_color.rgb * bloom * 0.6;

	vec3 lit_total = base_col + inner_col + aura_col + bloom_col;
	float alpha = clamp(base + aura * 0.8 + bloom * 0.4, 0.0, 1.0);

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

	COLOR = vec4(clamp(final_color, vec3(0.0), vec3(1.0)), final_alpha);
}
