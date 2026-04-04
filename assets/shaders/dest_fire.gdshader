shader_type canvas_item;
// Fire Destination — Amorphous blob of solar plasma with lava veins.
// NOT a clean sphere — FBM-distorted boundary, billowing and organic.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 3.5;
uniform vec3 bg_color : source_color = vec3(0.02, 0.0, 0.0);
uniform vec3 lava_hot : source_color = vec3(1.0, 0.85, 0.3);
uniform vec3 lava_mid : source_color = vec3(1.0, 0.35, 0.05);
uniform vec3 lava_cool : source_color = vec3(0.5, 0.05, 0.0);
uniform vec3 crust_color : source_color = vec3(0.1, 0.03, 0.01);
uniform float base_radius : hint_range(0.05, 0.3) = 0.16;
uniform float blob_distort : hint_range(0.0, 0.15) = 0.06;
uniform float crack_width : hint_range(0.01, 0.2) = 0.09;
uniform float corona_size : hint_range(0.03, 0.25) = 0.12;
uniform float flare_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float surface_turb : hint_range(0.0, 1.0) = 0.5;
uniform float pulse_speed : hint_range(0.0, 2.0) = 0.7;

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
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 6; i++) { v += a * vnoise(p); p = rot * p * 2.1; a *= 0.48; }
	return v;
}

vec2 voronoi(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	float d1 = 8.0, d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 n = vec2(float(x), float(y));
			vec2 pt = vec2(hash(i + n), hash(i + n + 57.0));
			pt = 0.5 + 0.4 * sin(6.28 * pt + TIME * 0.15);
			float dd = length(n + pt - f);
			if (dd < d1) { d2 = d1; d1 = dd; }
			else if (dd < d2) { d2 = dd; }
		}
	}
	return vec2(d1, d2);
}

