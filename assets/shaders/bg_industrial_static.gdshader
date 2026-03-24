shader_type canvas_item;
// Static industrial deck — scroll controlled by uniform (not TIME).
// Designed for doodad placement: background position is deterministic and scrubbable.
// No animated elements (no pulsing glow, no blinking LEDs).

uniform vec4 plate_color : source_color = vec4(0.08, 0.09, 0.1, 1.0);
uniform vec4 seam_color : source_color = vec4(0.03, 0.035, 0.04, 1.0);
uniform vec4 rivet_color : source_color = vec4(0.22, 0.24, 0.26, 0.9);
uniform vec4 grate_glow : source_color = vec4(0.9, 0.4, 0.05, 0.7);
uniform vec4 warning_color : source_color = vec4(0.9, 0.7, 0.0, 0.6);
uniform vec4 shadow_color : source_color = vec4(0.01, 0.012, 0.015, 1.0);
uniform vec4 led_color : source_color = vec4(0.1, 0.8, 0.2, 1.0);
uniform vec4 conduit_color : source_color = vec4(0.14, 0.15, 0.17, 1.0);
uniform vec4 equip_color : source_color = vec4(0.06, 0.065, 0.075, 1.0);
uniform float scroll_offset : hint_range(0.0, 100000.0) = 0.0;
uniform float plate_size : hint_range(40.0, 200.0) = 100.0;
uniform float rivet_size : hint_range(1.0, 5.0) = 2.0;
uniform float grate_brightness : hint_range(0.0, 2.0) = 0.8;
uniform float depth_strength : hint_range(0.0, 1.0) = 0.6;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
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

