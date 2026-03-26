shader_type canvas_item;
// Holographic warning box OUTLINE — scanlines, edge glow, flicker, chromatic shift.
// Interior is transparent (see-through). Only the border and its glow are visible.
// Apply to a ColorRect sized to the desired box area.

uniform vec4 box_color : source_color = vec4(1.0, 0.3, 0.2, 1.0);
uniform vec2 rect_size = vec2(240.0, 80.0);  // Actual pixel size of the ColorRect
uniform float scanline_density : hint_range(50.0, 800.0) = 300.0;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.4;
uniform float edge_width : hint_range(1.0, 12.0) = 2.0;
uniform float edge_glow_width : hint_range(0.0, 20.0) = 8.0;
uniform float flicker_speed : hint_range(0.0, 20.0) = 4.0;
uniform float flicker_amount : hint_range(0.0, 1.0) = 0.15;
uniform float chromatic_shift : hint_range(0.0, 10.0) = 2.0;
uniform float hdr_intensity : hint_range(1.0, 6.0) = 2.5;
uniform float noise_amount : hint_range(0.0, 0.3) = 0.05;
uniform float scroll_speed : hint_range(0.0, 200.0) = 30.0;
uniform float corner_radius : hint_range(0.0, 20.0) = 4.0;
uniform bool double_border = false;

float hash_f(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float rounded_box_sdf(vec2 center_pos, vec2 half_size, float radius) {
	vec2 d = abs(center_pos) - half_size + vec2(radius);
	return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - radius;
}

void fragment() {
	// Work in pixel space relative to the ColorRect
	vec2 local_px = UV * rect_size;
	vec2 center = local_px - rect_size * 0.5;
	float dist = rounded_box_sdf(center, rect_size * 0.5, corner_radius);

	// Outside the rounded rect — fully transparent
	if (dist > edge_glow_width) {
		COLOR = vec4(0.0);
		return;
	}

	// Flicker
	float flicker = 1.0 - flicker_amount * (0.5 + 0.5 * sin(TIME * flicker_speed + sin(TIME * 2.3) * 3.0));

	// Scrolling scanlines (screen-space Y for consistency across boxes)
	float scan_y = FRAGCOORD.y + TIME * scroll_speed;
	float scanline = 0.5 + 0.5 * sin(scan_y * scanline_density * 0.01);
	float scan_darken = 1.0 - scanline_strength * (1.0 - scanline);

	// Border band: sharp edge at the rounded rect perimeter
	// dist < 0 = inside, dist > 0 = outside
	// The border straddles dist=0: outer edge to inner edge
	float half_w = edge_width * 0.5;
	float border = smoothstep(half_w + 1.0, half_w, abs(dist));  // 1px antialiasing

	// Outer glow — soft falloff outside the border
	float outer_glow = 0.0;
	if (dist > -half_w) {
		outer_glow = exp(-max(dist - half_w, 0.0) * 0.3) * 0.5;
	}

	// Inner glow — soft falloff inside the border
	float inner_glow = 0.0;
	if (dist < half_w) {
		float inner_dist = abs(dist + half_w);
		inner_glow = exp(-inner_dist * 0.15) * 0.2;
	}

	// Double border — second thinner line inside
	float inner_border = 0.0;
	if (double_border) {
		float inner_offset = edge_width * 2.5;
		float inner_dist = dist + inner_offset;
		inner_border = smoothstep(half_w * 0.4 + 1.0, half_w * 0.4, abs(inner_dist)) * 0.6;
	}

	// Noise grain
	float noise = (hash_f(FRAGCOORD.xy + fract(TIME * 37.0)) - 0.5) * noise_amount * 2.0;

	// Combine: border (bright) + glow (softer) + inner glow (subtle)
	float edge_total = border + inner_border;
	float glow_total = outer_glow + inner_glow;
	float brightness = (edge_total * hdr_intensity + glow_total * hdr_intensity * 0.4);
	brightness *= scan_darken * flicker;
	brightness += noise * max(edge_total, glow_total * 0.5);

	// Chromatic shift on the border
	vec3 col = box_color.rgb;
	vec3 final_col = col * brightness;
	if (chromatic_shift > 0.0 && edge_total > 0.1) {
		float shift_frac = chromatic_shift * 0.008;
		final_col.r = col.r * (brightness * (1.0 + edge_total * shift_frac * 2.0));
		final_col.b = col.b * (brightness * (1.0 - edge_total * shift_frac));
	}

	// Alpha: border is opaque, glow fades, interior is transparent
	float alpha = clamp(edge_total + glow_total, 0.0, 1.0) * flicker;

	// Interior fully transparent (only border + glow visible)
	if (dist < -half_w - edge_glow_width * 0.5 && !double_border) {
		// Deep interior — let inner glow fade to nothing
		float fade = exp((dist + half_w + edge_glow_width * 0.5) * 0.1);
		alpha *= fade;
		final_col *= fade;
	}

	COLOR = vec4(final_col, alpha);
}