void fragment() {
	vec2 uv = UV;
	float ar = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 center = vec2(0.5, 0.48);
	vec2 d = vec2((uv.x - center.x) * ar, uv.y - center.y);
	float dist = length(d);
	float angle = atan(d.y, d.x);
	vec3 col = bg_color;

	// ── Distorted blob boundary (NOT a clean circle) ──
	// Use FBM at the current angle to warp the radius
	float angle_for_warp = angle + TIME * 0.08;
	float warp1 = fbm(vec2(angle_for_warp * 2.0, TIME * 0.15)) - 0.5;
	float warp2 = fbm(vec2(angle_for_warp * 3.5 + 10.0, TIME * 0.12 + 5.0)) - 0.5;
	float warp = (warp1 * 0.7 + warp2 * 0.3) * blob_distort;
	float effective_radius = base_radius + warp;

	// How deep inside the blob are we? 0 = edge, 1 = deep inside
	float blob_t = 1.0 - (dist / max(effective_radius, 0.01));
	float in_blob = smoothstep(-0.02, 0.04, blob_t);

	// Soft edge — not a hard cutoff
	float edge_softness = smoothstep(-0.03, 0.06, blob_t);

	// ══════════════════════════════════════════════
	// CORONA + PROMINENCES (behind and around blob)
	// ══════════════════════════════════════════════
	float corona_dist = max(dist - effective_radius, 0.0);
	float corona = exp(-corona_dist / corona_size);

	// Irregular corona using FBM — not uniform
	float corona_warp = fbm(vec2(angle * 3.0 + TIME * 0.2, dist * 8.0)) * 0.6 + 0.4;
	corona *= corona_warp;

	// Radial flare rays (also warped)
	float rays = 0.0;
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		float ray_a = fi * 1.257 + sin(TIME * 0.25 + fi * 2.0) * 0.4;
		float da = abs(mod(angle - ray_a + PI, 6.2832) - PI);
		float rw = 0.1 + fbm(vec2(fi * 3.0, TIME * 0.1)) * 0.08;
		rays += exp(-da * da / (rw * rw)) * exp(-corona_dist * 3.0);
	}
	rays *= flare_intensity;

	col += lava_cool * corona * hdr_intensity * 0.35;
	col += lava_mid * rays * hdr_intensity * 0.45;

	// Prominence arcs (organic, not perfectly symmetric)
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		float arc_a = fi * 1.571 + TIME * 0.06 + sin(TIME * 0.3 + fi) * 0.4;
		vec2 arc_dir = vec2(cos(arc_a), sin(arc_a));
		float along = dot(d, arc_dir);
		float perp = length(d - arc_dir * along);
		float arc_h = 0.05 + sin(TIME * 0.4 + fi * 2.3) * 0.03;
		float arc_peak = effective_radius + arc_h;
		if (along > effective_radius * 0.5 && along < arc_peak * 1.4) {
			float t = (along - effective_radius * 0.5) / (arc_peak * 1.4 - effective_radius * 0.5);
			float expected = sin(t * PI) * (0.02 + fi * 0.008);
			float ad = abs(perp - expected);
			float arc = exp(-ad * ad / 0.00004);
			arc *= smoothstep(0.0, 0.15, t) * smoothstep(1.0, 0.75, t);
			col += lava_mid * arc * flare_intensity * hdr_intensity * 0.35;
		}
	}

	// ══════════════════════════════════════════════
	// BLOB SURFACE — lava + solar turbulence
	// ══════════════════════════════════════════════
	if (in_blob > 0.01) {
		// UV coordinates that follow the blob's organic shape
		vec2 surf_uv = d / max(effective_radius, 0.01); // -1..1 ish

		// Voronoi lava cracks
		vec2 lava_uv = surf_uv * 4.5 + TIME * vec2(0.03, -0.02);
		vec2 vor = voronoi(lava_uv);
		float edge_v = vor.y - vor.x;
		float pulse = sin(TIME * pulse_speed + vor.x * 4.0) * 0.25 + 0.75;
		float crack = smoothstep(crack_width, crack_width * 0.08, edge_v) * pulse;
		float crack_glow = exp(-edge_v / (crack_width * 1.8)) * pulse;

		// Solar granulation
		vec2 gran_uv = surf_uv * 10.0 + TIME * 0.2;
		float gran = vnoise(gran_uv) * vnoise(gran_uv * 1.7 + 3.0);
		gran = smoothstep(0.1, 0.4, gran) * surface_turb;

		// Large-scale turbulence
		float turb_large = fbm(surf_uv * 3.0 + TIME * vec2(0.06, 0.03));

		// Color
		vec3 crack_col = mix(lava_mid, lava_hot, crack);
		vec3 plate_col = crust_color + lava_cool * turb_large * 0.35 + lava_mid * gran * 0.4;
		vec3 surface = mix(plate_col, crack_col, max(crack, crack_glow * 0.5));

		// Brighter toward center, darker at edges (organic limb darkening)
		float limb = smoothstep(-0.01, 0.3, blob_t);
		surface *= 0.3 + 0.7 * limb;

		surface *= hdr_intensity;
		col = mix(col, surface, edge_softness);
	}

	// ── Eruption hotspots (positioned by FBM, not on a circle) ──
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		float ea = fbm(vec2(fi * 3.0, TIME * 0.05)) * 6.28;
		float er = fbm(vec2(fi * 5.0 + 10.0, TIME * 0.04)) * base_radius * 0.7;
		vec2 ep = center + vec2(cos(ea) * er / ar, sin(ea) * er);
		float ed = length((uv - ep) * vec2(ar, 1.0));
		float flare_t = sin(TIME * (1.0 + fi * 0.4) + fi * 3.0) * 0.5 + 0.5;
		float flare = exp(-ed * ed / 0.0005) * flare_t;
		float inside = smoothstep(0.0, 0.02, blob_t);
		col += lava_hot * flare * hdr_intensity * 0.35 * inside;
	}

	// ── Background heat haze ──
	float bg_heat = exp(-dist * 2.5) * 0.08;
	col += lava_cool * bg_heat * hdr_intensity * 0.15;

	COLOR = vec4(col, 1.0);
}
