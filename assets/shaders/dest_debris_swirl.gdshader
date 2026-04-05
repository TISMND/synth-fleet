shader_type canvas_item;
// Debris Swirl — Manmade wreckage orbiting inside a glowing vortex.
// Central swirl/nebula (fluid-rift style), 10 tumbling chunks at various
// orbits, rim-lit by the vortex, with running lights and occasional arc
// discharges between chunks.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 3.0;
uniform vec3 bg_color : source_color = vec3(0.02, 0.005, 0.03);
uniform vec3 swirl_color : source_color = vec3(0.4, 0.75, 1.0);
uniform vec3 core_color : source_color = vec3(0.9, 0.95, 1.0);
uniform vec3 hull_color : source_color = vec3(0.14, 0.16, 0.20);
uniform vec3 rim_color : source_color = vec3(0.7, 0.9, 1.0);
uniform vec3 arc_color : source_color = vec3(0.6, 0.85, 1.0);
uniform float vortex_radius : hint_range(0.05, 0.25) = 0.12;
uniform float swirl_speed : hint_range(0.0, 1.5) = 0.45;
uniform float orbit_speed : hint_range(0.0, 0.8) = 0.18;
uniform float chunk_count : hint_range(4.0, 16.0) = 11.0;

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
	for (int i = 0; i < 4; i++) { v += a * vnoise(p); p *= 2.02; a *= 0.5; }
	return v;
}

