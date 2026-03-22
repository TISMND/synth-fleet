shader_type canvas_item;

// Bar bezel / frame shader — renders depth effects around an LED bar region.
// Applied to a ColorRect that wraps the bar. The bar sits on top via z_index.
// Different parameter combos produce distinct looks: inner shadow, raised bevel,
// chamfered edge, neon trim, rubber gasket, deep well, etc.

// Bezel geometry
uniform float bezel_width : hint_range(0.0, 0.3) = 0.08;
uniform float corner_radius : hint_range(0.0, 0.2) = 0.02;

// Inner shadow (makes the bar look recessed/depressed into the panel)
uniform float inner_shadow_intensity : hint_range(0.0, 2.0) = 0.6;
uniform float inner_shadow_softness : hint_range(0.0, 1.0) = 0.5;
// Shadow direction: 0.0 = uniform, positive = light from top-left
uniform float shadow_direction : hint_range(-1.0, 1.0) = 0.4;

// Bevel highlight (3D raised/chamfered edge)
uniform float bevel_intensity : hint_range(0.0, 1.5) = 0.3;
// 0 = sharp bevel, 1 = smooth chamfer
uniform float bevel_softness : hint_range(0.0, 1.0) = 0.4;

// Outer highlight ring (neon trim / accent line)
uniform float rim_intensity : hint_range(0.0, 2.0) = 0.0;
uniform float rim_width : hint_range(0.0, 0.1) = 0.01;
uniform vec4 rim_color : source_color = vec4(0.3, 0.8, 1.0, 1.0);

// Metal surface
uniform vec4 metal_color : source_color = vec4(0.12, 0.13, 0.18, 1.0);
uniform float metal_roughness : hint_range(0.0, 1.0) = 0.5;
// Brushed metal direction: 0 = none, 1 = horizontal, 2 = vertical
uniform int brush_direction : hint_range(0, 2) = 0;
uniform float brush_intensity : hint_range(0.0, 0.5) = 0.08;

// Rivet/bolt accents at corners
uniform float rivet_size : hint_range(0.0, 0.04) = 0.0;
uniform float rivet_brightness : hint_range(0.0, 1.0) = 0.5;

// Overall depth multiplier
uniform float depth_scale : hint_range(0.0, 2.0) = 1.0;


// Signed distance to rounded rectangle (negative = inside)
float sdf_rounded_rect(vec2 p, vec2 half_size, float radius) {
	vec2 d = abs(p) - half_size + vec2(radius);
	return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - radius;
}

