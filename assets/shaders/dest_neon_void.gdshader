shader_type canvas_item;
// Neon Void Rift — Vertical oval rip with tendrils, lightning-strike bolts
// (main shaft ~500ms with chaotic 150ms branches), and irregular HDR ring pulses.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 3.0;
uniform vec3 bg_color : source_color = vec3(0.01, 0.0, 0.03);
uniform vec3 rift_color : source_color = vec3(1.0, 0.1, 0.55);
uniform vec3 line_color : source_color = vec3(0.9, 0.06, 0.45);
uniform vec3 bolt_color : source_color = vec3(1.0, 0.3, 0.7);
uniform float rift_width : hint_range(0.02, 0.15) = 0.055;
uniform float rift_height : hint_range(0.05, 0.3) = 0.16;
uniform float line_brightness : hint_range(0.2, 4.0) = 1.5;
uniform float pulse_speed : hint_range(0.5, 5.0) = 2.5;
uniform float pulse_count : hint_range(1.0, 8.0) = 5.0;
uniform float pulse_hdr : hint_range(1.0, 30.0) = 21.0;
uniform float pulse_width : hint_range(0.005, 0.15) = 0.03;
uniform float line_density : hint_range(8.0, 40.0) = 18.0;
uniform float bolt_count : hint_range(2.0, 10.0) = 6.0;
uniform float bolt_brightness : hint_range(0.5, 8.0) = 4.0;
uniform float tendril_count : hint_range(2.0, 10.0) = 6.0;
uniform float tendril_length : hint_range(0.05, 0.5) = 0.25;
uniform float cloud_intensity : hint_range(0.0, 0.6) = 0.2;
uniform float drift_speed : hint_range(0.0, 0.3) = 0.08;

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
	for (int i = 0; i < 4; i++) { v += a * vnoise(p); p *= 2.1; a *= 0.45; }
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
	vec3 col = bg_color;

	// ── Rift ellipse ──
	float ex = d.x / rift_width;
	float ey = d.y / rift_height;
	float rift_dist = length(vec2(ex, ey));

	if (rift_dist < 1.0) {
		float inner = smoothstep(1.0, 0.2, rift_dist);
		col = mix(bg_color * 0.3, vec3(0.005, 0.0, 0.01), inner);
		float angle = atan(d.y, d.x);
		float swirl = sin(angle * 3.0 + TIME * 0.8 + rift_dist * 6.0) * 0.5 + 0.5;
		col += rift_color * swirl * inner * 0.12 * hdr_intensity;
	}

	float rim = smoothstep(0.6, 1.0, rift_dist) * smoothstep(1.5, 1.0, rift_dist);
	col += rift_color * rim * hdr_intensity * 1.2;
	float halo_val = exp(-max(rift_dist - 1.0, 0.0) * 3.0) * 0.5;
	col += rift_color * halo_val * hdr_intensity * 0.3;

	// ── Tendrils from rift ──
	int tc = int(tendril_count);
	for (int i = 0; i < 10; i++) {
		if (i >= tc) break;
		float fi = float(i);
		float t_angle = fi * 6.2832 / tendril_count + 0.3;
		vec2 anchor = vec2(cos(t_angle) * rift_width, sin(t_angle) * rift_height);
		vec2 outward = normalize(vec2(cos(t_angle), sin(t_angle)));
		vec2 pixel_from_anchor = d - anchor;
		float along = dot(pixel_from_anchor, outward);
		float perp = length(pixel_from_anchor - outward * along);
		if (along > -0.02 && along < tendril_length) {
			float t_param = along / tendril_length;
			float wave = sin(t_param * 8.0 + TIME * 1.0 + fi * 2.3) * 0.025;
			wave += sin(t_param * 14.0 - TIME * 0.7 + fi * 4.1) * 0.015;
			wave += sin(t_param * 4.0 + TIME * 0.4 + fi * 1.0) * 0.035;
			wave += (fbm(vec2(t_param * 2.5 + fi * 5.0, TIME * 0.08)) - 0.5) * 0.04;
			float adjusted_perp = abs(perp - wave);
			float width = mix(0.03, 0.005, t_param * t_param);
			float tendril_val = exp(-adjusted_perp * adjusted_perp / (width * width));
			float tip_fade = smoothstep(1.0, 0.5, t_param);
			float base_fade = smoothstep(-0.02, 0.05, along);
			float brightness = 0.5 + 0.5 * sin(t_param * 8.0 - TIME * 2.0 + fi * 2.0);
			col += rift_color * tendril_val * tip_fade * base_fade * brightness * hdr_intensity * 0.8;
		}
	}

	// ══════════════════════════════════════════════
	// LIGHTNING STRIKES — main shaft (~500ms) with chaotic branches (~150ms)
	// Each bolt has its own strike cycle. Most of the time: dark.
	// ══════════════════════════════════════════════
	float lightning_val = 0.0;
	int bc = int(bolt_count);
	for (int bolt = 0; bolt < 10; bolt++) {
		if (bolt >= bc) break;
		float fb = float(bolt);

		// Each bolt has its own cycle period (1.5 - 4 seconds between strikes)
		float cycle_period = 1.5 + hash(vec2(fb, 77.0)) * 2.5;
		float cycle_phase = hash(vec2(fb, 66.0)) * cycle_period;
		float cycle_t = mod(TIME + cycle_phase, cycle_period);

		// Main shaft: visible for ~0.5s at start of cycle, then dark
		float shaft_duration = 0.5;
		float shaft_alive = smoothstep(shaft_duration, shaft_duration - 0.05, cycle_t)
		                   * smoothstep(0.0, 0.02, cycle_t);
		if (shaft_alive < 0.01) continue;

		// Flash envelope — bright on strike, fading over duration
		float shaft_flash = shaft_alive * smoothstep(shaft_duration, 0.0, cycle_t);

		// Bolt geometry changes each strike (seed from cycle index)
		float strike_id = floor((TIME + cycle_phase) / cycle_period);
		float bolt_angle = fb * 6.2832 / bolt_count
		                 + hash(vec2(fb, strike_id * 3.0)) * 0.8 - 0.4;
		vec2 pos = vec2(cos(bolt_angle) * rift_width, sin(bolt_angle) * rift_height);
		vec2 out_dir = normalize(vec2(cos(bolt_angle), sin(bolt_angle)));
		vec2 perp_dir = vec2(-out_dir.y, out_dir.x);

		// Main shaft segments
		for (int seg = 0; seg < 10; seg++) {
			float fs = float(seg);
			float seg_seed = hash(vec2(fb * 13.0 + fs, strike_id * 7.0 + fs));

			vec2 direction;
			float seg_len;
			if (seg % 2 == 0) {
				direction = out_dir;
				seg_len = 0.03 + seg_seed * 0.07;
			} else {
				float jog_sign = (seg_seed > 0.5) ? 1.0 : -1.0;
				direction = perp_dir * jog_sign;
				seg_len = 0.015 + seg_seed * 0.04;
			}

			vec2 next_pos = pos + direction * seg_len;
			float sd = seg_dist(d, pos, next_pos);
			float core = smoothstep(0.004, 0.001, sd);
			float glow = exp(-sd * sd / 0.00008);
			float dist_from_start = length(pos);
			float range_fade = smoothstep(0.55, 0.02, dist_from_start);

			lightning_val += (core * 1.0 + glow * 0.3) * range_fade * shaft_flash;

			// ── Branches — shorter lived, chaotic ──
			// Spawn a branch from some shaft segments
			float branch_chance = hash(vec2(fb * 5.0 + fs, strike_id + 100.0));
			if (branch_chance > 0.55 && seg % 2 == 0) {
				// Branch alive for ~150ms, delayed randomly within shaft window
				float branch_delay = hash(vec2(fb * 9.0 + fs, strike_id + 200.0)) * 0.3;
				float branch_t = cycle_t - branch_delay;
				float branch_duration = 0.15;
				float branch_alive = smoothstep(branch_duration, branch_duration - 0.03, branch_t)
				                   * smoothstep(0.0, 0.01, branch_t);
				float branch_flash = branch_alive * smoothstep(branch_duration, 0.0, branch_t);

				if (branch_flash > 0.01) {
					// Branch goes perpendicular from this point on the shaft
					float branch_sign = (hash(vec2(fb + fs * 3.0, strike_id + 300.0)) > 0.5) ? 1.0 : -1.0;
					vec2 branch_dir = perp_dir * branch_sign;
					vec2 bpos = (pos + next_pos) * 0.5; // midpoint of shaft segment

					for (int bseg = 0; bseg < 5; bseg++) {
						float bfs = float(bseg);
						float bseed = hash(vec2(fb * 17.0 + fs * 3.0 + bfs, strike_id + bfs));
						vec2 bdir;
						float blen;
						if (bseg % 2 == 0) {
							bdir = branch_dir;
							blen = 0.01 + bseed * 0.025;
						} else {
							bdir = out_dir * ((bseed > 0.5) ? 1.0 : -1.0);
							blen = 0.008 + bseed * 0.015;
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
	// HDR PULSES — geometric (manhattan distance = diamond/square wavefront),
	// irregular timing, 80% off, angular masking.
	// ══════════════════════════════════════════════
	float ring_boost = 0.0;
	float pixel_angle = atan(d.y, d.x);
	// Manhattan distance from center — makes the wavefront diamond-shaped
	float manhattan_dist = abs(d.x) + abs(d.y);
	// Chebyshev (max of abs) — makes it square-shaped
	float chebyshev_dist = max(abs(d.x), abs(d.y));
	int pc = int(pulse_count);
	for (int i = 0; i < 8; i++) {
		if (i >= pc) break;
		float fi = float(i);

		float period = 1.2 + hash(vec2(fi, 11.0)) * 2.0;
		float phase = hash(vec2(fi, 22.0)) * period;
		float cycle_t = mod(TIME + phase, period);

		float active_window = period * 0.2;
		float pulse_alive = smoothstep(active_window, active_window - 0.05, cycle_t)
		                   * smoothstep(0.0, 0.03, cycle_t);
		if (pulse_alive < 0.01) continue;

		// Angular mask — each pulse covers a random arc
		float strike_id = floor((TIME + phase) / period);
		float arc_center = hash(vec2(fi * 3.0, strike_id * 7.0)) * 6.2832 - 3.14159;
		float arc_half = 0.52 + hash(vec2(fi * 5.0, strike_id * 11.0)) * 1.05;
		float angle_diff = abs(mod(pixel_angle - arc_center + 3.14159, 6.2832) - 3.14159);
		float arc_mask = smoothstep(arc_half, arc_half - 0.25, angle_diff);
		if (arc_mask < 0.01) continue;

		float ring_t = cycle_t / active_window;
		float wave_radius = ring_t * 0.85;

		// Alternate between diamond and square wavefronts per pulse
		float shape_pick = hash(vec2(fi * 7.0, strike_id * 13.0));
		float geo_dist = (shape_pick > 0.5) ? chebyshev_dist : manhattan_dist;
		// Scale to match: manhattan/chebyshev range differs from euclidean
		float scale = (shape_pick > 0.5) ? 1.0 : 0.7;
		float wave_match = abs(geo_dist * scale - wave_radius);
		float ring = exp(-wave_match * wave_match / (pulse_width * pulse_width));

		// Chaotic flicker — multiple overlapping sine waves, full 0-100% range
		float flk = sin(TIME * 37.0 + fi * 5.0) * sin(TIME * 23.0 + fi * 11.0);
		flk = flk * 0.5 + 0.5; // 0..1
		flk *= step(0.3, sin(TIME * 61.0 + fi * 17.0)); // hard cuts to zero
		float intensity = (1.0 - ring_t * 0.4) * pulse_alive * flk;
		ring_boost += ring * intensity * arc_mask;
	}
	ring_boost = min(ring_boost, 6.0);

	// ── Geometric grid lines ──
	vec2 grid_offset = vec2(sin(TIME * drift_speed * 0.7) * 0.01, cos(TIME * drift_speed) * 0.01);
	vec2 grid_uv = (uv + grid_offset) * line_density;
	vec2 cell_id = floor(grid_uv);
	vec2 cell_f = fract(grid_uv);

	float cell_dist = length((cell_id + 0.5) / line_density - center);
	float base_activity = smoothstep(0.55, 0.03, cell_dist);
	float thin_chance = smoothstep(0.08, 0.45, cell_dist);
	float sparse_mask = step(thin_chance * 0.7, hash(cell_id + 200.0));
	float activity = base_activity * sparse_mask;
	activity *= smoothstep(0.0, 0.05, cell_dist - 0.03);

	float h_active = step(0.3, hash(cell_id)) * activity;
	float v_active = step(0.3, hash(cell_id + 77.0)) * activity;
	float near_rift = smoothstep(0.12, 0.03, cell_dist);
	h_active = max(h_active, near_rift);
	v_active = max(v_active, near_rift);

	float line_w = 0.041;
	float h_line = smoothstep(line_w, line_w * 0.12, abs(cell_f.y - 0.5)) * h_active;
	float v_line = smoothstep(line_w, line_w * 0.12, abs(cell_f.x - 0.5)) * v_active;
	float line_core = max(h_line, v_line);

	// Grid: very dim base, ring pulse CRANKS HDR
	float base_dim = 0.03;
	float ring_lit = ring_boost * pulse_hdr;
	col += line_color * line_core * (base_dim + ring_lit) * line_brightness * hdr_intensity * 0.15;

	// Nodes
	float at_int = smoothstep(0.1, 0.02, max(abs(cell_f.x - 0.5), abs(cell_f.y - 0.5)));
	float node_active = min(h_active, v_active);
	col += rift_color * at_int * node_active * (base_dim + ring_lit * 0.5) * hdr_intensity * 0.2;

	// Ring ambient wash
	float ambient_mask = smoothstep(0.0, 0.04, dist) * smoothstep(0.8, 0.05, dist);
	col += rift_color * ring_boost * hdr_intensity * 0.05 * ambient_mask;

	// ── Cloud haze ──
	if (cloud_intensity > 0.001) {
		vec2 neb_uv = uv * 3.5 + vec2(TIME * 0.015, TIME * 0.01);
		float neb = fbm(neb_uv) * fbm(neb_uv * 1.2 + 5.0);
		neb = smoothstep(0.1, 0.35, neb) * cloud_intensity;
		float near = smoothstep(0.45, 0.08, dist);
		col += rift_color * 0.35 * neb * near * hdr_intensity * 0.3;
	}

	// ── Stars ──
	for (int layer = 0; layer < 2; layer++) {
		float gs = (layer == 0) ? 90.0 : 140.0;
		float lo = float(layer) * 300.0;
		vec2 cell_s = floor(uv * vec2(gs, gs * 0.5));
		float h = hash(cell_s + lo);
		if (h > 0.94) {
			vec2 soff = vec2(hash(cell_s + lo + 111.0), hash(cell_s + lo + 222.0));
			vec2 sp = (cell_s + soff) / vec2(gs, gs * 0.5);
			float d_star = length((uv - sp) * vec2(ar, 1.0));
			float tw = 0.7 + 0.3 * sin(TIME * (1.0 + h * 3.0) + h * 6.28);
			float star = exp(-d_star * d_star / 0.000004) * tw;
			star *= smoothstep(0.03, 0.15, dist);
			col += vec3(0.7, 0.8, 1.0) * star * 1.5;
		}
	}

	COLOR = vec4(col, 1.0);
}