float sd_rrect(vec2 p, vec2 hs, float r) {
	vec2 q = abs(p) - hs + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

vec2 rot(vec2 p, float a) {
	float c = cos(a), s = sin(a);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
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
	vec2 cen = vec2(0.5, 0.48);
	vec2 d = vec2((uv.x - cen.x) * ar, uv.y - cen.y);
	float dist = length(d);
	float angle = atan(d.y, d.x);
	vec3 col = bg_color;

	// ── Central vortex swirl ──
	float swirl_a = angle - dist * 12.0 + TIME * swirl_speed;
	float arms = sin(swirl_a * 3.0) * 0.5 + 0.5;
	arms = pow(arms, 2.0);
	float turb = fbm(vec2(swirl_a * 0.5, dist * 7.0) + TIME * vec2(0.0, -0.1)) * 0.3;
	arms = clamp(arms + turb - 0.12, 0.0, 1.0);
	float arm_fade = smoothstep(vortex_radius * 2.2, vortex_radius * 0.3, dist)
	               * smoothstep(vortex_radius * 0.08, vortex_radius * 0.3, dist);
	arms *= arm_fade;
	col += swirl_color * arms * hdr_intensity * 0.45;

	// Nebula fill
	float neb = fbm(d * 9.0 + TIME * vec2(0.02, 0.015)) * fbm(d * 13.0 + vec2(4.0, 7.0));
	float neb_mask = smoothstep(vortex_radius * 2.6, vortex_radius * 0.25, dist);
	col += swirl_color * neb * neb_mask * 0.4 * hdr_intensity;

	// Bright hot core
	float core = exp(-dist * 9.0 / vortex_radius);
	col += core_color * core * hdr_intensity * 0.55;
	float core_tight = exp(-dist * 24.0 / vortex_radius);
	col += vec3(0.9, 0.97, 1.0) * core_tight * hdr_intensity * 0.45;

	// Outer wash
	float outer_wash = smoothstep(0.8, 0.1, dist);
	col += swirl_color * outer_wash * 0.025 * hdr_intensity;

	// ══════════════════════════════════════════════
	// DEBRIS CHUNKS — rectangles on elliptical orbits
	// ══════════════════════════════════════════════
	int cc = int(chunk_count);
	// Collect chunk positions for arc discharges later
	vec2 chunk_pos[16];
	for (int ck = 0; ck < 16; ck++) chunk_pos[ck] = vec2(1000.0);

	for (int ck = 0; ck < 16; ck++) {
		if (ck >= cc) break;
		float fc = float(ck);
		float orbit_r = 0.16 + hash(vec2(fc, 3.0)) * 0.28;
		float orbit_phase_0 = hash(vec2(fc, 5.0)) * 6.2832;
		// Different orbital speeds per chunk
		float orbit_w = orbit_speed * (0.6 + hash(vec2(fc, 9.0)) * 1.0)
		              * (hash(vec2(fc, 11.0)) > 0.5 ? 1.0 : -1.0);
		float orbit_a = orbit_phase_0 + TIME * orbit_w;
		// Elliptical
		float ellipse_k = 0.6 + hash(vec2(fc, 13.0)) * 0.5;
		vec2 pos = vec2(cos(orbit_a) * orbit_r, sin(orbit_a) * orbit_r * ellipse_k);
		chunk_pos[ck] = pos;

		// Tumble rotation (independent)
		float tumble = TIME * (0.3 + hash(vec2(fc, 17.0)) * 1.2)
		             * (hash(vec2(fc, 19.0)) > 0.5 ? 1.0 : -1.0)
		             + hash(vec2(fc, 21.0)) * 6.2832;

		// Chunk size (irregular)
		vec2 hs = vec2(0.008 + hash(vec2(fc, 23.0)) * 0.014,
		               0.003 + hash(vec2(fc, 25.0)) * 0.007);

		vec2 local = rot(d - pos, -tumble);
		float csd = sd_rrect(local, hs, 0.0015);

		// Chip irregularity: subtract a smaller rectangle from an offset corner
		vec2 chip_off = vec2(hs.x * 0.4, hs.y * 0.5);
		float chip_sd = sd_rrect(local - chip_off, vec2(hs.x * 0.35, hs.y * 0.45), 0.001);
		csd = max(csd, -chip_sd);

		// Second nick on the opposite edge
		vec2 nick_off = vec2(-hs.x * 0.6, -hs.y * 0.3);
		float nick_sd = sd_rrect(local - nick_off, vec2(hs.x * 0.18, hs.y * 0.3), 0.001);
		csd = max(csd, -nick_sd);

		if (csd < 0.0) {
			// Hull shadow darker on side facing away from core
			vec2 to_core = normalize(-pos);
			float facing = dot(normalize(local), rot(to_core, -tumble)) * 0.5 + 0.5;
			col = hull_color * (0.55 + facing * 0.9);
			// Panel line detail on hull surface
			float panel = step(0.5, fract(local.x * 120.0));
			col *= (0.9 + panel * 0.15);
		}

		// Rim light from vortex
		float rim_w = 0.0014;
		float rim = smoothstep(rim_w, rim_w * 0.2, abs(csd));
		// Attenuate rim based on orientation toward core
		vec2 to_core_world = normalize(-pos);
		// Sample at the chunk surface outward
		float core_side = dot(normalize(d - pos + vec2(0.0001)), to_core_world);
		float rim_bright = 0.4 + 0.6 * max(core_side, 0.0);
		col += rim_color * rim * hdr_intensity * 0.35 * rim_bright;
		// Soft rim glow
		float rim_halo = exp(-abs(csd) * 600.0);
		col += rim_color * rim_halo * hdr_intensity * 0.1 * rim_bright;

		// Running light blinker on chunk
		vec2 light_off = rot(vec2(hs.x * 0.7, 0.0), tumble);
		vec2 light_pos = pos + light_off;
		float ld = length(d - light_pos);
		float blink = 0.3 + 0.7 * pow(max(sin(TIME * 2.3 + fc * 1.7), 0.0), 6.0);
		vec3 light_col = (hash(vec2(fc, 33.0)) > 0.5) ? vec3(1.0, 0.3, 0.25) : vec3(0.9, 0.95, 1.0);
		col += light_col * exp(-ld * ld / 0.0000055) * blink * hdr_intensity * 2.2;
		col += light_col * exp(-ld * ld / 0.00035) * blink * hdr_intensity * 0.25;
	}

	// ══════════════════════════════════════════════
	// ARC DISCHARGES between random chunk pairs
	// ══════════════════════════════════════════════
	for (int arc = 0; arc < 4; arc++) {
		float fa = float(arc);
		float period = 2.5 + hash(vec2(fa, 41.0)) * 2.0;
		float phase = hash(vec2(fa, 43.0)) * period;
		float ct = mod(TIME + phase, period);
		float dur = 0.22;
		float alive = smoothstep(dur, dur - 0.03, ct) * smoothstep(0.0, 0.02, ct);
		if (alive < 0.01) continue;
		float flash = alive * smoothstep(dur, 0.0, ct);
		float sid = floor((TIME + phase) / period);
		int a_idx = int(hash(vec2(fa, sid * 3.0)) * float(cc)) % cc;
		int b_idx = int(hash(vec2(fa, sid * 5.0)) * float(cc)) % cc;
		if (a_idx == b_idx) continue;
		vec2 pa = chunk_pos[a_idx];
		vec2 pb = chunk_pos[b_idx];
		if (distance(pa, pb) > 0.25) continue;
		// Walk 4 segments with jitter
		vec2 pos = pa;
		vec2 seg_dir = normalize(pb - pa);
		vec2 perp_dir = vec2(-seg_dir.y, seg_dir.x);
		float total = distance(pa, pb);
		float arc_val = 0.0;
		for (int s = 0; s < 5; s++) {
			float fs = float(s);
			float t_param = (fs + 1.0) / 5.0;
			vec2 straight = pa + seg_dir * (total * t_param);
			float jit = (hash(vec2(fa * 7.0 + fs, sid)) - 0.5) * 0.015;
			vec2 next_pos = straight + perp_dir * jit;
			float sdv = seg_dist(d, pos, next_pos);
			arc_val += smoothstep(0.003, 0.0008, sdv) + exp(-sdv * sdv / 0.00004) * 0.3;
			pos = next_pos;
		}
		col += arc_color * arc_val * flash * hdr_intensity * 0.55;
	}

	// ── Ambient haze ──
	vec2 haze_uv = uv * 3.0 + vec2(TIME * 0.014, TIME * 0.009);
	float haze = fbm(haze_uv) * fbm(haze_uv * 1.5 + 5.0);
	float haze_mask = smoothstep(0.7, 0.05, dist);
	col += swirl_color * haze * haze_mask * 0.08 * hdr_intensity;

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
			star *= smoothstep(vortex_radius * 0.5, vortex_radius * 2.5, dist);
			col += vec3(0.8, 0.85, 1.0) * star * 1.2;
		}
	}

	COLOR = vec4(col, 1.0);
}
