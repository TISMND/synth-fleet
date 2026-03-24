shader_type canvas_item;
// Mid-layer scrolling background: microchip die / silicon wafer surface.
// Anti-aliased patterns — minimum spacings prevent moire flickering.

uniform vec4 silicon_color : source_color = vec4(0.02, 0.02, 0.04, 1.0);
uniform vec4 metal_color : source_color = vec4(0.45, 0.42, 0.55, 0.7);
uniform vec4 metal_bright : source_color = vec4(0.7, 0.65, 0.8, 1.0);
uniform vec4 pad_color : source_color = vec4(0.75, 0.6, 0.15, 0.9);
uniform vec4 active_color : source_color = vec4(0.1, 0.5, 0.9, 0.4);
uniform float scroll_speed : hint_range(0.0, 200.0) = 35.0;
uniform float block_size : hint_range(60.0, 300.0) = 160.0;
uniform float line_width : hint_range(0.5, 3.0) = 1.2;
uniform float hdr_gleam : hint_range(0.0, 4.0) = 2.0;
uniform float gleam_period : hint_range(3.0, 15.0) = 8.0;
uniform float activity_speed : hint_range(0.0, 3.0) = 0.8;
uniform bool manual_scroll = false;
uniform float scroll_offset : hint_range(0.0, 100000.0) = 0.0;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hash_f(float p) {
	return fract(sin(p * 127.1 + 311.7) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec2 pmod(vec2 x, float s) {
	return fract(x / s) * s;
}

float pmod1(float x, float s) {
	return fract(x / s) * s;
}

// Anti-aliased line: smoothstep with minimum 1px transition
float aa_line(float dist, float width) {
	return 1.0 - smoothstep(0.0, max(width, 1.0), dist);
}

void fragment() {
	vec2 uv = FRAGCOORD.xy;
	float y_scroll = manual_scroll ? -scroll_offset : -TIME * scroll_speed;
	vec2 pos = uv + vec2(0.0, y_scroll);

	// ── Level 1: Major blocks ──
	vec2 block_cell = floor(pos / block_size);
	vec2 block_local = pmod(pos, block_size);
	float block_hash = hash21(block_cell);
	float block_hash2 = hash21(block_cell + vec2(11.0, 7.0));

	float block_type = floor(block_hash * 4.0);

	// Block border (scribe lines)
	float border_w = 3.0;
	float bx = min(block_local.x, block_size - block_local.x);
	float by = min(block_local.y, block_size - block_local.y);
	float border = aa_line(min(bx, by), border_w);

	// Scribe channel
	float channel = aa_line(min(bx, by), 1.5);

	// ── Level 2: Sub-cells ──
	float sub_div = floor(3.0 + block_hash2 * 2.0); // 3-4 divisions (not 5, too fine)
	float sub_size = block_size / sub_div;
	vec2 sub_local = pmod(block_local, sub_size);
	vec2 sub_cell = floor(block_local / sub_size);
	float sub_hash = hash21(sub_cell + block_cell * 7.0);

	// Sub-cell grid lines
	float sub_bx = min(sub_local.x, sub_size - sub_local.x);
	float sub_by = min(sub_local.y, sub_size - sub_local.y);
	float sub_grid = max(aa_line(sub_bx, line_width), aa_line(sub_by, line_width));
	sub_grid *= smoothstep(0.0, border_w + 2.0, min(bx, by));

	// ── Internal patterns — all with anti-aliased minimum spacings ──
	float pattern = 0.0;
	float pattern_bright = 0.0;

	if (block_type < 1.0) {
		// MEMORY ARRAY: regular grid, minimum 8px spacing
		float mem_sp = 8.0 + floor(block_hash2 * 4.0) * 2.0; // 8, 10, 12, 14
		float mem_x = pmod1(block_local.x, mem_sp);
		float mem_y = pmod1(block_local.y, mem_sp);
		// Cell fill rectangles
		float cell_fill = smoothstep(mem_sp * 0.55, mem_sp * 0.6, mem_x)
			* (1.0 - smoothstep(0.0, mem_sp * 0.15, mem_x));
		cell_fill = max(cell_fill, 0.0);
		float cell_fill_y = smoothstep(mem_sp * 0.4, mem_sp * 0.45, mem_y)
			* (1.0 - smoothstep(0.0, mem_sp * 0.1, mem_y));
		pattern = max(cell_fill * 0.12, cell_fill_y * 0.1);
		// Word lines (horizontal, anti-aliased)
		pattern = max(pattern, aa_line(mem_y, line_width) * 0.2);
		// Bit lines (vertical, every other column)
		float bit_col = floor(block_local.x / mem_sp);
		float bit_on = smoothstep(0.4, 0.6, fract(bit_col * 0.5));
		pattern = max(pattern, aa_line(mem_x, line_width * 0.8) * bit_on * 0.15);

	} else if (block_type < 2.0) {
		// LOGIC BLOCK: standard cell rows, minimum 10px row height
		float row_h = 10.0 + floor(block_hash2 * 3.0) * 4.0; // 10, 14, 18
		float row_local_y = pmod1(block_local.y, row_h);
		// Power rails
		float rail = max(aa_line(row_local_y, line_width), aa_line(row_h - row_local_y, line_width));
		pattern = rail * 0.25;
		// Gate lines (vertical, minimum 8px spacing)
		float gate_sp = 8.0 + floor(hash21(block_cell + vec2(5.0, 0.0)) * 3.0) * 2.0;
		float gate_col = floor(block_local.x / gate_sp);
		float gate_hash = hash21(vec2(gate_col, floor(block_local.y / row_h)) + block_cell * 3.0);
		float gate_x = pmod1(block_local.x, gate_sp);
		float gate_line = aa_line(gate_x, line_width * 0.8) * step(0.4, gate_hash);
		pattern = max(pattern, gate_line * 0.15);
		// Diffusion fill regions
		float in_fill = smoothstep(2.0, 3.0, gate_x) * (1.0 - smoothstep(gate_sp - 3.0, gate_sp - 2.0, gate_x))
			* smoothstep(2.5, 3.5, row_local_y) * (1.0 - smoothstep(row_h - 3.5, row_h - 2.5, row_local_y));
		float fill_on = step(0.35, hash21(vec2(gate_col, floor(block_local.y / row_h)) + block_cell * 13.0));
		pattern = max(pattern, in_fill * fill_on * 0.07);

	} else if (block_type < 3.0) {
		// I/O RING: bond pads, minimum 18px spacing
		float pad_sp = 18.0;
		float pad_size_val = 6.0;
		float margin = block_size * 0.15;
		float near_edge = min(min(block_local.x, block_size - block_local.x),
			min(block_local.y, block_size - block_local.y));
		float in_pad_zone = 1.0 - smoothstep(margin - 1.0, margin + 1.0, near_edge);
		// Pads with smooth edges
		float pad_x = pmod1(block_local.x, pad_sp);
		float pad_y = pmod1(block_local.y, pad_sp);
		float pad_dx = abs(pad_x - pad_sp * 0.5);
		float pad_dy = abs(pad_y - pad_sp * 0.5);
		float pad = (1.0 - smoothstep(pad_size_val - 0.5, pad_size_val + 0.5, max(pad_dx, pad_dy)))
			* in_pad_zone;
		pattern_bright = pad * 0.6;
		// Driver grid (minimum 12px spacing)
		float drv_sp = 12.0;
		float in_driver = smoothstep(margin + 1.0, margin + 3.0, near_edge)
			* (1.0 - smoothstep(margin + 14.0, margin + 16.0, near_edge));
		float drv_grid = max(
			aa_line(pmod1(block_local.x, drv_sp), line_width),
			aa_line(pmod1(block_local.y, drv_sp), line_width)
		) * in_driver;
		pattern = max(pattern, drv_grid * 0.12);

	} else {
		// BUS ROUTING: parallel lines, minimum 6px spacing
		float bus_dir = step(0.5, block_hash2);
		float bus_sp = 6.0 + floor(hash21(block_cell + vec2(3.0, 0.0)) * 3.0) * 2.0; // 6, 8, 10
		float bus_coord = mix(block_local.y, block_local.x, bus_dir);
		float bus_line = aa_line(pmod1(bus_coord, bus_sp), line_width);
		float bus_col_idx = floor(bus_coord / bus_sp);
		float bus_on = step(0.3, hash_f(bus_col_idx * 7.1 + block_hash * 100.0));
		pattern = bus_line * bus_on * 0.18;
		// Cross-connections (minimum 22px spacing)
		float cross_sp = 22.0 + floor(block_hash2 * 4.0) * 5.0;
		float cross_coord = mix(block_local.x, block_local.y, bus_dir);
		float cross = aa_line(pmod1(cross_coord, cross_sp), line_width);
		float cross_on = step(0.6, hash21(vec2(floor(cross_coord / cross_sp), block_hash * 50.0)));
		pattern = max(pattern, cross * cross_on * 0.1);
	}

	// ── Active regions ──
	float activity = 0.0;
	if (activity_speed > 0.01) {
		float act_phase = TIME * activity_speed + block_hash * 6.28 + sub_hash * 3.14;
		float act_wave = 0.5 + 0.5 * sin(act_phase);
		float is_active = step(0.6, sub_hash);
		activity = act_wave * is_active * pattern * 0.3;
	}

	// ── HDR gleam sweep ──
	float gleam_pass = floor(TIME / gleam_period);
	float gleam_t = fract(TIME / gleam_period);
	float gleam_hash = hash_f(gleam_pass * 17.3 + 0.5);
	float gleam_angle = gleam_hash * 1.57;
	vec2 gleam_dir = vec2(cos(gleam_angle), sin(gleam_angle));
	float gleam_proj = dot(pos, gleam_dir) - gleam_t * 3000.0 - gleam_hash * 500.0;
	float gleam_mask = max(pattern, sub_grid) + border * 0.3;
	float gleam = exp(-gleam_proj * gleam_proj / 1200.0) * gleam_mask;
	gleam *= smoothstep(0.0, 0.1, gleam_t) * (1.0 - smoothstep(0.9, 1.0, gleam_t));

	// ── Silicon texture ──
	float si_tex = noise(pos * 0.05) * 0.008;

	// ── Compose ──
	vec3 col = silicon_color.rgb + vec3(si_tex);

	col = mix(col, silicon_color.rgb * 0.5, channel * 0.6);
	col = mix(col, metal_color.rgb * 0.5, border * 0.4);
	col = mix(col, metal_color.rgb, sub_grid * 0.5);
	col = mix(col, metal_color.rgb, pattern);
	col = mix(col, pad_color.rgb, pattern_bright);
	col += active_color.rgb * activity;
	col += metal_bright.rgb * gleam * hdr_gleam;

	COLOR = vec4(col, 1.0);
}
