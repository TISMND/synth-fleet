shader_type canvas_item;
// Shipyard — Ship under construction inside scaffolding. Angled beam
// frame, floodlights at joints, welding sparks flashing at random points
// along the hull, and electric arc discharges between scaffolding nodes.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 3.0;
uniform vec3 bg_color : source_color = vec3(0.008, 0.01, 0.014);
uniform vec3 scaffold_color : source_color = vec3(0.35, 0.38, 0.44);
uniform vec3 hull_color : source_color = vec3(0.18, 0.2, 0.24);
uniform vec3 flood_color : source_color = vec3(1.0, 0.92, 0.7);
uniform vec3 spark_color : source_color = vec3(1.0, 0.75, 0.3);
uniform vec3 arc_color : source_color = vec3(0.6, 0.85, 1.0);
uniform float ship_w : hint_range(0.08, 0.3) = 0.16;
uniform float ship_h : hint_range(0.03, 0.2) = 0.08;
uniform float scaffold_gap : hint_range(0.01, 0.1) = 0.04;
uniform float spark_rate : hint_range(0.5, 6.0) = 2.8;

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

float sd_rrect(vec2 p, vec2 hs, float r) {
	vec2 q = abs(p) - hs + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
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
	vec2 cen = vec2(0.5, 0.5);
	vec2 d = vec2((uv.x - cen.x) * ar, uv.y - cen.y);
	vec3 col = bg_color;

	// ── Ship hull outline (horizontal elongated capsule with nose taper) ──
	// Body: rounded rect; nose: triangle bump on right; engines: notch on left
	vec2 ship_half = vec2(ship_w, ship_h);
	float ship_sd = sd_rrect(d, ship_half, ship_h * 0.8);

	// Nose taper — subtract a wedge from front
	// (Done by carving off right corners further)
	float right_tri = max(
		(d.x - ship_w * 0.75) * 1.0 + abs(d.y) * 1.3 - ship_h * 0.5,
		-(d.x - ship_w * 1.1)
	);
	ship_sd = max(ship_sd, -(-right_tri));
	// Simpler: keep rrect as-is

	bool in_hull = ship_sd < 0.0;

	// ══════════════════════════════════════════════
	// SCAFFOLDING — 8 beam frame around ship
	// ══════════════════════════════════════════════
	// Outer frame rect (larger than ship)
	vec2 frame_w = ship_half + vec2(scaffold_gap * 2.0, scaffold_gap * 2.0);
	// Define 4 frame corners
	vec2 fc_tl = vec2(-frame_w.x, -frame_w.y);
	vec2 fc_tr = vec2(frame_w.x, -frame_w.y);
	vec2 fc_bl = vec2(-frame_w.x, frame_w.y);
	vec2 fc_br = vec2(frame_w.x, frame_w.y);

	// Scaffolding beams: outer frame + diagonal cross braces to hull
	float beam_val = 0.0;
	float beam_w = 0.0022;
	// Top beam
	beam_val += smoothstep(beam_w, beam_w * 0.3, seg_dist(d, fc_tl, fc_tr));
	// Bottom beam
	beam_val += smoothstep(beam_w, beam_w * 0.3, seg_dist(d, fc_bl, fc_br));
	// Left beam
	beam_val += smoothstep(beam_w, beam_w * 0.3, seg_dist(d, fc_tl, fc_bl));
	// Right beam
	beam_val += smoothstep(beam_w, beam_w * 0.3, seg_dist(d, fc_tr, fc_br));

	// Diagonal cross braces from corners to ship hull edge (6 diagonals)
	vec2 ship_tl = vec2(-ship_w, -ship_h);
	vec2 ship_tr = vec2(ship_w, -ship_h);
	vec2 ship_bl = vec2(-ship_w, ship_h);
	vec2 ship_br = vec2(ship_w, ship_h);
	beam_val += smoothstep(beam_w, beam_w * 0.3, seg_dist(d, fc_tl, ship_tl)) * 0.9;
	beam_val += smoothstep(beam_w, beam_w * 0.3, seg_dist(d, fc_tr, ship_tr)) * 0.9;
	beam_val += smoothstep(beam_w, beam_w * 0.3, seg_dist(d, fc_bl, ship_bl)) * 0.9;
	beam_val += smoothstep(beam_w, beam_w * 0.3, seg_dist(d, fc_br, ship_br)) * 0.9;

	// Horizontal mid beams (extra detail)
	vec2 mid_l = vec2(-frame_w.x, 0.0);
	vec2 mid_r = vec2(frame_w.x, 0.0);
	vec2 ship_l = vec2(-ship_w, 0.0);
	vec2 ship_r = vec2(ship_w, 0.0);
	beam_val += smoothstep(beam_w * 0.8, beam_w * 0.2, seg_dist(d, mid_l, ship_l)) * 0.8;
	beam_val += smoothstep(beam_w * 0.8, beam_w * 0.2, seg_dist(d, mid_r, ship_r)) * 0.8;

	// Vertical support struts at quarter points along frame
	vec2 top_q1 = vec2(-frame_w.x * 0.5, -frame_w.y);
	vec2 bot_q1 = vec2(-frame_w.x * 0.5, frame_w.y);
	vec2 top_q2 = vec2(frame_w.x * 0.5, -frame_w.y);
	vec2 bot_q2 = vec2(frame_w.x * 0.5, frame_w.y);
	beam_val += smoothstep(beam_w * 0.7, beam_w * 0.2, seg_dist(d, top_q1, bot_q1)) * 0.6;
	beam_val += smoothstep(beam_w * 0.7, beam_w * 0.2, seg_dist(d, top_q2, bot_q2)) * 0.6;

	beam_val = clamp(beam_val, 0.0, 1.5);

	// Flood-lit scaffolding (front side brighter)
	float flood_lit = 0.5 + 0.5 * smoothstep(-ship_h, ship_h, -d.y);
	col += scaffold_color * beam_val * flood_lit * hdr_intensity * 0.5;

	// ── Ship hull fill ──
	if (in_hull) {
		// Base metal, slight gradient
		col = hull_color * (0.75 + 0.35 * smoothstep(ship_h, -ship_h, d.y));
		// Hull panel lines (horizontal)
		float panel = smoothstep(0.3, 0.25, fract(d.y * 70.0)) * smoothstep(0.7, 0.75, fract(d.y * 70.0));
		col *= (0.85 + panel * 0.2);
		// Vertical seam at midline
		float seam = smoothstep(0.002, 0.0, abs(d.x));
		col += scaffold_color * seam * 0.3;
		// Noise grime
		float grime = vnoise(d * 80.0);
		col *= (0.8 + grime * 0.4);
	}

	// Hull rim
	float rim_w = 0.0025;
	float rim = smoothstep(rim_w, rim_w * 0.2, abs(ship_sd));
	col += scaffold_color * rim * hdr_intensity * 0.5;

	// ══════════════════════════════════════════════
	// FLOODLIGHTS at scaffolding joints (4 corners + mid points)
	// ══════════════════════════════════════════════
	vec2 flood_pts[6] = vec2[6](
		fc_tl, fc_tr, fc_bl, fc_br, mid_l, mid_r
	);
	for (int f = 0; f < 6; f++) {
		float ff = float(f);
		vec2 fp = flood_pts[f];
		float fd = length(d - fp);
		float flick = 0.93 + 0.07 * sin(TIME * 4.0 + ff * 1.3);
		// Bright core
		col += flood_color * exp(-fd * fd / 0.00001) * flick * hdr_intensity * 3.5;
		// Wider halo
		col += flood_color * exp(-fd * fd / 0.0018) * flick * hdr_intensity * 0.25;
		// Soft cone aimed at hull center (fake volumetric)
		vec2 to_hull = normalize(-fp);
		vec2 from_fp = d - fp;
		float along = dot(from_fp, to_hull);
		if (along > 0.0 && along < 0.4) {
			vec2 perp_v = from_fp - to_hull * along;
			float perp_d = length(perp_v);
			float half_w = mix(0.003, 0.05, along / 0.4);
			float cone = smoothstep(half_w, half_w * 0.3, perp_d);
			cone *= 1.0 / (1.0 + along * along * 25.0);
			col += flood_color * cone * 0.18 * hdr_intensity * flick;
		}
	}

	// ══════════════════════════════════════════════
	// WELDING SPARKS — random points on hull flash briefly
	// ══════════════════════════════════════════════
	for (int sp = 0; sp < 5; sp++) {
		float fs = float(sp);
		float period = 0.4 + hash(vec2(fs, 7.0)) * 1.2;
		float phase = hash(vec2(fs, 11.0)) * period;
		float ct = mod(TIME * spark_rate * 0.3 + phase, period);
		float dur = 0.08 + hash(vec2(fs, 13.0)) * 0.12;
		float alive = smoothstep(dur, dur - 0.02, ct) * smoothstep(0.0, 0.01, ct);
		if (alive < 0.01) continue;
		float flash = alive * smoothstep(dur, 0.0, ct);
		float sid = floor((TIME * spark_rate * 0.3 + phase) / period);
		// Pick random point on hull (rough bounds)
		vec2 spark_pos = vec2(
			(hash(vec2(fs, sid * 3.0)) - 0.5) * 2.0 * ship_w * 0.95,
			(hash(vec2(fs, sid * 5.0)) - 0.5) * 2.0 * ship_h * 0.9
		);
		float wd = length(d - spark_pos);
		// Tight hot core
		col += vec3(1.0, 0.95, 0.85) * exp(-wd * wd / 0.000002) * flash * hdr_intensity * 6.0;
		// Orange halo
		col += spark_color * exp(-wd * wd / 0.0002) * flash * hdr_intensity * 1.5;
		// Wider glow
		col += spark_color * exp(-wd * wd / 0.003) * flash * hdr_intensity * 0.3;

		// Spark trails — 3 short streaks outward
		for (int tr = 0; tr < 3; tr++) {
			float ftr = float(tr);
			float trail_ang = hash(vec2(fs + ftr, sid * 7.0)) * 6.2832;
			vec2 trail_dir = vec2(cos(trail_ang), sin(trail_ang));
			float trail_len = 0.01 + hash(vec2(fs + ftr, sid * 11.0)) * 0.02;
			vec2 trail_end = spark_pos + trail_dir * trail_len;
			float sdv = seg_dist(d, spark_pos, trail_end);
			col += spark_color * smoothstep(0.0012, 0.0002, sdv) * flash * hdr_intensity * 1.5;
		}
	}

	// ══════════════════════════════════════════════
	// ELECTRIC ARCS between scaffolding nodes
	// ══════════════════════════════════════════════
	for (int a = 0; a < 3; a++) {
		float fa = float(a);
		float period = 2.0 + hash(vec2(fa, 51.0)) * 1.8;
		float phase = hash(vec2(fa, 53.0)) * period;
		float ct = mod(TIME + phase, period);
		float dur = 0.15;
		float alive = smoothstep(dur, dur - 0.02, ct) * smoothstep(0.0, 0.01, ct);
		if (alive < 0.01) continue;
		float flash = alive * smoothstep(dur, 0.0, ct);
		float sid = floor((TIME + phase) / period);
		// Pick two frame corners
		vec2 arc_pts[4] = vec2[4](fc_tl, fc_tr, fc_bl, fc_br);
		int ai = int(hash(vec2(fa, sid * 3.0)) * 4.0) % 4;
		int bi = int(hash(vec2(fa, sid * 7.0)) * 4.0) % 4;
		if (ai == bi) continue;
		vec2 pa = arc_pts[ai];
		vec2 pb = arc_pts[bi];
		vec2 pos = pa;
		vec2 dir = normalize(pb - pa);
		vec2 perp_dir = vec2(-dir.y, dir.x);
		float arc_val = 0.0;
		for (int s = 0; s < 4; s++) {
			float fsg = float(s);
			float tp = (fsg + 1.0) / 4.0;
			vec2 straight = mix(pa, pb, tp);
			float jit = (hash(vec2(fa * 9.0 + fsg, sid)) - 0.5) * 0.03;
			vec2 next_pos = straight + perp_dir * jit;
			float sdv = seg_dist(d, pos, next_pos);
			arc_val += smoothstep(0.003, 0.0005, sdv) + exp(-sdv * sdv / 0.00005) * 0.3;
			pos = next_pos;
		}
		col += arc_color * arc_val * flash * hdr_intensity * 0.5;
	}

	// ── Ambient hangar haze ──
	vec2 haze_uv = uv * 2.5 + vec2(TIME * 0.008, TIME * 0.005);
	float haze = vnoise(haze_uv) * vnoise(haze_uv * 1.5 + 3.0);
	float haze_mask = smoothstep(0.8, 0.1, length(d));
	col += flood_color * haze * haze_mask * 0.015 * hdr_intensity;

	// ── Distant stars outside scaffolding ──
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
			// Only outside scaffolding frame
			float outside_frame = step(frame_w.x + 0.02, max(abs(d.x), abs(d.y) * (frame_w.x / frame_w.y)));
			star *= outside_frame;
			col += vec3(0.8, 0.85, 1.0) * star * 1.2;
		}
	}

	COLOR = vec4(col, 1.0);
}
