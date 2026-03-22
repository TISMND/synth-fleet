shader_type canvas_item;

// Per-segment bezel shader — renders individual socket/frame effects around each
// LED segment. Uses the same segment grid math as led_bar_hdr.gdshader so bezels
// align perfectly with the LED segments they frame.
//
// The rect can be larger than the bar via edge_pad_x / edge_pad_y (in UV).
// The segment grid is remapped into the inner region. End segments' bezel
// frames extend naturally into the padding zone. Everything else is transparent.

// Segment grid (must match led_bar_hdr values passed to this bar)
uniform int segment_count : hint_range(1, 40) = 10;
uniform float segment_gap : hint_range(0.0, 0.12) = 0.04;
uniform int vertical : hint_range(0, 1) = 1;

// Edge padding in UV space (fraction of total rect).
uniform float edge_pad_x : hint_range(0.0, 0.3) = 0.0;
uniform float edge_pad_y : hint_range(0.0, 0.3) = 0.0;

// Per-socket bezel geometry
uniform float socket_bezel : hint_range(0.0, 0.5) = 0.15;
uniform float socket_radius : hint_range(0.0, 0.5) = 0.1;

// Inner shadow per socket
uniform float inner_shadow_intensity : hint_range(0.0, 2.0) = 0.8;
uniform float inner_shadow_softness : hint_range(0.0, 1.0) = 0.5;
uniform float shadow_direction : hint_range(-1.0, 1.0) = 0.4;

// Bevel highlight per socket
uniform float bevel_intensity : hint_range(0.0, 1.5) = 0.3;
uniform float bevel_softness : hint_range(0.0, 1.0) = 0.5;

// Rim / accent around each socket
uniform float rim_intensity : hint_range(0.0, 2.0) = 0.0;
uniform float rim_width : hint_range(0.0, 0.15) = 0.02;
uniform vec4 rim_color : source_color = vec4(0.3, 0.8, 1.0, 1.0);

// Metal surface
uniform vec4 metal_color : source_color = vec4(0.12, 0.13, 0.18, 1.0);
uniform float metal_roughness : hint_range(0.0, 1.0) = 0.5;

// Outer shadow — soft darkening halo around the segment array
uniform float outer_shadow_intensity : hint_range(0.0, 2.0) = 0.0;
uniform float outer_shadow_size : hint_range(0.0, 0.3) = 0.08;

// Depth
uniform float depth_scale : hint_range(0.0, 2.0) = 1.0;


