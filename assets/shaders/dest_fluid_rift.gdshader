shader_type canvas_item;
// Fluid Rift — Spiral vortex + aurora curtains + geometric lightning + flickering
// geometric HDR pulses with angular masking. Same mechanics as neon void, blue palette.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 3.0;
uniform vec3 bg_color : source_color = vec3(0.0, 0.01, 0.04);
uniform vec3 fluid_color : source_color = vec3(0.2, 0.6, 1.0);
uniform vec3 aurora_color : source_color = vec3(0.3, 0.85, 0.95);
uniform vec3 line_color : source_color = vec3(0.12, 0.45, 0.85);
uniform vec3 bolt_color : source_color = vec3(0.4, 0.8, 1.0);
uniform float vortex_radius : hint_range(0.05, 0.3) = 0.18;
uniform float swirl_speed : hint_range(0.0, 1.0) = 0.3;
uniform float curtain_count : hint_range(2.0, 8.0) = 5.0;
uniform float wave_amplitude : hint_range(0.01, 0.12) = 0.05;
uniform float line_density : hint_range(8.0, 35.0) = 16.0;
uniform float line_brightness : hint_range(0.2, 3.0) = 1.5;
uniform float pulse_speed : hint_range(0.5, 5.0) = 2.0;
uniform float pulse_count : hint_range(1.0, 8.0) = 5.0;
uniform float pulse_hdr : hint_range(1.0, 30.0) = 21.0;
uniform float pulse_width : hint_range(0.005, 0.15) = 0.03;
uniform float bolt_count : hint_range(2.0, 10.0) = 5.0;
uniform float bolt_brightness : hint_range(0.5, 8.0) = 3.5;
uniform float tendril_count : hint_range(2.0, 10.0) = 5.0;
uniform float tendril_length : hint_range(0.05, 0.5) = 0.2;
uniform float drift_speed : hint_range(0.0, 0.3) = 0.06;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
	           mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * vnoise(p); p *= 2.0; a *= 0.5; }
	return v;
}

float seg_dist(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float len2 = dot(ab, ab);
	if (len2 < 0.000001) return length(p - a);
	float t = clamp(dot(p - a, ab) / len2, 0.0, 1.0);
	return length(p - (a + ab * t));
}

