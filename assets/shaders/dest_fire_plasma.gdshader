shader_type canvas_item;
// Fire Destination — Approach C: Radial plasma burst / solar flare.
// Central sun-like orb with coronal mass ejections and plasma arcs.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 4.0;
uniform vec3 bg_color : source_color = vec3(0.02, 0.0, 0.0);
uniform vec3 plasma_core : source_color = vec3(1.0, 0.95, 0.7);
uniform vec3 plasma_mid : source_color = vec3(1.0, 0.5, 0.08);
uniform vec3 plasma_outer : source_color = vec3(0.8, 0.12, 0.02);
uniform float sun_radius : hint_range(0.05, 0.25) = 0.12;
uniform float corona_size : hint_range(0.05, 0.3) = 0.15;
uniform float flare_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float surface_turb : hint_range(0.0, 1.0) = 0.6;
uniform float rotation_speed : hint_range(0.0, 1.0) = 0.2;

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
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = rot * p * 2.1;
		a *= 0.48;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	float ar = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 center = vec2(0.5, 0.48);
	vec2 d = vec2((uv.x - center.x) * ar, uv.y - center.y);
	float dist = length(d);
	float angle = atan(d.y, d.x);
	vec3 col = bg_color;

	// ── Corona (outer atmosphere) ──
	float corona_dist = max(dist - sun_radius, 0.0);
	float corona = exp(-corona_dist / corona_size);

	// Radial rays in corona
	float ray_angle = angle + TIME * rotation_speed * 0.3;
	float rays = 0.0;
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		float ray_a = fi * 1.2566 + sin(TIME * 0.3 + fi * 2.0) * 0.3;
		float da = abs(mod(ray_angle - ray_a + PI, 6.2832) - PI);
		float ray_width = 0.15 + sin(TIME * 0.5 + fi * 1.5) * 0.05;
		float ray = exp(-da * da / (ray_width * ray_width)) * exp(-corona_dist * 3.0);
		rays += ray;
	}
	rays *= flare_intensity;

	col += plasma_outer * corona * hdr_intensity * 0.4;
	col += plasma_mid * rays * hdr_intensity * 0.6;

	// ── Prominences / arcs ──
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float arc_a = fi * 2.094 + TIME * rotation_speed;
		float arc_spread = 0.4 + sin(TIME * 0.4 + fi * 3.0) * 0.1;

		// Arc shape: parabolic from surface
		vec2 arc_dir = vec2(cos(arc_a), sin(arc_a));
		float along = dot(d, arc_dir);
		float perp = length(d - arc_dir * along);

		float arc_height = 0.08 + sin(TIME * 0.6 + fi * 2.0) * 0.03;
		float arc_peak = sun_radius + arc_height;

		if (along > sun_radius * 0.7 && along < arc_peak * 1.3) {
			float t = (along - sun_radius * 0.7) / (arc_peak * 1.3 - sun_radius * 0.7);
			float expected_perp = sin(t * PI) * arc_spread * 0.04;
			float arc_dist = abs(perp - expected_perp);
			float arc = exp(-arc_dist * arc_dist / 0.00004);
			arc *= smoothstep(0.0, 0.2, t) * smoothstep(1.0, 0.8, t);
			col += plasma_mid * arc * flare_intensity * hdr_intensity * 0.5;
		}
	}

	// ── Sun surface ──
	if (dist < sun_radius * 1.1) {
		float sphere_t = dist / sun_radius;

		// Surface turbulence
		vec2 surf_uv = vec2(angle * 2.0 + TIME * rotation_speed, sphere_t * 5.0);
		float turb = fbm(surf_uv * 3.0 + TIME * vec2(0.1, 0.05));
		float turb2 = fbm(surf_uv * 5.0 - TIME * vec2(0.08, 0.03) + 7.0);
		float surface = turb * turb2 * surface_turb;

		// Granulation
		float gran = vnoise(vec2(angle * 15.0, sphere_t * 30.0) + TIME * 0.5);
		gran = smoothstep(0.3, 0.7, gran) * 0.2;

		// Color: hotter at center, cooler at edge
		vec3 surf_col = mix(plasma_core, plasma_mid, sphere_t * 0.8);
		surf_col += plasma_core * surface * 0.5;
		surf_col += plasma_core * gran;

		// Limb darkening
		float limb = sqrt(max(1.0 - sphere_t * sphere_t, 0.0));
		surf_col *= 0.4 + 0.6 * limb;

		// Edge softness
		float edge = smoothstep(sun_radius * 1.1, sun_radius * 0.95, dist);
		col = mix(col, surf_col * hdr_intensity, edge);
	}

	// ── Sunspots ──
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float sa = fi * 2.5 + TIME * rotation_speed * 0.5;
		float sr = 0.3 + hash(vec2(fi, 5.0)) * 0.4;
		vec2 sp = center + vec2(cos(sa), sin(sa)) * sun_radius * sr / vec2(ar, 1.0);
		float sd = length((uv - sp) * vec2(ar, 1.0));
		float spot_size = 0.008 + hash(vec2(fi, 6.0)) * 0.012;
		float spot = smoothstep(spot_size, spot_size * 0.3, sd);
		if (dist < sun_radius) {
			col *= 1.0 - spot * 0.5;
		}
	}

	// ── Background heat haze ──
	float bg_heat = exp(-dist * 2.5) * 0.1;
	col += plasma_outer * bg_heat * hdr_intensity * 0.15;

	COLOR = vec4(col, 1.0);
}
