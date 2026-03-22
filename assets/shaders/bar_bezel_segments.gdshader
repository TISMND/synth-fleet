shader_type canvas_item;

// Per-segment bezel shader — renders individual socket/frame effects around each
// LED segment. Uses the same segment grid math as led_bar_hdr.gdshader so bezels
// align perfectly with the LED segments they frame.
// Applied to a ColorRect overlaying the bar. Transparent between segments and
// inside each segment cutout; opaque metal frame around each socket.

// Segment grid (must match led_bar_hdr values passed to this bar)
uniform int segment_count : hint_range(1, 40) = 10;
uniform float segment_gap : hint_range(0.0, 0.12) = 0.04;
uniform int vertical : hint_range(0, 1) = 1;

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

	// Segment grid math — same as led_bar_hdr.gdshader
	float seg_w = 1.0 / float(segment_count);
	float half_gap = segment_gap * 0.5;

	int seg_i = int(floor(uv.x / seg_w));
	seg_i = clamp(seg_i, 0, segment_count - 1);

	float seg_start = float(seg_i) * seg_w;

	// Local UV within this segment cell, normalized 0→1
	float lx = (uv.x - seg_start) / seg_w;
	float ly = uv.y;

	// Cell aspect ratio: how wide vs tall is one segment cell in pixels.
	// For a vertical bar, after UV remap:
	//   uv.x spans the rect's height (long axis)
	//   uv.y spans the rect's width (short axis)
	// TEXTURE_PIXEL_SIZE: px.x = 1/rect_width, px.y = 1/rect_height
	vec2 px = TEXTURE_PIXEL_SIZE;
	float rect_w_px = 1.0 / max(px.x, 0.0001);
	float rect_h_px = 1.0 / max(px.y, 0.0001);

	float along_px;  // pixels per segment along the fill direction
	float across_px; // pixels across the bar width
	if (vertical == 1) {
		along_px = rect_h_px * seg_w;  // height * fraction = segment length
		across_px = rect_w_px;          // width = bar width
	} else {
		along_px = rect_w_px * seg_w;
		across_px = rect_h_px;
	}

	// cell_aspect = across / along — how much wider than tall each cell is
	float cell_aspect = across_px / max(along_px, 1.0);

	// Center local UV and apply aspect correction so SDF is isotropic
	vec2 c = vec2(lx - 0.5, (ly - 0.5) * cell_aspect);
	vec2 half_ext = vec2(0.5, 0.5 * cell_aspect);

	// Outer rect = full cell
	float r_outer = socket_radius * min(cell_aspect, 1.0);
	float d_outer = sdf_rounded_rect(c, half_ext, r_outer);

	// Inner rect = LED cutout, inset by socket_bezel
	vec2 half_inner = half_ext - vec2(socket_bezel, socket_bezel * cell_aspect);
	half_inner = max(half_inner, vec2(0.01));
	float r_inner = max(r_outer - socket_bezel * min(cell_aspect, 1.0), 0.0);
	float d_inner = sdf_rounded_rect(c, half_inner, r_inner);

	// Bezel mask: inside outer AND outside inner
	float in_outer = 1.0 - smoothstep(-0.005, 0.005, d_outer);
	float in_inner = 1.0 - smoothstep(-0.005, 0.005, d_inner);
	float bezel_mask = in_outer * (1.0 - in_inner);

	// Depth into bezel frame (0 = outer edge, 1 = inner edge)
	float depth_raw = 0.0;
	if (socket_bezel > 0.001) {
		float from_inner = max(d_inner, 0.0);
		float from_outer = max(-d_outer, 0.0);
		float total = from_inner + from_outer;
		depth_raw = (total > 0.001) ? from_outer / total : 0.5;
	}
	float depth = depth_raw * depth_scale;

	// --- Metal base color ---
	vec3 col = metal_color.rgb;
	if (metal_roughness > 0.0) {
		float grain = hash21(uv * 500.0);
		col += vec3((grain - 0.5) * metal_roughness * 0.06);
	}

	// --- Inner shadow ---
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

	// --- Bevel highlight ---
	if (bevel_intensity > 0.0 && bezel_mask > 0.0 && length(c) > 0.001) {
		vec2 grad_dir = normalize(c);
		float facing = dot(grad_dir, normalize(vec2(-1.0, -1.0)));
		float ramp = smoothstep(0.0, mix(0.3, 1.0, bevel_softness), depth);
		float inv_ramp = smoothstep(1.0, mix(0.7, 0.0, bevel_softness), depth);
		col += vec3(facing * ramp * inv_ramp * bevel_intensity * 0.3);
	}

	// --- Rim around each socket ---
	if (rim_intensity > 0.0 && rim_width > 0.0) {
		float rim_d = abs(d_inner);
		float rim_mask = smoothstep(rim_width, rim_width * 0.2, rim_d) * in_outer;
		col = mix(col, rim_color.rgb * rim_intensity, rim_mask);
	}

	// --- Alpha: opaque in bezel frame, transparent in cutout and outside ---
	// in_outer handles outer edge softness, in_inner handles cutout softness
	float final_alpha = in_outer * (1.0 - in_inner);

	COLOR = vec4(col, final_alpha * mod_a * metal_color.a);
}
