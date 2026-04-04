shader_type canvas_item;
// Neon Void Rift — Approach B: Swirling circular portal with cloud vortex.
// Rotating energy ring with FBM cloud spiraling inward.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 3.5;
uniform vec3 bg_color : source_color = vec3(0.01, 0.0, 0.04);
uniform vec3 ring_color : source_color = vec3(1.0, 0.08, 0.5);
uniform vec3 cloud_color : source_color = vec3(0.8, 0.15, 0.55);
uniform vec3 inner_color : source_color = vec3(0.4, 0.0, 0.2);
uniform float portal_radius : hint_range(0.05, 0.35) = 0.18;
uniform float ring_width : hint_range(0.005, 0.06) = 0.015;
uniform float swirl_speed : hint_range(0.0, 2.0) = 0.4;
uniform float cloud_density : hint_range(0.0, 1.0) = 0.6;
uniform float ray_count : hint_range(2.0, 16.0) = 8.0;

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
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p *= 2.1;
		a *= 0.45;
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

	// ── Cloud vortex (spiraling around portal) ──
	float swirl_angle = angle - dist * 12.0 + TIME * swirl_speed;
	vec2 swirl_uv = vec2(swirl_angle * 0.5, dist * 6.0) + TIME * vec2(0.02, -0.08);
	float cloud = fbm(swirl_uv * 2.5);
	float cloud2 = fbm(swirl_uv * 3.2 + 7.3);
	float cloud_val = cloud * cloud2;
	cloud_val = smoothstep(0.08, 0.35, cloud_val) * cloud_density;

	// Fade clouds: strong near portal, fade outward
	float cloud_ring = smoothstep(portal_radius * 3.5, portal_radius * 0.8, dist);
	float cloud_outside = smoothstep(portal_radius * 0.5, portal_radius * 0.9, dist);
	cloud_val *= cloud_ring * cloud_outside;
	col += cloud_color * cloud_val * hdr_intensity * 0.7;

	// Deeper layer with different color
	vec2 swirl_uv2 = vec2(swirl_angle * 0.3 + 3.0, dist * 4.0) + TIME * vec2(-0.03, -0.05);
	float cloud3 = fbm(swirl_uv2 * 2.0) * fbm(swirl_uv2 * 1.5 + 11.0);
	cloud3 = smoothstep(0.1, 0.3, cloud3) * cloud_density * 0.5;
	cloud3 *= cloud_ring * cloud_outside;
	col += vec3(0.3, 0.05, 0.6) * cloud3 * hdr_intensity * 0.6;

	// ── Portal interior ──
	if (dist < portal_radius) {
		float inner_t = smoothstep(portal_radius, portal_radius * 0.15, dist);
		vec3 void_col = mix(inner_color * 0.3, vec3(0.005, 0.0, 0.01), inner_t);

		// Subtle inner spiral pattern
		float inner_swirl = sin(angle * 5.0 - TIME * 1.2 + dist * 25.0) * 0.5 + 0.5;
		inner_swirl *= smoothstep(0.0, portal_radius * 0.7, dist);
		void_col += ring_color * inner_swirl * 0.08 * hdr_intensity;

		col = void_col;
	}

	// ── Energy ring ──
	float ring_dist = abs(dist - portal_radius);
	float ring_core = smoothstep(ring_width, ring_width * 0.2, ring_dist);
	float ring_bloom = exp(-ring_dist / (ring_width * 3.0));

	// Pulsing segments along ring
	float seg = sin(angle * ray_count + TIME * 2.0) * 0.3 + 0.7;
	float seg2 = sin(angle * ray_count * 2.0 - TIME * 3.5) * 0.15 + 0.85;

	col += ring_color * ring_core * seg * hdr_intensity * 1.8;
	col += ring_color * ring_bloom * seg2 * hdr_intensity * 0.5;

	// ── Light rays emanating outward ──
	float ray_angle = mod(angle + TIME * 0.15, 6.2832);
	float ray = pow(max(sin(ray_angle * ray_count), 0.0), 8.0);
	float ray_fade = exp(-max(dist - portal_radius, 0.0) * 5.0);
	ray *= smoothstep(portal_radius * 0.8, portal_radius * 1.2, dist);
	col += ring_color * ray * ray_fade * hdr_intensity * 0.6;

	// ── Scattered grid fragments floating around ──
	for (int i = 0; i < 6; i++) {
		float fi = float(i);
		float ga = fi * 1.047 + TIME * 0.08 * (0.5 + hash(vec2(fi, 1.0)) * 0.5);
		float gr = portal_radius * (1.4 + hash(vec2(fi, 2.0)) * 1.2);
		vec2 gp = center / vec2(ar, 1.0) + vec2(cos(ga), sin(ga)) * gr / vec2(ar, 1.0);
		vec2 gd = (uv - gp) * vec2(ar, 1.0);

		// Rotate fragment
		float fa = ga * 0.5 + TIME * 0.3;
		float cs = cos(fa), sn = sin(fa);
		vec2 gd_r = vec2(gd.x * cs - gd.y * sn, gd.x * sn + gd.y * cs);

		float gx = abs(fract(gd_r.x * 30.0) - 0.5);
		float gy = abs(fract(gd_r.y * 30.0) - 0.5);
		float grid = max(smoothstep(0.06, 0.0, gx), smoothstep(0.06, 0.0, gy));
		float frag_mask = smoothstep(0.04, 0.02, length(gd));
		col += ring_color * grid * frag_mask * hdr_intensity * 0.3;
	}

	// ── Stars ──
	for (int layer = 0; layer < 2; layer++) {
		float gs = (layer == 0) ? 90.0 : 140.0;
		float lo = float(layer) * 300.0;
		vec2 cell = floor(uv * vec2(gs, gs * 0.5));
		float h = hash(cell + lo);
		if (h > 0.94) {
			vec2 soff = vec2(hash(cell + lo + 111.0), hash(cell + lo + 222.0));
			vec2 sp = (cell + soff) / vec2(gs, gs * 0.5);
			float d_star = length((uv - sp) * vec2(ar, 1.0));
			float tw = 0.7 + 0.3 * sin(TIME * (1.0 + h * 3.0) + h * 6.28);
			float star = exp(-d_star * d_star / 0.000004) * tw;
			star *= smoothstep(portal_radius * 0.5, portal_radius * 2.0, length(uv - center));
			col += vec3(0.7, 0.8, 1.0) * star * 1.5;
		}
	}

	COLOR = vec4(col, 1.0);
}
