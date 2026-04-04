shader_type canvas_item;
// Fluid Rift — Spiral vortex + organic voronoi strand mesh (inspired by reef edge
// detection) + angular lightning + flickering geometric HDR pulses.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 3.0;
uniform vec3 bg_color : source_color = vec3(0.0, 0.01, 0.04);
uniform vec3 fluid_color : source_color = vec3(0.2, 0.6, 1.0);
uniform vec3 aurora_color : source_color = vec3(0.3, 0.85, 0.95);
uniform vec3 strand_color : source_color = vec3(0.1, 0.4, 0.8);
uniform vec3 bolt_color : source_color = vec3(0.4, 0.8, 1.0);
uniform float vortex_radius : hint_range(0.05, 0.3) = 0.18;
uniform float swirl_speed : hint_range(0.0, 1.0) = 0.3;
uniform float strand_scale : hint_range(3.0, 20.0) = 10.0;
uniform float strand_thickness : hint_range(0.01, 0.15) = 0.04;
uniform float strand_brightness : hint_range(0.2, 3.0) = 1.5;
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

vec2 hash22(vec2 p) {
	return vec2(hash(p), hash(p + 57.0));
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

// Voronoi returning (nearest_dist, second_nearest_dist)
vec2 voronoi(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	float d1 = 10.0, d2 = 10.0;
	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			vec2 n = vec2(float(x), float(y));
			vec2 pt = hash22(i + n);
			pt = 0.5 + 0.4 * sin(TIME * drift_speed + 6.2832 * pt);
			float dd = length(n + pt - f);
			if (dd < d1) { d2 = d1; d1 = dd; }
			else if (dd < d2) { d2 = dd; }
		}
	}
	return vec2(d1, d2);
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
	// Spiral vortex center
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

	// Nebula fill — FBM haze that fills gaps between spiral arms
	float nebula_fill = fbm(d * 8.0 + TIME * vec2(0.02, 0.015));
	float nebula_fill2 = fbm(d * 12.0 + vec2(5.0, 3.0) - TIME * vec2(0.015, 0.01));
	float neb = nebula_fill * 0.6 + nebula_fill2 * 0.4;
	float neb_mask = smoothstep(vortex_radius * 2.5, vortex_radius * 0.3, dist)
	              * smoothstep(vortex_radius * 0.08, vortex_radius * 0.25, dist);
	col += fluid_color * 0.4 * neb * neb_mask * hdr_intensity * 0.35;
	col += aurora_color * 0.2 * pow(neb, 2.0) * neb_mask * hdr_intensity * 0.2;

	// Bright core glow — wide and hot
	float core = exp(-dist * 8.0 / vortex_radius);
	col += aurora_color * core * hdr_intensity * 0.7;
	float core_tight = exp(-dist * 20.0 / vortex_radius);
	col += vec3(0.6, 0.95, 1.0) * core_tight * hdr_intensity * 0.5;

	// Dark eye (smaller now)
	float eye = smoothstep(vortex_radius * 0.1, vortex_radius * 0.03, dist);
	col = mix(col, bg_color * 0.4, eye * 0.4);

	// ── Tendrils from vortex ──
	int ttc = int(tendril_count);
	for (int i = 0; i < 10; i++) {
		if (i >= ttc) break;
		float fi = float(i);
		float t_angle = fi * 6.2832 / tendril_count + TIME * swirl_speed * 0.15;
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
	// LIGHTNING — organic angular bolts (not locked to 90°)
	// Sharp turns at varied angles, more natural than neon void's grid-locked paths.
	// ══════════════════════════════════════════════
	float lightning_val = 0.0;
	int bc = int(bolt_count);
	for (int bolt = 0; bolt < 10; bolt++) {
		if (bolt >= bc) break;
		float fb = float(bolt);

		float cycle_period = 2.0 + hash(vec2(fb, 77.0)) * 3.0;
		float cycle_phase = hash(vec2(fb, 66.0)) * cycle_period;
		float cycle_t = mod(TIME + cycle_phase, cycle_period);

		float shaft_duration = 0.5;
		float shaft_alive = smoothstep(shaft_duration, shaft_duration - 0.05, cycle_t)
		                   * smoothstep(0.0, 0.02, cycle_t);
		if (shaft_alive < 0.01) continue;

		float shaft_flash = shaft_alive * smoothstep(shaft_duration, 0.0, cycle_t);

		float strike_id = floor((TIME + cycle_phase) / cycle_period);
		float bolt_angle = fb * 6.2832 / bolt_count
		                 + hash(vec2(fb, strike_id * 3.0)) * 1.0 - 0.5
		                 + TIME * swirl_speed * 0.1;
		vec2 pos = vec2(cos(bolt_angle), sin(bolt_angle)) * vortex_radius * 0.8;
		// Current travel direction — starts outward, wanders organically
		float cur_angle = bolt_angle;

		for (int seg = 0; seg < 12; seg++) {
			float fs = float(seg);
			float seg_seed = hash(vec2(fb * 13.0 + fs, strike_id * 7.0 + fs));

			// Jog the angle: sharp turn of 30°-120° in random direction
			float jog = (seg_seed - 0.5) * 2.0; // -1..1
			// Bigger jog every other segment, small corrections between
			float jog_amount = (seg % 2 == 0) ? 0.3 : 0.8;
			cur_angle += jog * jog_amount;
			// Bias back toward outward to prevent bolts curling inward
			float outward_angle = atan(pos.y, pos.x);
			cur_angle = mix(cur_angle, outward_angle, 0.15);

			vec2 direction = vec2(cos(cur_angle), sin(cur_angle));
			float seg_len = 0.02 + seg_seed * 0.05;

			vec2 next_pos = pos + direction * seg_len;
			float sd = seg_dist(d, pos, next_pos);
			float s_core = smoothstep(0.004, 0.001, sd);
			float s_glow = exp(-sd * sd / 0.00008);
			float range_fade = smoothstep(0.5, 0.02, length(pos));

			lightning_val += (s_core * 1.0 + s_glow * 0.3) * range_fade * shaft_flash;

			// Branches — organic angles too
			float branch_chance = hash(vec2(fb * 5.0 + fs, strike_id + 100.0));
			if (branch_chance > 0.6) {
				float branch_delay = hash(vec2(fb * 9.0 + fs, strike_id + 200.0)) * 0.3;
				float branch_t = cycle_t - branch_delay;
				float branch_dur = 0.15;
				float branch_alive = smoothstep(branch_dur, branch_dur - 0.03, branch_t)
				                   * smoothstep(0.0, 0.01, branch_t);
				float branch_flash = branch_alive * smoothstep(branch_dur, 0.0, branch_t);

				if (branch_flash > 0.01) {
					// Branch forks off at a wide angle from current direction
					float fork_sign = (hash(vec2(fb + fs * 3.0, strike_id + 300.0)) > 0.5) ? 1.0 : -1.0;
					float branch_angle = cur_angle + fork_sign * (0.8 + hash(vec2(fb * 7.0, fs + strike_id)) * 0.8);
					vec2 bpos = (pos + next_pos) * 0.5;

					for (int bseg = 0; bseg < 5; bseg++) {
						float bfs = float(bseg);
						float bseed = hash(vec2(fb * 17.0 + fs * 3.0 + bfs, strike_id + bfs));
						// Wander the branch angle
						branch_angle += (bseed - 0.5) * 0.6;
						vec2 bdir = vec2(cos(branch_angle), sin(branch_angle));
						float blen = 0.008 + bseed * 0.018;
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
	// ORGANIC STRAND MESH — voronoi edge network (reef-inspired)
	// Replaces the rigid right-angle grid with organic branching strands.
	// ══════════════════════════════════════════════
	// Two scales of voronoi for large + fine strands
	vec2 mesh_uv = d * strand_scale;
	vec2 vor1 = voronoi(mesh_uv);
	vec2 vor2 = voronoi(mesh_uv * 1.7 + vec2(13.7, 7.3));

	float edge1 = vor1.y - vor1.x; // large cell boundaries
	float edge2 = vor2.y - vor2.x; // fine sub-structure

	// Strand from edge distance — thin bright lines at cell borders
	float strand1 = smoothstep(strand_thickness, strand_thickness * 0.1, edge1);
	float strand1_glow = exp(-edge1 / (strand_thickness * 3.0));
	float strand2 = smoothstep(strand_thickness * 0.6, strand_thickness * 0.06, edge2) * 0.4;
	float strand2_glow = exp(-edge2 / (strand_thickness * 2.0)) * 0.2;

	float strand_total = strand1 + strand2;
	float strand_glow_total = strand1_glow + strand2_glow;

	// Fade strands: present near vortex, sparser further out
	float strand_activity = smoothstep(0.55, 0.03, dist);
	strand_activity *= smoothstep(0.0, 0.06, dist - vortex_radius * 0.4);

	// ══════════════════════════════════════════════
	// HDR RAYS — radial flashes from center to edge, illuminating the mesh.
	// Each ray is a thin angular wedge that flashes on/off at random intervals.
	// ══════════════════════════════════════════════
	float ring_boost = 0.0;
	float pixel_angle = atan(d.y, d.x);
	int pc = int(pulse_count);
	for (int i = 0; i < 8; i++) {
		if (i >= pc) break;
		float fi = float(i);

		// Each ray has its own irregular flash cycle
		float period = 1.0 + hash(vec2(fi, 11.0)) * 2.5;
		float phase = hash(vec2(fi, 22.0)) * period;
		float cycle_t = mod(TIME + phase, period);

		// 80% off: ray flashes for first 20% of cycle
		float active_window = period * 0.05;
		float ray_alive = smoothstep(active_window, active_window - 0.02, cycle_t)
		                 * smoothstep(0.0, 0.01, cycle_t);
		if (ray_alive < 0.01) continue;

		// Ray angle — random each flash
		float flash_id = floor((TIME + phase) / period);
		float ray_angle = hash(vec2(fi * 3.0, flash_id * 7.0)) * 6.2832 - 3.14159;

		// Angular width — wider wedge with soft feathered edges
		float ray_half_width = 0.15 + hash(vec2(fi * 5.0, flash_id * 11.0)) * 0.2;

		float angle_diff = abs(mod(pixel_angle - ray_angle + 3.14159, 6.2832) - 3.14159);
		// Hard core in the center, soft gaussian feather on outer edges
		float core_mask = smoothstep(ray_half_width * 0.4, ray_half_width * 0.05, angle_diff);
		float feather = exp(-angle_diff * angle_diff / (ray_half_width * ray_half_width));
		float ray_mask = core_mask * 0.7 + feather * 0.3;
		if (ray_mask < 0.01) continue;

		// Fade along length: bright near center, reaches further out
		float radial_fade = smoothstep(0.85, 0.02, dist) * smoothstep(0.0, 0.04, dist);

		// Occasional flicker (less chaotic, more sustained)
		float flk = step(0.15, sin(TIME * 31.0 + fi * 11.0) * 0.5 + 0.5);

		float intensity = ray_alive * radial_fade * ray_mask * flk;
		ring_boost += intensity;
	}
	ring_boost = min(ring_boost, 8.0);

	// ── Strands lit by rays ──
	float base_dim = 0.03;
	float ring_lit = ring_boost * pulse_hdr * 1.5;
	float mesh_lit = base_dim + ring_lit;

	col += strand_color * strand_total * mesh_lit * strand_brightness * hdr_intensity * 0.15 * strand_activity;
	col += strand_color * strand_glow_total * mesh_lit * strand_brightness * hdr_intensity * 0.04 * strand_activity;

	// Strand intersection nodes (where both scales overlap = bright spots)
	float node_val = strand1 * strand2 * 4.0;
	col += aurora_color * node_val * (base_dim + ring_lit * 0.5) * hdr_intensity * 0.2 * strand_activity;

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