float sdf_rounded_rect(vec2 p, vec2 half_size, float radius) {
	vec2 q = abs(p) - half_size + vec2(radius);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
}

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float mod_a = COLOR.a;
	vec2 uv = UV;

	// Remap for vertical bars — same transform as led_bar_hdr
	if (vertical == 1) {
		uv = vec2(1.0 - uv.y, uv.x);
	}
	// Now uv.x = along segments (0→1), uv.y = across bar width (0→1)

	// Remap UV into bar region (the inner area excluding edge padding).
	// bar_uv can go outside 0-1 in the padding zone — that's intentional.
	float inner_span_x = max(1.0 - 2.0 * edge_pad_x, 0.001);
	float inner_span_y = max(1.0 - 2.0 * edge_pad_y, 0.001);
	float bar_uv_x = (uv.x - edge_pad_x) / inner_span_x;
	float bar_uv_y = (uv.y - edge_pad_y) / inner_span_y;

	// Cell aspect ratio
	vec2 px = TEXTURE_PIXEL_SIZE;
	float rect_w_px = 1.0 / max(px.x, 0.0001);
	float rect_h_px = 1.0 / max(px.y, 0.0001);
	float along_px;
	float across_px;
	if (vertical == 1) {
		along_px = rect_h_px * inner_span_x / float(segment_count);
		across_px = rect_w_px * inner_span_y;
	} else {
		along_px = rect_w_px * inner_span_x / float(segment_count);
		across_px = rect_h_px * inner_span_y;
	}
	float cell_aspect = across_px / max(along_px, 1.0);

	// --- Segment SDF — always computed, even in padding zone ---
	// Clamp to nearest segment so end bezels extend into padding naturally.
	float seg_w = 1.0 / float(segment_count);

	int seg_i = int(floor(bar_uv_x / seg_w));
	seg_i = clamp(seg_i, 0, segment_count - 1);
	float seg_start = float(seg_i) * seg_w;

	// Local UV within this segment cell (can exceed 0-1 in padding)
	float lx = (bar_uv_x - seg_start) / seg_w;
	float ly = bar_uv_y;

	// Center local UV and apply aspect correction
	vec2 c = vec2(lx - 0.5, (ly - 0.5) * cell_aspect);
	vec2 half_ext = vec2(0.5, 0.5 * cell_aspect);

	// Outer rect = full cell
	float r_outer = socket_radius * min(cell_aspect, 1.0);
	float d_outer = sdf_rounded_rect(c, half_ext, r_outer);

	// Inner rect = LED cutout
	vec2 half_inner = half_ext - vec2(socket_bezel, socket_bezel * cell_aspect);
	half_inner = max(half_inner, vec2(0.01));
	float r_inner = max(r_outer - socket_bezel * min(cell_aspect, 1.0), 0.0);
	float d_inner = sdf_rounded_rect(c, half_inner, r_inner);

	float in_outer = 1.0 - smoothstep(-0.005, 0.005, d_outer);
	float in_inner = 1.0 - smoothstep(-0.005, 0.005, d_inner);
	float bezel_mask = in_outer * (1.0 - in_inner);

	// --- Metal color ---
	vec3 col = metal_color.rgb;
	if (metal_roughness > 0.0) {
		float grain = hash21(uv * 500.0);
		col += vec3((grain - 0.5) * metal_roughness * 0.06);
	}

	// --- Socket depth effects (only where bezel is visible) ---
	float depth_raw = 0.0;
	if (socket_bezel > 0.001 && bezel_mask > 0.0) {
		float from_inner = max(d_inner, 0.0);
		float from_outer = max(-d_outer, 0.0);
		float total = from_inner + from_outer;
		depth_raw = (total > 0.001) ? from_outer / total : 0.5;
	}
	float depth = depth_raw * depth_scale;

	// Inner shadow
	if (inner_shadow_intensity > 0.0 && bezel_mask > 0.0) {
		float sh = pow(max(depth, 0.0), mix(0.5, 2.0, 1.0 - inner_shadow_softness));
		if (abs(shadow_direction) > 0.01 && length(c) > 0.001) {
			vec2 to_ctr = normalize(-c);
			vec2 light_dir = normalize(vec2(-1.0, -1.0) * shadow_direction);
			float bias = dot(to_ctr, light_dir) * 0.5 + 0.5;
			sh *= mix(0.5, 1.5, bias);
		}
		col *= 1.0 - sh * inner_shadow_intensity * 0.8;
	}

	// Bevel highlight
	if (bevel_intensity > 0.0 && bezel_mask > 0.0 && length(c) > 0.001) {
		vec2 grad_dir = normalize(c);
		float facing = dot(grad_dir, normalize(vec2(-1.0, -1.0)));
		float ramp = smoothstep(0.0, mix(0.3, 1.0, bevel_softness), depth);
		float inv_ramp = smoothstep(1.0, mix(0.7, 0.0, bevel_softness), depth);
		col += vec3(facing * ramp * inv_ramp * bevel_intensity * 0.3);
	}

	// Rim around each socket
	if (rim_intensity > 0.0 && rim_width > 0.0) {
		float rim_d = abs(d_inner);
		float rim_mask = smoothstep(rim_width, rim_width * 0.2, rim_d) * in_outer;
		col = mix(col, rim_color.rgb * rim_intensity, rim_mask);
	}

	// --- Alpha: transparent by default, opaque only in bezel frames ---
	// Bezel frame = inside outer cell rect but NOT inside inner LED cutout.
	// This naturally handles padding: end segment bezels extend into padding,
	// but empty padding space stays transparent (d_outer > 0 → in_outer = 0).
	float socket_alpha = in_outer * (1.0 - in_inner);

	// --- Outer shadow: semi-transparent darkening halo in the padding zone ---
	float shadow_alpha = 0.0;
	if (outer_shadow_intensity > 0.0 && outer_shadow_size > 0.0) {
		// Distance from the bar region boundary
		float dx = 0.0;
		float dy = 0.0;
		if (bar_uv_x < 0.0) dx = -bar_uv_x;
		else if (bar_uv_x > 1.0) dx = bar_uv_x - 1.0;
		if (bar_uv_y < 0.0) dy = -bar_uv_y;
		else if (bar_uv_y > 1.0) dy = bar_uv_y - 1.0;
		float edge_dist = max(dx, dy);

		if (edge_dist > 0.0) {
			// Outside bar region: shadow fades outward
			float fade = 1.0 - smoothstep(0.0, outer_shadow_size, edge_dist);
			shadow_alpha = fade * outer_shadow_intensity * 0.5;
			col *= 1.0 - fade * outer_shadow_intensity * 0.4;
		} else {
			// Inside bar region: subtle inner edge darkening
			float inner_dx = min(bar_uv_x, 1.0 - bar_uv_x);
			float inner_dy = min(bar_uv_y, 1.0 - bar_uv_y);
			float inner_edge = min(inner_dx, inner_dy);
			float inner_darken = smoothstep(outer_shadow_size * 0.5, 0.0, inner_edge);
			col *= 1.0 - inner_darken * outer_shadow_intensity * 0.2;
		}
	}

	// Combine: socket bezel frames are fully opaque, shadow is semi-transparent,
	// everything else (gaps, cutouts, empty padding) is transparent.
	float final_alpha = max(socket_alpha, shadow_alpha);

	COLOR = vec4(col, final_alpha * mod_a * metal_color.a);
}
