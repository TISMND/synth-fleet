shader_type canvas_item;
// Rift Gate — Hybrid: metallic chrome annulus ring containing an organic
// energy rift (spiral vortex with lightning). Structural scaffolding on
// outside of ring. Rift bolts arc across the interior and occasionally
// escape beyond the gate.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 3.0;
uniform vec3 bg_color : source_color = vec3(0.01, 0.006, 0.02);
uniform vec3 chrome_dark : source_color = vec3(0.07, 0.08, 0.11);
uniform vec3 chrome_mid : source_color = vec3(0.24, 0.26, 0.32);
uniform vec3 chrome_bright : source_color = vec3(0.72, 0.78, 0.88);
uniform vec3 rift_color : source_color = vec3(0.85, 0.35, 1.0);
uniform vec3 core_color : source_color = vec3(1.0, 0.7, 1.0);
uniform vec3 bolt_color : source_color = vec3(1.0, 0.6, 1.0);
uniform vec3 warn_color : source_color = vec3(1.0, 0.85, 0.25);
uniform float ring_radius : hint_range(0.1, 0.35) = 0.2;
uniform float ring_thickness : hint_range(0.01, 0.1) = 0.035;
uniform float swirl_speed : hint_range(0.0, 1.5) = 0.55;
uniform float rift_intensity : hint_range(0.2, 3.0) = 1.3;
uniform float bolt_count : hint_range(2.0, 10.0) = 6.0;
uniform float bolt_brightness : hint_range(0.5, 8.0) = 3.5;
uniform float pulse_speed : hint_range(0.3, 4.0) = 1.2;
uniform float pulse_hdr : hint_range(1.0, 30.0) = 14.0;
uniform float gleam_speed : hint_range(0.0, 2.0) = 0.25;

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
	for (int i = 0; i < 4; i++) { v += a * vnoise(p); p *= 2.05; a *= 0.5; }
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

	float r_inner = ring_radius - ring_thickness * 0.5;
	float r_outer = ring_radius + ring_thickness * 0.5;

	// ══════════════════════════════════════════════
	// RIFT INTERIOR — spiral vortex with nebula fill
	// ══════════════════════════════════════════════
	if (dist < r_inner + 0.01) {
		float vr = r_inner;
		float swirl_a = angle - dist * 14.0 + TIME * swirl_speed;
		float arms = sin(swirl_a * 3.0) * 0.5 + 0.5;
		arms = pow(arms, 2.0);
		vec2 turb_uv = vec2(swirl_a * 0.5, dist * 7.0) + TIME * vec2(0.0, -0.1);
		float turb = fbm(turb_uv * 2.0) * 0.3;
		arms = clamp(arms + turb - 0.15, 0.0, 1.0);
		float arm_fade = smoothstep(vr * 1.0, vr * 0.2, dist) * smoothstep(0.0, vr * 0.3, dist);
		arms *= arm_fade;
		col += rift_color * arms * hdr_intensity * 0.55 * rift_intensity;

		// Nebula fill between arms
		float neb1 = fbm(d * 10.0 + TIME * vec2(0.02, 0.015));
		float neb2 = fbm(d * 15.0 + vec2(4.0, 7.0) - TIME * vec2(0.015, 0.01));
		float neb = neb1 * 0.6 + neb2 * 0.4;
		float neb_mask = smoothstep(vr * 1.1, vr * 0.15, dist);
		col += rift_color * neb * neb_mask * 0.45 * hdr_intensity * rift_intensity;

		// Hot core
		float core_glow = exp(-dist * 10.0 / vr);
		col += core_color * core_glow * hdr_intensity * 0.6;
		float core_tight = exp(-dist * 26.0 / vr);
		col += vec3(1.0, 0.95, 1.0) * core_tight * hdr_intensity * 0.55;
	}

	// ══════════════════════════════════════════════
	// LIGHTNING — bolts from rift crossing interior (some escape past ring)
	// ══════════════════════════════════════════════
	float lightning_val = 0.0;
	int bc = int(bolt_count);
	for (int bolt = 0; bolt < 10; bolt++) {
		if (bolt >= bc) break;
		float fb = float(bolt);

		float cycle_period = 1.8 + hash(vec2(fb, 77.0)) * 2.4;
		float cycle_phase = hash(vec2(fb, 66.0)) * cycle_period;
		float cycle_t = mod(TIME + cycle_phase, cycle_period);
		float shaft_duration = 0.4;
		float shaft_alive = smoothstep(shaft_duration, shaft_duration - 0.04, cycle_t)
		                   * smoothstep(0.0, 0.015, cycle_t);
		if (shaft_alive < 0.01) continue;
		float shaft_flash = shaft_alive * smoothstep(shaft_duration, 0.0, cycle_t);
		float strike_id = floor((TIME + cycle_phase) / cycle_period);

		// Start in rift, walk outward — possibly past the ring
		float start_ang = hash(vec2(fb, strike_id * 3.0)) * 6.2832;
		vec2 pos = vec2(cos(start_ang), sin(start_ang)) * r_inner * 0.3;
		float cur_angle = start_ang;
		// Chance to escape past the gate
		float escape_chance = hash(vec2(fb, strike_id * 5.0));
		float reach = (escape_chance > 0.65) ? 0.55 : r_inner * 0.95;

		for (int seg = 0; seg < 14; seg++) {
			float fs = float(seg);
			float seed = hash(vec2(fb * 13.0 + fs, strike_id * 7.0 + fs));
			float jog = (seed - 0.5) * 2.0;
			float jog_amount = (seg % 2 == 0) ? 0.25 : 0.7;
			cur_angle += jog * jog_amount;
			float outward_angle = atan(pos.y, pos.x);
			cur_angle = mix(cur_angle, outward_angle, 0.2);
			vec2 direction = vec2(cos(cur_angle), sin(cur_angle));
			float seg_len = 0.025 + seed * 0.045;
			vec2 next_pos = pos + direction * seg_len;
			if (length(next_pos) > reach) break;
			float sd = seg_dist(d, pos, next_pos);
			float core = smoothstep(0.004, 0.001, sd);
			float glow = exp(-sd * sd / 0.00008);
			float range_fade = smoothstep(0.55, 0.02, length(pos));
			// Attenuate when crossing the ring
			float ring_cross_fade = 1.0;
			float seg_mid_dist = length((pos + next_pos) * 0.5);
			if (seg_mid_dist > r_inner && seg_mid_dist < r_outer) {
				ring_cross_fade = 0.25;
			}
			lightning_val += (core + glow * 0.3) * range_fade * shaft_flash * ring_cross_fade;
			pos = next_pos;
		}
	}
	lightning_val = min(lightning_val, 5.0);
	col += bolt_color * lightning_val * bolt_brightness * hdr_intensity * 0.55;

	// ══════════════════════════════════════════════
	// ACTIVATION PULSE — radial shockwave ring expanding from gate
	// ══════════════════════════════════════════════
	float ring_boost = 0.0;
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		float period = 2.2 + hash(vec2(fi, 11.0)) * 1.5;
		float phase = hash(vec2(fi, 22.0)) * period;
		float ct = mod(TIME + phase, period);
		float window = period * 0.35;
		float alive = smoothstep(window, window - 0.03, ct) * smoothstep(0.0, 0.04, ct);
		if (alive < 0.01) continue;
		float t_norm = ct / window;
		float wave_radius = ring_radius + t_norm * 0.45;
		float wave_match = abs(dist - wave_radius);
		float pw = 0.02;
		float ring_v = exp(-wave_match * wave_match / (pw * pw));
		float intensity = (1.0 - t_norm) * alive;
		ring_boost += ring_v * intensity;
	}
	ring_boost = min(ring_boost, 5.0);
	col += core_color * ring_boost * pulse_hdr * hdr_intensity * 0.025;

	// ══════════════════════════════════════════════
	// CHROME RING — the gate structure itself
	// ══════════════════════════════════════════════
	float ring_t = (dist - r_inner) / ring_thickness;
	if (ring_t >= 0.0 && ring_t <= 1.0) {
		float t_centered = (ring_t - 0.5) * 2.0;
		float chrome_base = 1.0 - t_centered * t_centered * 0.75;
		float static_band = exp(-pow((ring_t - 0.3) / 0.12, 2.0));
		float under_band = exp(-pow((ring_t - 0.78) / 0.08, 2.0)) * 0.5;

		vec3 chrome = mix(chrome_dark, chrome_mid, chrome_base);
		chrome = mix(chrome, chrome_bright, static_band * 0.6);
		chrome += chrome_bright * under_band * 0.3;

		// Rotating gleam
		float gleam_angle = TIME * gleam_speed;
		float ang_diff = abs(mod(angle - gleam_angle + 3.14159, 6.2832) - 3.14159);
		float gleam = exp(-ang_diff * ang_diff / 0.22) * static_band;
		chrome += chrome_bright * gleam * 1.1 * hdr_intensity;

		// Inner rim bleed — rift light catches the inside edge
		float inner_lit = exp(-pow(ring_t / 0.18, 2.0));
		chrome += rift_color * inner_lit * rift_intensity * 0.8 * hdr_intensity;

		// Rift pulse lights up the whole ring (activation)
		chrome += rift_color * ring_boost * pulse_hdr * 0.015 * hdr_intensity;

		// Rivets (two bands)
		float rivet_count = 56.0;
		float rivet_ang = angle * rivet_count / 6.2832;
		float rivet_f = fract(rivet_ang) - 0.5;
		float rivet_dist = abs(rivet_f) * 6.2832 * ring_radius / rivet_count;
		float rivet_r = 0.003;
		float rivet_dot = smoothstep(rivet_r, rivet_r * 0.3, rivet_dist);
		float rivet_b1 = exp(-pow((ring_t - 0.2) / 0.05, 2.0));
		float rivet_b2 = exp(-pow((ring_t - 0.8) / 0.05, 2.0));
		float rivet = rivet_dot * max(rivet_b1, rivet_b2);
		chrome = mix(chrome, chrome_dark * 0.3, rivet * 0.7);

		col = chrome;
	}

	// ══════════════════════════════════════════════
	// STRUCTURAL SCAFFOLDING — 4 anchor struts extending outward
	// ══════════════════════════════════════════════
	for (int st = 0; st < 4; st++) {
		float sa = float(st) * 1.5708 + 0.7854;
		vec2 strut_inner = vec2(cos(sa), sin(sa)) * r_outer;
		vec2 strut_outer = vec2(cos(sa), sin(sa)) * (r_outer + 0.08);
		float sdl = seg_dist(d, strut_inner, strut_outer);
		float strut_line = smoothstep(0.006, 0.002, sdl);
		col += chrome_mid * strut_line * hdr_intensity * 0.45;
		// Warning light at strut tip
		float tip_dist = length(d - strut_outer);
		float blink = 0.3 + 0.7 * pow(max(sin(TIME * 1.7 + float(st) * 0.9), 0.0), 4.0);
		col += warn_color * exp(-tip_dist * tip_dist / 0.00002) * blink * hdr_intensity * 2.5;
		col += warn_color * exp(-tip_dist * tip_dist / 0.0009) * blink * hdr_intensity * 0.3;
	}

	// ══════════════════════════════════════════════
	// NEBULA HAZE — rift color spills into surrounding space
	// ══════════════════════════════════════════════
	vec2 haze_uv = uv * 3.0 + vec2(TIME * 0.015, TIME * 0.01);
	float haze = fbm(haze_uv) * fbm(haze_uv * 1.4 + 5.0);
	float haze_mask = smoothstep(0.7, 0.1, dist) * smoothstep(r_outer + 0.02, r_outer + 0.12, dist);
	col += rift_color * haze * haze_mask * 0.18 * hdr_intensity;

	// ══════════════════════════════════════════════
	// STARS
	// ══════════════════════════════════════════════
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
			star *= smoothstep(r_outer + 0.01, r_outer + 0.06, dist);
			col += vec3(0.85, 0.8, 1.0) * star * 1.3;
		}
	}

	COLOR = vec4(col, 1.0);
}
