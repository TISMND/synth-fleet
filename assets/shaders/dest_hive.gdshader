shader_type canvas_item;
// Hive — Dense cluster of interconnected Apple-white cubes. Brutalist
// stacking, many small lit windows, connecting tubes between modules,
// breathing ambient glow, comm array at top, slow thruster plumes below.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 3.0;
uniform vec3 bg_color : source_color = vec3(0.005, 0.008, 0.016);
uniform vec3 hull_color : source_color = vec3(0.88, 0.92, 0.98);
uniform vec3 seam_color : source_color = vec3(0.4, 0.48, 0.6);
uniform vec3 window_color : source_color = vec3(0.55, 0.85, 1.0);
uniform vec3 warm_color : source_color = vec3(1.0, 0.85, 0.6);
uniform vec3 thruster_color : source_color = vec3(0.65, 0.9, 1.0);
uniform float hive_scale : hint_range(0.5, 2.0) = 1.0;
uniform float window_density : hint_range(0.0, 1.0) = 0.5;

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

float sd_rect(vec2 p, vec2 hs) {
	vec2 q = abs(p) - hs;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
}

float sd_rrect(vec2 p, vec2 hs, float r) {
	vec2 q = abs(p) - hs + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// Signed distance to a segment with thickness (capsule)
float sd_capsule(vec2 p, vec2 a, vec2 b, float r) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h) - r;
}

