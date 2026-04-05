shader_type canvas_item;
// Chrome Ring — Massive metallic jump gate. Gaussian-highlight chrome annulus,
// rivets, rotating specular gleam, red warning lights at cardinals, angular
// energy arcs crossing the ring interior, small running lights on inner rim.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 3.0;
uniform vec3 bg_color : source_color = vec3(0.006, 0.008, 0.014);
uniform vec3 chrome_dark : source_color = vec3(0.08, 0.09, 0.12);
uniform vec3 chrome_mid : source_color = vec3(0.28, 0.30, 0.36);
uniform vec3 chrome_bright : source_color = vec3(0.78, 0.82, 0.92);
uniform vec3 rim_color : source_color = vec3(0.55, 0.85, 1.0);
uniform vec3 warn_color : source_color = vec3(1.0, 0.3, 0.2);
uniform vec3 arc_color : source_color = vec3(0.6, 0.9, 1.0);
uniform float ring_radius : hint_range(0.1, 0.35) = 0.24;
uniform float ring_thickness : hint_range(0.01, 0.15) = 0.065;
uniform float gleam_speed : hint_range(0.0, 2.0) = 0.35;
uniform float rivet_count : hint_range(12.0, 96.0) = 48.0;
uniform float arc_count : hint_range(1.0, 6.0) = 3.0;
uniform float arc_brightness : hint_range(0.5, 8.0) = 3.5;
uniform float running_count : hint_range(12.0, 120.0) = 64.0;
uniform float running_speed : hint_range(0.0, 3.0) = 0.8;

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

	// Radial position across ring thickness (0 inner → 1 outer)
	float ring_t = (dist - r_inner) / ring_thickness;

	// ══════════════════════════════════════════════
	// OUTER AURA AND BACKSCATTER
	// ══════════════════════════════════════════════
	float outside_dist = max(dist - r_outer, 0.0);
	float inside_dist = max(r_inner - dist, 0.0);
	float outer_aura = exp(-outside_dist * 18.0);
	col += rim_color * outer_aura * hdr_intensity * 0.05;

	// ══════════════════════════════════════════════
	// INSIDE THE RING: dim void with energy arcs
	// ══════════════════════════════════════════════
	if (dist < r_inner) {
		// Very dark interior with faint inner rim glow
		float inner_glow = exp(-inside_dist * 18.0);
		col += rim_color * inner_glow * hdr_intensity * 0.22;
		// Subtle volumetric swirl inside
		float swirl = sin(angle * 4.0 + TIME * 0.5 + dist * 18.0) * 0.5 + 0.5;
		col += rim_color * swirl * inner_glow * 0.08 * hdr_intensity;

		// ── Angular energy arcs crossing interior ──
		float arc_val = 0.0;
		int ac = int(arc_count);
		for (int a = 0; a < 6; a++) {
			if (a >= ac) break;
			float fa = float(a);
			float period = 1.5 + hash(vec2(fa, 13.0)) * 2.0;
			float phase = hash(vec2(fa, 27.0)) * period;
			float ct = mod(TIME + phase, period);
			float dur = 0.35;
			float alive = smoothstep(dur, dur - 0.04, ct) * smoothstep(0.0, 0.02, ct);
			if (alive < 0.01) continue;
			float flash = alive * smoothstep(dur, 0.0, ct);
			float sid = floor((TIME + phase) / period);

			// Pick two random points on the inner rim
			float ang_a = hash(vec2(fa, sid * 3.0)) * 6.2832;
			float ang_b = ang_a + 2.0 + hash(vec2(fa, sid * 5.0)) * 2.0;
			vec2 pos = vec2(cos(ang_a), sin(ang_a)) * r_inner * 0.98;
			vec2 target = vec2(cos(ang_b), sin(ang_b)) * r_inner * 0.98;

			// Walk in ~6 segments with jog
			vec2 dir = normalize(target - pos);
			vec2 perp_d = vec2(-dir.y, dir.x);
			for (int seg = 0; seg < 6; seg++) {
				float fs = float(seg);
				float seed = hash(vec2(fa * 11.0 + fs, sid * 7.0));
				float t_frac = (fs + 1.0) / 6.0;
				vec2 straight = mix(pos, target, 1.0 / (6.0 - fs));
				vec2 jitter = perp_d * (seed - 0.5) * 0.06;
				vec2 next_pos = straight + jitter;
				float sd = seg_dist(d, pos, next_pos);
				float core = smoothstep(0.0035, 0.001, sd);
				float glow = exp(-sd * sd / 0.00008);
				arc_val += (core + glow * 0.3) * flash;
				pos = next_pos;
			}
		}
		arc_val = min(arc_val, 5.0);
		col += arc_color * arc_val * arc_brightness * hdr_intensity * 0.55;
	}

	// ══════════════════════════════════════════════
	// CHROME RING — Gaussian highlight band, rotating gleam
	// ══════════════════════════════════════════════
	if (ring_t >= 0.0 && ring_t <= 1.0) {
		// Vertical chrome gradient across thickness: dark→bright→dark
		float t_centered = (ring_t - 0.5) * 2.0; // -1..1
		float chrome_base = 1.0 - t_centered * t_centered * 0.7;

		// Static highlight band at 30% of thickness (like text_chrome)
		float static_band = exp(-pow((ring_t - 0.3) / 0.13, 2.0));
		// Second lower band at 75% (under-lip)
		float under_band = exp(-pow((ring_t - 0.78) / 0.09, 2.0)) * 0.5;

		// Base chrome color ramp
		vec3 chrome = mix(chrome_dark, chrome_mid, chrome_base);
		chrome = mix(chrome, chrome_bright, static_band * 0.6);
		chrome += chrome_bright * under_band * 0.3;

		// Rotating specular gleam — bright spot that sweeps around angle
		float gleam_angle = TIME * gleam_speed;
		float ang_diff = abs(mod(angle - gleam_angle + 3.14159, 6.2832) - 3.14159);
		float gleam = exp(-ang_diff * ang_diff / 0.18) * static_band;
		chrome += chrome_bright * gleam * 1.2 * hdr_intensity;

		// Opposite gleam (softer)
		float gleam_angle2 = TIME * gleam_speed + 3.14159;
		float ang_diff2 = abs(mod(angle - gleam_angle2 + 3.14159, 6.2832) - 3.14159);
		float gleam2 = exp(-ang_diff2 * ang_diff2 / 0.35) * static_band;
		chrome += chrome_bright * gleam2 * 0.4 * hdr_intensity;

		// ── Rivet pattern (small circles at regular angular intervals) ──
		float rivet_ang = angle * rivet_count / 6.2832;
		float rivet_cell = floor(rivet_ang);
		float rivet_f = fract(rivet_ang) - 0.5;
		float angular_rivet_dist = abs(rivet_f) * 6.2832 * ring_radius / rivet_count;
		// Two rings of rivets: at ring_t 0.15 and 0.85
		float rivet_band1 = exp(-pow((ring_t - 0.15) / 0.04, 2.0));
		float rivet_band2 = exp(-pow((ring_t - 0.85) / 0.04, 2.0));
		float rivet_r = 0.004;
		float rivet_dot = smoothstep(rivet_r, rivet_r * 0.3, angular_rivet_dist);
		float rivet = rivet_dot * max(rivet_band1, rivet_band2);
		chrome = mix(chrome, chrome_dark * 0.3, rivet * 0.8);
		chrome += chrome_bright * rivet * 0.4;

		col = chrome;

		// ── Running lights along inner rim (just inside r_inner line) ──
		float run_band = exp(-pow((ring_t - 0.05) / 0.025, 2.0));
		float run_ang = angle * running_count / 6.2832 - TIME * running_speed;
		float run_f = fract(run_ang);
		float run_dot = smoothstep(0.12, 0.0, abs(run_f - 0.5));
		col += rim_color * run_dot * run_band * hdr_intensity * 0.7;
	}

	// ══════════════════════════════════════════════
	// CARDINAL WARNING LIGHTS (4 points on outer rim)
	// ══════════════════════════════════════════════
	for (int c = 0; c < 4; c++) {
		float ca = float(c) * 1.5708;
		vec2 cp = vec2(cos(ca), sin(ca)) * r_outer;
		float cd = length(d - cp);
		float phase = float(c) * 0.8;
		float blink = 0.3 + 0.7 * pow(max(sin(TIME * 1.9 + phase), 0.0), 4.0);
		float core = exp(-cd * cd / 0.00002);
		float halo = exp(-cd * cd / 0.0012);
		col += warn_color * core * blink * hdr_intensity * 3.0;
		col += warn_color * halo * blink * hdr_intensity * 0.4;
	}

	// ══════════════════════════════════════════════
	// STRUCTURAL SPOKES — 6 thin connectors extending outward
	// ══════════════════════════════════════════════
	float spoke_count = 6.0;
	float spoke_ang = angle * spoke_count / 6.2832;
	float spoke_f = abs(fract(spoke_ang) - 0.5);
	float spoke_mask = smoothstep(0.02, 0.0, spoke_f);
	float spoke_band = smoothstep(r_outer, r_outer + 0.04, dist) * smoothstep(r_outer + 0.07, r_outer + 0.02, dist);
	col += chrome_mid * spoke_mask * spoke_band * hdr_intensity * 0.4;

	// ══════════════════════════════════════════════
	// DRIFT HAZE — subtle cool nebula
	// ══════════════════════════════════════════════
	vec2 haze_uv = uv * 3.2 + vec2(TIME * 0.012, TIME * 0.008);
	float haze = vnoise(haze_uv) * vnoise(haze_uv * 1.6 + 5.0);
	float haze_mask = smoothstep(0.7, 0.05, dist) * smoothstep(r_outer + 0.03, r_outer + 0.15, dist);
	col += rim_color * haze * haze_mask * 0.08 * hdr_intensity;

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
			// Only show outside the ring
			star *= smoothstep(r_outer + 0.01, r_outer + 0.05, dist);
			col += vec3(0.8, 0.85, 1.0) * star * 1.3;
		}
	}

	COLOR = vec4(col, 1.0);
}