// Simple hash for brushed metal noise
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Value noise
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	float mod_a = COLOR.a;
	vec2 uv = UV;

	// Pixel size for aspect-correct SDF
	vec2 px = TEXTURE_PIXEL_SIZE;
	float aspect = px.y / max(px.x, 0.0001);

	// Center UV and apply aspect correction
	vec2 centered = (uv - 0.5) * vec2(1.0, aspect);
	vec2 half_ext = vec2(0.5, 0.5 * aspect);

	// Outer edge of bezel (full rect)
	float outer_dist = sdf_rounded_rect(centered, half_ext, corner_radius * aspect);

	// Inner edge (the bar cutout) — inset by bezel_width
	vec2 inner_half = half_ext - vec2(bezel_width, bezel_width * aspect);
	float inner_radius = max(corner_radius * aspect - bezel_width * aspect, 0.0);
	float inner_dist = sdf_rounded_rect(centered, inner_half, inner_radius);

	// Bezel zone: between outer and inner edges
	float in_bezel = step(inner_dist, 0.0) * step(outer_dist, 0.0);
	// Actually: outer edge is the full rect, inner edge is the cutout
	// We want: inside outer AND outside inner = bezel frame
	float outside_inner = 1.0 - step(inner_dist, 0.0);
	float inside_outer = step(outer_dist, 0.0);
	// But outer_dist < 0 means inside the rect... let me fix:
	float is_inside_outer = 1.0 - step(0.0, outer_dist);
	float is_outside_inner = step(0.0, inner_dist);
	float bezel_mask = is_inside_outer * is_outside_inner;

	// Normalized depth into bezel (0 at outer edge, 1 at inner edge)
	float bezel_depth_raw = 0.0;
	if (bezel_width > 0.001) {
		// Use inner_dist for depth: 0 at inner edge, negative deeper into bezel
		// Normalize by bezel_width
		float from_inner = max(inner_dist, 0.0);
		float from_outer = max(-outer_dist, 0.0);
		float total = from_inner + from_outer;
		bezel_depth_raw = (total > 0.001) ? from_outer / total : 0.5;
	}
	// bezel_depth_raw: 0 = at outer edge, 1 = at inner edge

	// --- Metal base color ---
	vec3 col = metal_color.rgb;

	// Brushed metal texture
	if (brush_direction > 0) {
		float brush_coord;
		if (brush_direction == 1) {
			// Horizontal brush: noise varies with y, streaks along x
			brush_coord = uv.y * 200.0;
			float n = noise(vec2(uv.x * 20.0, brush_coord));
			col += vec3((n - 0.5) * brush_intensity);
		} else {
			// Vertical brush: noise varies with x, streaks along y
			brush_coord = uv.x * 200.0;
			float n = noise(vec2(brush_coord, uv.y * 20.0));
			col += vec3((n - 0.5) * brush_intensity);
		}
	}

	// Metal roughness: subtle grain
	if (metal_roughness > 0.0) {
		float grain = noise(uv * 500.0);
		col += vec3((grain - 0.5) * metal_roughness * 0.06);
	}

	// --- Bezel effects (only in bezel zone) ---
	float depth = bezel_depth_raw * depth_scale;

	// Inner shadow: darkening that increases toward the inner edge
	float shadow = 0.0;
	if (inner_shadow_intensity > 0.0) {
		// Base shadow from depth
		float base_shadow = pow(depth, mix(0.5, 2.0, 1.0 - inner_shadow_softness));

		// Directional bias: darken bottom-right more (light from top-left)
		if (abs(shadow_direction) > 0.01 && length(centered) > 0.001) {
			vec2 to_center = normalize(-centered);
			// Light direction (top-left = (-1, -1) normalized)
			vec2 light_dir = normalize(vec2(-1.0, -1.0) * shadow_direction);
			float dir_bias = dot(to_center, light_dir) * 0.5 + 0.5;
			base_shadow *= mix(0.5, 1.5, dir_bias);
		}

		shadow = base_shadow * inner_shadow_intensity;
	}

	// Bevel highlight: bright edge on top/left, dark on bottom/right
	float bevel = 0.0;
	if (bevel_intensity > 0.0 && length(centered) > 0.001) {
		// Gradient based on position relative to inner edge
		vec2 grad_dir = normalize(centered);
		// Light from top-left: highlight where surface faces up-left
		float facing = dot(grad_dir, normalize(vec2(-1.0, -1.0)));
		// Ramp across the bezel width
		float ramp = smoothstep(0.0, mix(0.3, 1.0, bevel_softness), depth);
		float inv_ramp = smoothstep(1.0, mix(0.7, 0.0, bevel_softness), depth);
		bevel = facing * ramp * inv_ramp * bevel_intensity;
	}

	// Apply shadow and bevel to bezel zone
	col = col * (1.0 - shadow * bezel_mask * 0.8);
	col += vec3(bevel * bezel_mask * 0.3);

	// --- Rim / accent line at inner edge ---
	if (rim_intensity > 0.0 && rim_width > 0.0) {
		float rim_dist = abs(inner_dist);
		float rim_mask = smoothstep(rim_width, rim_width * 0.2, rim_dist);
		col = mix(col, rim_color.rgb * rim_intensity, rim_mask * bezel_mask);
		// Also apply rim just inside the cutout for glow bleed
		float inner_rim = smoothstep(rim_width * 0.5, 0.0, -inner_dist);
		col = mix(col, rim_color.rgb * rim_intensity * 0.5, inner_rim * (1.0 - bezel_mask));
	}

	// --- Rivets at corners ---
	if (rivet_size > 0.001) {
		float r = rivet_size * aspect;
		// Four corner positions (inset from edges)
		float inset_x = bezel_width * 0.5;
		float inset_y = bezel_width * 0.5 * aspect;
		vec2 corners[4];
		corners[0] = vec2(-0.5 + inset_x, -0.5 * aspect + inset_y);
		corners[1] = vec2(0.5 - inset_x, -0.5 * aspect + inset_y);
		corners[2] = vec2(-0.5 + inset_x, 0.5 * aspect - inset_y);
		corners[3] = vec2(0.5 - inset_x, 0.5 * aspect - inset_y);

		for (int i = 0; i < 4; i++) {
			float d = length(centered - corners[i]);
			float rivet = smoothstep(r, r * 0.5, d);
			// Slight 3D bump: bright top, dark bottom
			float bump = (centered.y - corners[i].y) / max(r, 0.001);
			vec3 rivet_col = metal_color.rgb * (1.0 + rivet_brightness * (0.5 - bump * 0.3));
			col = mix(col, rivet_col, rivet * bezel_mask);
		}
	}

	// --- Cutout: make the inner area transparent so the bar shows through ---
	float cutout_alpha = bezel_mask;
	// Soft anti-alias on inner edge
	float aa = fwidth(inner_dist);
	float inner_soft = smoothstep(-aa, aa, inner_dist);
	cutout_alpha = max(cutout_alpha, 0.0);

	// Final: bezel is opaque metal, cutout is transparent
	float final_alpha = inner_soft * is_inside_outer;

	COLOR = vec4(col, final_alpha * mod_a * metal_color.a);
}