void fragment() {
	vec2 uv = UV;
	float ar = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 cen = vec2(0.5, 0.48);
	vec2 d = vec2((uv.x - cen.x) * ar, uv.y - cen.y) / hive_scale;
	vec3 col = bg_color;

	// ── Cubes: hardcoded arrangement for interesting composition ──
	const int N_CUBES = 9;
	vec2 cube_centers[9] = vec2[9](
		vec2(0.0, 0.0),
		vec2(-0.09, -0.06),
		vec2(0.08, -0.05),
		vec2(0.0, -0.12),
		vec2(-0.13, 0.04),
		vec2(0.12, 0.04),
		vec2(-0.05, 0.11),
		vec2(0.07, 0.12),
		vec2(0.18, -0.01)
	);
	vec2 cube_sizes[9] = vec2[9](
		vec2(0.055, 0.055),
		vec2(0.035, 0.04),
		vec2(0.04, 0.035),
		vec2(0.05, 0.03),
		vec2(0.03, 0.045),
		vec2(0.035, 0.035),
		vec2(0.042, 0.03),
		vec2(0.028, 0.035),
		vec2(0.03, 0.025)
	);

	// Combined silhouette SDF
	float hive_sd = 10.0;
	int which_cube = -1;
	vec2 cube_local = vec2(0.0);
	vec2 cube_hs = vec2(0.0);
	for (int i = 0; i < N_CUBES; i++) {
		float sdv = sd_rrect(d - cube_centers[i], cube_sizes[i], 0.003);
		if (sdv < hive_sd) {
			hive_sd = sdv;
			which_cube = i;
			cube_local = d - cube_centers[i];
			cube_hs = cube_sizes[i];
		}
	}

	// ── Connecting tubes between adjacent cubes ──
	float tube_sd = 10.0;
	// Explicit connections (8 tubes)
	int tube_pairs[16] = int[16](0,1, 0,2, 0,3, 0,4, 0,5, 0,6, 6,7, 2,8);
	for (int t = 0; t < 8; t++) {
		vec2 a = cube_centers[tube_pairs[t*2]];
		vec2 b = cube_centers[tube_pairs[t*2+1]];
		float ts = sd_capsule(d, a, b, 0.007);
		tube_sd = min(tube_sd, ts);
	}

	// Combined hull
	float combined_sd = min(hive_sd, tube_sd);
	bool in_hull = combined_sd < 0.0;

	// ── Outer aura ──
	float aura = exp(-max(combined_sd, 0.0) * 14.0);
	col += hull_color * aura * hdr_intensity * 0.07;
	float aura_wide = exp(-max(combined_sd, 0.0) * 3.0);
	col += window_color * aura_wide * hdr_intensity * 0.02;
	// Breathing pulse
	float breath = 0.85 + 0.15 * sin(TIME * 0.6);
	col *= (1.0 - 0.0) + aura_wide * breath * 0.02;

	// ── Hull interior ──
	if (in_hull) {
		col = hull_color * 0.85;

		// Cube-specific: vertical sheen + panel seams + windows
		if (which_cube >= 0 && hive_sd < tube_sd) {
			float sheen = 0.8 + 0.2 * smoothstep(cube_hs.y, -cube_hs.y, cube_local.y);
			col = hull_color * sheen;

			// Window grid per-cube (depends on size)
			float win_grid_x = floor(cube_hs.x * 140.0) * 2.0 + 3.0;
			float win_grid_y = floor(cube_hs.y * 140.0) * 2.0 + 3.0;
			vec2 win_uv = (cube_local + cube_hs) * vec2(win_grid_x, win_grid_y) / (cube_hs * 2.0);
			vec2 win_id = floor(win_uv);
			vec2 win_f = fract(win_uv);
			float win_dot = 1.0
				- smoothstep(0.28, 0.15, min(win_f.x, 1.0 - win_f.x))
				- smoothstep(0.28, 0.15, min(win_f.y, 1.0 - win_f.y));
			win_dot = clamp(win_dot, 0.0, 1.0);
			float wh = hash(win_id + float(which_cube) * 7.3);
			float win_lit = step(1.0 - window_density, wh);
			// Mix cool and warm windows
			vec3 win_col = (wh > 0.6) ? warm_color : window_color;
			float wflick = 0.75 + 0.25 * sin(TIME * (0.4 + wh * 2.0) + wh * 14.0);
			wflick *= step(0.1, wh + sin(TIME * 0.2 + wh * 20.0) * 0.5 + 0.5);
			float inner_fade = smoothstep(-0.001, -0.006, hive_sd);
			col += win_col * win_dot * win_lit * wflick * inner_fade * 0.28 * hdr_intensity;

			// Seam grid
			float seam_w = 0.12;
			float seam_x = smoothstep(seam_w, seam_w * 0.3, min(win_f.x, 1.0 - win_f.x));
			float seam_y = smoothstep(seam_w, seam_w * 0.3, min(win_f.y, 1.0 - win_f.y));
			float seam = max(seam_x, seam_y);
			col = mix(col, seam_color, seam * 0.18 * inner_fade);
		}

		// Tube interior: banded (ribbed)
		if (tube_sd < hive_sd) {
			col = hull_color * 0.7;
			float rib = sin(d.x * 120.0 + d.y * 80.0) * 0.5 + 0.5;
			col *= (0.85 + rib * 0.2);
		}
	}

	// Rim
	float rim_w = 0.0025;
	float rim = smoothstep(rim_w, rim_w * 0.2, abs(combined_sd));
	col += hull_color * rim * hdr_intensity * 0.5;
	float rim_glow = exp(-abs(combined_sd) * 250.0);
	col += hull_color * rim_glow * hdr_intensity * 0.2;

	// ── Comm array spires on top cube ──
	for (int s = 0; s < 4; s++) {
		float fs = float(s);
		float spx = (fs - 1.5) * 0.012;
		float sph = 0.025 + fs * 0.004;
		vec2 base_pt = vec2(spx, cube_centers[6].y - cube_sizes[6].y);
		vec2 tip_pt = vec2(spx, base_pt.y - sph);
		float t_clamp = clamp((d.y - tip_pt.y) / (base_pt.y - tip_pt.y), 0.0, 1.0);
		vec2 closest = mix(tip_pt, base_pt, t_clamp);
		float spd = length(d - closest);
		col += seam_color * smoothstep(0.0014, 0.0004, spd) * hdr_intensity * 0.5;
		float tip_dist = length(d - tip_pt);
		float tip_blink = 0.3 + 0.7 * pow(max(sin(TIME * 1.9 + fs * 1.5), 0.0), 4.0);
		col += window_color * exp(-tip_dist * tip_dist / 0.000008) * tip_blink * hdr_intensity * 2.2;
	}

	// ── Thruster glow below bottom cube ──
	vec2 thrust_center = vec2(0.0, cube_centers[3].y + cube_sizes[3].y + 0.02);
	float td = length(d - thrust_center);
	float thrust_flick = 0.85 + 0.15 * vnoise(vec2(TIME * 8.0, 0.0));
	col += thruster_color * exp(-td * td / 0.0004) * thrust_flick * hdr_intensity * 0.35;
	// Vertical plume
	vec2 plume_axis = d - thrust_center;
	if (plume_axis.y > 0.0) {
		float plume_d = abs(plume_axis.x);
		float plume_len = smoothstep(0.12, 0.0, plume_axis.y);
		float plume_width = mix(0.008, 0.025, plume_axis.y / 0.12);
		float plume = exp(-plume_d * plume_d / (plume_width * plume_width)) * plume_len;
		float noise_break = 0.6 + 0.4 * vnoise(vec2(plume_axis.y * 40.0, TIME * 4.0));
		col += thruster_color * plume * noise_break * hdr_intensity * 0.4;
	}

	// ── Drift haze ──
	vec2 haze_uv = uv * 3.2 + vec2(TIME * 0.01, TIME * 0.007);
	float haze = vnoise(haze_uv) * vnoise(haze_uv * 1.6 + 3.0);
	float haze_mask = smoothstep(0.6, 0.08, length(d));
	col += window_color * haze * haze_mask * 0.035 * hdr_intensity;

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
			star *= smoothstep(0.0, 0.04, combined_sd);
			col += vec3(0.85, 0.9, 1.0) * star * 1.3;
		}
	}

	COLOR = vec4(col, 1.0);
}