void fragment() {
	vec2 uv = FRAGCOORD.xy;
	vec2 pos = uv + vec2(0.0, -scroll_offset);

	// ── Major plate grid ──
	vec2 cell = floor(pos / plate_size);
	vec2 local = pmod(pos, plate_size);
	float ch = hash21(cell);
	float ch2 = hash21(cell + vec2(7.3, 11.1));
	float ch3 = hash21(cell + vec2(31.7, 53.3));
	float ch4 = hash21(cell + vec2(61.1, 23.7));

	float elevation = 0.0;
	if (ch4 > 0.82) { elevation = 1.0; }
	else if (ch4 > 0.73) { elevation = 2.0; }

	float plate_type = 0.0;
	if (elevation < 1.5) {
		if (ch > 0.84) { plate_type = 1.0; }
		else if (ch > 0.74) { plate_type = 2.0; }
		else if (ch > 0.62) { plate_type = 3.0; }
		else if (ch > 0.45) { plate_type = 4.0; }
	}

	// ── Seams ──
	float seam_w = 2.5;
	float h_seam = 1.0 - smoothstep(0.0, seam_w, min(local.y, plate_size - local.y));
	float v_seam = 1.0 - smoothstep(0.0, seam_w, min(local.x, plate_size - local.x));
	float seam = max(h_seam, v_seam);
	float edge_mask = smoothstep(0.0, 8.0, min(local.y, plate_size - local.y))
		* smoothstep(0.0, 8.0, min(local.x, plate_size - local.x));

	// ── Rivets ──
	float inset = 7.0;
	float rivet = 0.0;
	for (int ry = 0; ry <= 1; ry++) {
		for (int rx = 0; rx <= 1; rx++) {
			vec2 rpos = vec2(inset + float(rx) * (plate_size - 2.0 * inset),
							 inset + float(ry) * (plate_size - 2.0 * inset));
			rivet = max(rivet, 1.0 - smoothstep(rivet_size - 0.5, rivet_size + 0.5, length(local - rpos)));
		}
	}

	// ── Depth: raised plates ──
	float depth_highlight = 0.0;
	float depth_shadow = 0.0;
	float shadow_w = 6.0 * depth_strength;
	if (elevation > 0.5 && elevation < 1.5) {
		depth_highlight = (1.0 - smoothstep(0.0, shadow_w, local.y)) * 0.12 * depth_strength;
		depth_highlight = max(depth_highlight,
			(1.0 - smoothstep(0.0, shadow_w, local.x)) * 0.08 * depth_strength);
		depth_shadow = (1.0 - smoothstep(0.0, shadow_w, plate_size - local.y)) * 0.15 * depth_strength;
		depth_shadow = max(depth_shadow,
			(1.0 - smoothstep(0.0, shadow_w, plate_size - local.x)) * 0.12 * depth_strength);
	}

	// ── Sunken ramps ──
	float ramp_dark = 0.0;
	float ramp_stripe = 0.0;
	if (elevation > 1.5) {
		float ramp_dir = step(0.5, ch2);
		float ramp_progress = mix(local.y / plate_size, local.x / plate_size, ramp_dir);
		ramp_dark = ramp_progress * 0.7 * depth_strength;
		ramp_dark += smoothstep(0.7, 1.0, ramp_progress) * 0.3;
		float stripe_edge = mix(
			min(local.x, plate_size - local.x),
			min(local.y, plate_size - local.y), ramp_dir);
		ramp_stripe = step(pmod1(pos.x + pos.y, 16.0), 8.0)
			* (1.0 - smoothstep(0.0, 15.0, stripe_edge)) * 0.25 * (1.0 - ramp_progress);
		depth_highlight = (1.0 - smoothstep(0.0, shadow_w * 2.0, mix(local.y, local.x, ramp_dir)))
			* 0.06 * depth_strength;
	}

	// ── Sub-grid plates ──
	float sub_seam = 0.0;
	float sub_rivet = 0.0;
	float sub_depth_hl = 0.0;
	float sub_depth_sh = 0.0;
	if (plate_type > 3.5 && plate_type < 4.5) {
		float sub_size = plate_size / 3.0;
		vec2 sub_local = pmod(local, sub_size);
		vec2 sub_cell = floor(local / sub_size);
		float sub_hash = hash21(sub_cell + cell * 10.0);
		sub_seam = max(
			1.0 - smoothstep(0.0, 1.5, min(sub_local.y, sub_size - sub_local.y)),
			1.0 - smoothstep(0.0, 1.5, min(sub_local.x, sub_size - sub_local.x))
		) * edge_mask;
		float sub_inset = 4.0;
		for (int sy = 0; sy <= 1; sy++) {
			for (int sx = 0; sx <= 1; sx++) {
				vec2 srp = vec2(sub_inset + float(sx) * (sub_size - 2.0 * sub_inset),
								sub_inset + float(sy) * (sub_size - 2.0 * sub_inset));
				sub_rivet = max(sub_rivet, 1.0 - smoothstep(1.0, 2.0, length(sub_local - srp)));
			}
		}
		sub_rivet *= edge_mask;
		float sub_sw = 3.0 * depth_strength;
		if (sub_hash > 0.6) {
			sub_depth_hl = max(
				(1.0 - smoothstep(0.0, sub_sw, sub_local.y)) * 0.08,
				(1.0 - smoothstep(0.0, sub_sw, sub_local.x)) * 0.06) * depth_strength;
			sub_depth_sh = max(
				(1.0 - smoothstep(0.0, sub_sw, sub_size - sub_local.y)) * 0.1,
				(1.0 - smoothstep(0.0, sub_sw, sub_size - sub_local.x)) * 0.08) * depth_strength;
		}
	}

	// ── Grate plates (static glow, no pulse) ──
	float grate = 0.0;
	if (plate_type > 0.5 && plate_type < 1.5) {
		grate = step(1.5, pmod1(local.x, 5.0)) * step(1.5, pmod1(local.y, 5.0)) * edge_mask;
	}

	// ── Access hatches ──
	float hatch = 0.0;
	float hatch_frame = 0.0;
	if (plate_type > 1.5 && plate_type < 2.5) {
		vec2 hc = vec2(plate_size * 0.5);
		vec2 hh = vec2(plate_size * 0.3);
		vec2 dh = abs(local - hc) - hh;
		float hs = max(dh.x, dh.y);
		hatch = 1.0 - smoothstep(-1.0, 0.5, hs);
		hatch_frame = max((1.0 - smoothstep(-3.0, -1.0, hs)) - (1.0 - smoothstep(-1.0, 0.5, hs)), 0.0);
		float handle = step(abs(local.x - hc.x), plate_size * 0.12)
			* (1.0 - smoothstep(0.0, 2.0, abs(local.y - plate_size * 0.35)));
		hatch_frame = max(hatch_frame, handle * 0.7);
		for (int by = 0; by <= 1; by++) {
			for (int bx = 0; bx <= 1; bx++) {
				vec2 bolt = hc + vec2(
					(float(bx) * 2.0 - 1.0) * (hh.x - 4.0),
					(float(by) * 2.0 - 1.0) * (hh.y - 4.0));
				hatch_frame = max(hatch_frame, 1.0 - smoothstep(1.5, 3.0, length(local - bolt)));
			}
		}
	}

	// ── Equipment pads (static, no LED blink) ──
	float equip_pad = 0.0;
	float equip_box = 0.0;
	float equip_hl = 0.0;
	if (plate_type > 2.5 && plate_type < 3.5) {
		vec2 pad_margin = vec2(10.0);
		vec2 pad_d = abs(local - vec2(plate_size * 0.5)) - (vec2(plate_size * 0.5) - pad_margin);
		equip_pad = 1.0 - smoothstep(-1.0, 0.5, max(pad_d.x, pad_d.y));
		equip_hl = (1.0 - smoothstep(0.0, 4.0, local.y - pad_margin.y))
			* step(pad_margin.x, local.x) * step(local.x, plate_size - pad_margin.x)
			* 0.06 * depth_strength;
		vec2 b1c = vec2(plate_size * 0.35, plate_size * 0.45);
		vec2 b1h = vec2(plate_size * 0.15, plate_size * 0.2);
		equip_box = max(equip_box, 1.0 - smoothstep(-0.5, 0.5, max(abs(local.x - b1c.x) - b1h.x, abs(local.y - b1c.y) - b1h.y)));
		vec2 b2c = vec2(plate_size * 0.7, plate_size * 0.55);
		vec2 b2h = vec2(plate_size * 0.1, plate_size * 0.12);
		equip_box = max(equip_box, 1.0 - smoothstep(-0.5, 0.5, max(abs(local.x - b2c.x) - b2h.x, abs(local.y - b2c.y) - b2h.y)));
		// Static LED (always on)
		float led_d = length(local - b1c - vec2(b1h.x - 4.0, -b1h.y + 4.0));
		equip_hl += (1.0 - smoothstep(0.8, 2.0, led_d)) * 0.3;
	}

	// ── Conduit runs ──
	float conduit = 0.0;
	float conduit_bracket = 0.0;
	float h_seam_cell_y = round(pos.y / plate_size);
	float h_cond_on = step(0.6, hash21(vec2(3.7, h_seam_cell_y * 11.3)));
	float h_cond_dist = min(pmod1(pos.y, plate_size), plate_size - pmod1(pos.y, plate_size));
	conduit = max(conduit, (1.0 - smoothstep(0.0, 3.0, abs(h_cond_dist - 6.0))) * h_cond_on);
	conduit_bracket = max(conduit_bracket, step(pmod1(pos.x, 30.0), 3.0) * conduit * 0.5);
	float v_seam_cell_x = round(pos.x / plate_size);
	float v_cond_on = step(0.65, hash21(vec2(v_seam_cell_x * 13.7, 7.1)));
	float v_cond_dist = min(pmod1(pos.x, plate_size), plate_size - pmod1(pos.x, plate_size));
	float v_conduit = (1.0 - smoothstep(0.0, 3.0, abs(v_cond_dist - 6.0))) * v_cond_on;
	conduit = max(conduit, v_conduit);
	conduit_bracket = max(conduit_bracket, step(pmod1(pos.y, 30.0), 3.0) * v_conduit * 0.5);

	// ── Warning stripes ──
	float warning = 0.0;
	if (step(0.92, hash21(cell + vec2(31.0, 17.0))) > 0.5 && plate_type < 0.5 && elevation < 0.5) {
		warning = step(pmod1(pos.x + pos.y, 20.0), 10.0) * 0.3 * edge_mask;
	}

	// ── Static LED indicators (always on) ──
	float led = 0.0;
	if (ch3 > 0.85 && elevation < 0.5 && plate_type < 0.5) {
		led = 1.0 - smoothstep(1.0, 2.5, length(local - vec2(plate_size - 12.0, 12.0)));
	}

	// ── Stenciled markings ──
	float stencil = 0.0;
	if (plate_type < 0.5 && ch2 > 0.65 && elevation < 0.5) {
		float my = local.y - plate_size * 0.7;
		float mx = local.x - plate_size * 0.15;
		float in_area = step(0.0, mx) * step(mx, plate_size * 0.4) * step(0.0, my) * step(my, 8.0);
		stencil = step(pmod1(mx, 7.0), 4.0) * in_area
			* step(0.5, hash21(vec2(floor(mx / 7.0), cell.y))) * 0.15;
	}

	// ── Metallic texture ──
	float metal = noise(pos * 0.12) * 0.025;
	float scratch = noise(pos * 0.6 + vec2(ch * 100.0, 0.0)) * 0.015;

	// ── Compose ──
	vec3 col = plate_color.rgb + vec3(metal + scratch);
	col *= 0.88 + 0.24 * ch;
	col = mix(col, shadow_color.rgb, ramp_dark);
	col = mix(col, seam_color.rgb, seam * 0.85);
	col = mix(col, seam_color.rgb, sub_seam * 0.6);
	col = mix(col, rivet_color.rgb * 0.8, sub_rivet * 0.5);
	col += vec3(sub_depth_hl);
	col -= vec3(sub_depth_sh);
	col += vec3(depth_highlight);
	col -= vec3(depth_shadow);
	col = mix(col, rivet_color.rgb, rivet);
	col = mix(col, grate_glow.rgb * grate_brightness * 0.7, grate * 0.7);
	col = mix(col, shadow_color.rgb * 1.5, hatch * 0.7);
	col = mix(col, rivet_color.rgb * 1.2, hatch_frame * 0.7);
	col = mix(col, plate_color.rgb * 1.15, equip_pad * 0.4);
	col += vec3(equip_hl);
	col = mix(col, equip_color.rgb, equip_box * 0.85);
	col = mix(col, warning_color.rgb, ramp_stripe);
	col = mix(col, conduit_color.rgb, conduit * 0.8);
	col = mix(col, rivet_color.rgb, conduit_bracket * 0.6);
	col += vec3(conduit * 0.04 * depth_strength);
	col = mix(col, warning_color.rgb, warning);
	col += vec3(stencil) * 0.5;
	col += led_color.rgb * led * 0.8;

	COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