void fragment() {
	vec2 uv = UV;
	float ar = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 center = vec2(0.5, 0.48);
	vec2 d = vec2((uv.x - center.x) * ar, uv.y - center.y);
	float dist = length(d);
	float angle = atan(d.y, d.x);
	vec3 col = bg_color;

	// ══════════════════════════════════════════════
	// LAYER 1: Aurora curtains (background)
	// ══════════════════════════════════════════════
	int cc = int(curtain_count);
	for (int i = 0; i < 8; i++) {
		if (i >= cc) break;
		float fi = float(i);
		float base_x = 0.12 + fi * 0.76 / curtain_count;

		float wave = sin(uv.y * 10.0 + TIME * swirl_speed * (0.6 + fi * 0.15) + fi * 2.0) * wave_amplitude;
		wave += sin(uv.y * 18.0 - TIME * swirl_speed * 0.4 + fi * 3.5) * wave_amplitude * 0.35;
		wave += sin(uv.y * 4.0 + TIME * swirl_speed * 0.2 + fi * 1.2) * wave_amplitude * 0.6;
		float noise_disp = (fbm(vec2(uv.y * 2.5 + fi * 5.0, TIME * 0.06)) - 0.5) * 0.06;

		float curtain_x = base_x + wave + noise_disp;
		float dx = abs(uv.x - curtain_x);
		float curtain = exp(-dx * dx * 1500.0);

		float height_var = fbm(vec2(fi * 3.0 + uv.y * 3.0, TIME * 0.05));
		height_var = smoothstep(0.25, 0.7, height_var);

		vec3 c = mix(fluid_color, aurora_color, fract(fi * 0.4 + TIME * 0.03));
		float val = curtain * height_var;
		val *= smoothstep(vortex_radius * 0.5, vortex_radius * 1.8, abs(uv.x - center.x) * ar + abs(uv.y - center.y));
		col += c * val * hdr_intensity * 0.6;
	}

	// ══════════════════════════════════════════════
	// LAYER 2: Spiral vortex center
	// ══════════════════════════════════════════════
	float swirl_a = angle - dist * 10.0 + TIME * swirl_speed;
	float arms = sin(swirl_a * 3.0) * 0.5 + 0.5;
	arms = pow(arms, 2.0);

	vec2 turb_uv = vec2(swirl_a * 0.5, dist * 6.0) + TIME * vec2(0.0, -0.08);
	float turb = fbm(turb_uv * 2.0) * 0.25;
	arms = clamp(arms + turb - 0.12, 0.0, 1.0);

	float arm_fade = smoothstep(vortex_radius * 2.2, vortex_radius * 0.35, dist);
	float arm_outside = smoothstep(vortex_radius * 0.1, vortex_radius * 0.4, dist);
	arms *= arm_fade * arm_outside;
	col += fluid_color * arms * hdr_intensity * 0.5;

	// Core glow
	float core = exp(-dist * 10.0 / vortex_radius);
	col += aurora_color * core * hdr_intensity * 0.4;
	// Dark eye
	float eye = smoothstep(vortex_radius * 0.15, vortex_radius * 0.04, dist);
	col = mix(col, bg_color * 0.4, eye * 0.6);

	// ── Tendrils from vortex ──
	int ttc = int(tendril_count);
	for (int i = 0; i < 10; i++) {
		if (i >= ttc) break;
		float fi = float(i);
		float t_angle = fi * 6.2832 / tendril_count + TIME * swirl_speed * 0.15;
		// Anchor at vortex edge
		vec2 anchor = vec2(cos(t_angle), sin(t_angle)) * vortex_radius * 0.9;
		vec2 outward = normalize(vec2(cos(t_angle), sin(t_angle)));
		vec2 pixel_from_anchor = d - anchor;
		float along = dot(pixel_from_anchor, outward);
		float perp = length(pixel_from_anchor - outward * along);
		if (along > -0.02 && along < tendril_length) {
			float t_param = along / tendril_length;
			float wave_t = sin(t_param * 10.0 + TIME * 1.2 + fi * 2.3) * 0.02;
			wave_t += sin(t_param * 16.0 - TIME * 0.8 + fi * 3.7) * 0.012;
			wave_t += sin(t_param * 5.0 + TIME * 0.5 + fi * 1.5) * 0.03;
			wave_t += (fbm(vec2(t_param * 2.5 + fi * 5.0, TIME * 0.1)) - 0.5) * 0.035;
			float adjusted_perp = abs(perp - wave_t);
			float width = mix(0.025, 0.004, t_param * t_param);
			float tendril_val = exp(-adjusted_perp * adjusted_perp / (width * width));
			float tip_fade = smoothstep(1.0, 0.5, t_param);
			float base_fade = smoothstep(-0.02, 0.05, along);
			float brightness = 0.5 + 0.5 * sin(t_param * 8.0 - TIME * 2.5 + fi * 2.0);
			col += aurora_color * tendril_val * tip_fade * base_fade * brightness * hdr_intensity * 0.7;
		}
	}

	// ══════════════════════════════════════════════
	// LIGHTNING STRIKES — geometric bolts from vortex edge
	// Same mechanics as neon void: shaft + branches, short duration.
	// ══════════════════════════════════════════════
	float lightning_val = 0.0;
	int bc = int(bolt_count);
	for (int bolt = 0; bolt < 10; bolt++) {
		if (bolt >= bc) break;
		float fb = float(bolt);

		// Staggered cycles, longer gaps than neon void (more calm)
		float cycle_period = 2.0 + hash(vec2(fb, 77.0)) * 3.0;
		float cycle_phase = hash(vec2(fb, 66.0)) * cycle_period;
		float cycle_t = mod(TIME + cycle_phase, cycle_period);

		float shaft_duration = 0.5;
		float shaft_alive = smoothstep(shaft_duration, shaft_duration - 0.05, cycle_t)
		                   * smoothstep(0.0, 0.02, cycle_t);
		if (shaft_alive < 0.01) continue;

		float shaft_flash = shaft_alive * smoothstep(shaft_duration, 0.0, cycle_t);

		float strike_id = floor((TIME + cycle_phase) / cycle_period);
		// Bolts spiral out from vortex (angle includes swirl offset)
		float bolt_angle = fb * 6.2832 / bolt_count
		                 + hash(vec2(fb, strike_id * 3.0)) * 1.0 - 0.5
		                 + TIME * swirl_speed * 0.1;
		vec2 pos = vec2(cos(bolt_angle), sin(bolt_angle)) * vortex_radius * 0.8;
		vec2 out_dir = normalize(vec2(cos(bolt_angle), sin(bolt_angle)));
		vec2 perp_dir = vec2(-out_dir.y, out_dir.x);

		for (int seg = 0; seg < 10; seg++) {
			float fs = float(seg);
			float seg_seed = hash(vec2(fb * 13.0 + fs, strike_id * 7.0 + fs));

			vec2 direction;
			float seg_len;
			if (seg % 2 == 0) {
				direction = out_dir;
				seg_len = 0.025 + seg_seed * 0.06;
			} else {
				float jog_sign = (seg_seed > 0.5) ? 1.0 : -1.0;
				direction = perp_dir * jog_sign;
				seg_len = 0.012 + seg_seed * 0.035;
			}

			vec2 next_pos = pos + direction * seg_len;
			float sd = seg_dist(d, pos, next_pos);
			float s_core = smoothstep(0.004, 0.001, sd);
			float s_glow = exp(-sd * sd / 0.00008);
			float range_fade = smoothstep(0.5, 0.02, length(pos));

			lightning_val += (s_core * 1.0 + s_glow * 0.3) * range_fade * shaft_flash;

			// Branches
			float branch_chance = hash(vec2(fb * 5.0 + fs, strike_id + 100.0));
			if (branch_chance > 0.6 && seg % 2 == 0) {
				float branch_delay = hash(vec2(fb * 9.0 + fs, strike_id + 200.0)) * 0.3;
				float branch_t = cycle_t - branch_delay;
				float branch_dur = 0.15;
				float branch_alive = smoothstep(branch_dur, branch_dur - 0.03, branch_t)
				                   * smoothstep(0.0, 0.01, branch_t);
				float branch_flash = branch_alive * smoothstep(branch_dur, 0.0, branch_t);

				if (branch_flash > 0.01) {
					float branch_sign = (hash(vec2(fb + fs * 3.0, strike_id + 300.0)) > 0.5) ? 1.0 : -1.0;
					vec2 branch_dir = perp_dir * branch_sign;
					vec2 bpos = (pos + next_pos) * 0.5;

					for (int bseg = 0; bseg < 5; bseg++) {
						float bfs = float(bseg);
						float bseed = hash(vec2(fb * 17.0 + fs * 3.0 + bfs, strike_id + bfs));
						vec2 bdir;
						float blen;
						if (bseg % 2 == 0) {
							bdir = branch_dir;
							blen = 0.01 + bseed * 0.02;
						} else {
							bdir = out_dir * ((bseed > 0.5) ? 1.0 : -1.0);
							blen = 0.007 + bseed * 0.012;
						}
						vec2 bnext = bpos + bdir * blen;
						float bsd = seg_dist(d, bpos, bnext);
						float bcore = smoothstep(0.003, 0.0008, bsd);
						float bglow = exp(-bsd * bsd / 0.00005);
						float bfade = smoothstep(0.25, 0.01, length(bpos));

						lightning_val += (bcore * 0.8 + bglow * 0.2) * bfade * branch_flash;
						bpos = bnext;
					}
				}
			}

			pos = next_pos;
		}
	}
	lightning_val = min(lightning_val, 5.0);
	col += bolt_color * lightning_val * bolt_brightness * hdr_intensity * 0.55;

	// ══════════════════════════════════════════════
	// HDR PULSES — geometric wavefronts, irregular, flickering, angular masked
	// ══════════════════════════════════════════════
	float ring_boost = 0.0;
	float pixel_angle = atan(d.y, d.x);
	float manhattan_dist = abs(d.x) + abs(d.y);
	float chebyshev_dist = max(abs(d.x), abs(d.y));
	int pc = int(pulse_count);
	for (int i = 0; i < 8; i++) {
		if (i >= pc) break;
		float fi = float(i);

		float period = 1.5 + hash(vec2(fi, 11.0)) * 2.5;
		float phase = hash(vec2(fi, 22.0)) * period;
		float cycle_t = mod(TIME + phase, period);

		float active_window = period * 0.2;
		float pulse_alive = smoothstep(active_window, active_window - 0.05, cycle_t)
		                   * smoothstep(0.0, 0.03, cycle_t);
		if (pulse_alive < 0.01) continue;

		// Angular mask
		float strike_id = floor((TIME + phase) / period);
		float arc_center = hash(vec2(fi * 3.0, strike_id * 7.0)) * 6.2832 - 3.14159;
		float arc_half = 0.52 + hash(vec2(fi * 5.0, strike_id * 11.0)) * 1.05;
		float angle_diff = abs(mod(pixel_angle - arc_center + 3.14159, 6.2832) - 3.14159);
		float arc_mask = smoothstep(arc_half, arc_half - 0.25, angle_diff);
		if (arc_mask < 0.01) continue;

		float ring_t = cycle_t / active_window;
		float wave_radius = ring_t * 0.85;

		// Alternate diamond / square wavefronts
		float shape_pick = hash(vec2(fi * 7.0, strike_id * 13.0));
		float geo_dist = (shape_pick > 0.5) ? chebyshev_dist : manhattan_dist;
		float scale = (shape_pick > 0.5) ? 1.0 : 0.7;
		float wave_match = abs(geo_dist * scale - wave_radius);
		float ring = exp(-wave_match * wave_match / (pulse_width * pulse_width));

		// Chaotic flicker
		float flk = sin(TIME * 41.0 + fi * 7.0) * sin(TIME * 29.0 + fi * 13.0);
		flk = flk * 0.5 + 0.5;
		flk *= step(0.3, sin(TIME * 53.0 + fi * 19.0));
		float intensity = (1.0 - ring_t * 0.4) * pulse_alive * flk;
		ring_boost += ring * intensity * arc_mask;
	}
	ring_boost = min(ring_boost, 6.0);

	// ── Geometric grid lines ──
	vec2 grid_offset = vec2(sin(TIME * drift_speed * 0.6) * 0.008, cos(TIME * drift_speed) * 0.008);
	vec2 grid_uv = (uv + grid_offset) * line_density;
	vec2 cell_id = floor(grid_uv);
	vec2 cell_f = fract(grid_uv);

	float cell_dist = length((cell_id + 0.5) / line_density - center);
	float base_activity = smoothstep(0.5, 0.03, cell_dist);
	float thin_chance = smoothstep(0.07, 0.4, cell_dist);
	float sparse_mask = step(thin_chance * 0.7, hash(cell_id + 200.0));
	float activity = base_activity * sparse_mask;
	activity *= smoothstep(0.0, 0.04, cell_dist - 0.02);

	float h_active = step(0.35, hash(cell_id)) * activity;
	float v_active = step(0.35, hash(cell_id + 77.0)) * activity;
	float near_center = smoothstep(0.1, 0.03, cell_dist);
	h_active = max(h_active, near_center);
	v_active = max(v_active, near_center);

	float line_w = 0.041;
	float h_line = smoothstep(line_w, line_w * 0.12, abs(cell_f.y - 0.5)) * h_active;
	float v_line = smoothstep(line_w, line_w * 0.12, abs(cell_f.x - 0.5)) * v_active;
	float line_core = max(h_line, v_line);

	float base_dim = 0.03;
	float ring_lit = ring_boost * pulse_hdr;
	col += line_color * line_core * (base_dim + ring_lit) * line_brightness * hdr_intensity * 0.15;

	// Nodes
	float at_int = smoothstep(0.1, 0.02, max(abs(cell_f.x - 0.5), abs(cell_f.y - 0.5)));
	float node_active = min(h_active, v_active);
	col += line_color * at_int * node_active * (base_dim + ring_lit * 0.5) * hdr_intensity * 0.2;

	// Ring ambient wash
	float ambient_mask = smoothstep(0.0, 0.04, dist) * smoothstep(0.8, 0.05, dist);
	col += aurora_color * ring_boost * hdr_intensity * 0.04 * ambient_mask;

	// ── Stars ──
	for (int layer = 0; layer < 2; layer++) {
		float gs = (layer == 0) ? 90.0 : 140.0;
		float lo = float(layer) * 300.0;
		vec2 cell_s = floor(uv * vec2(gs, gs * 0.5));
		float h = hash(cell_s + lo);
		if (h > 0.95) {
			vec2 soff = vec2(hash(cell_s + lo + 111.0), hash(cell_s + lo + 222.0));
			vec2 sp = (cell_s + soff) / vec2(gs, gs * 0.5);
			float d_star = length((uv - sp) * vec2(ar, 1.0));
			float tw = 0.7 + 0.3 * sin(TIME * (1.0 + h * 3.0) + h * 6.28);
			float star = exp(-d_star * d_star / 0.000004) * tw;
			star *= smoothstep(vortex_radius * 0.3, vortex_radius * 2.0, dist);
			col += vec3(0.6, 0.8, 1.0) * star * 1.2;
		}
	}

	COLOR = vec4(col, 1.0);
}
