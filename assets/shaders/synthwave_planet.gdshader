shader_type canvas_item;

// Planet + rings rendered in an isolated SubViewport so their HDR bloom
// never mixes with the grid's HDR bloom in the post-process pass.

// ── Sky (needed as backdrop behind planet) ──
uniform vec3 sky_top : source_color = vec3(0.01, 0.0, 0.06);
uniform vec3 sky_mid : source_color = vec3(0.08, 0.0, 0.14);
uniform vec3 sky_low : source_color = vec3(0.18, 0.02, 0.25);
uniform float horizon : hint_range(0.3, 0.65) = 0.50;

// ── Planet body ──
uniform float planet_x : hint_range(0.35, 0.85) = 0.63;
uniform float planet_radius : hint_range(0.03, 0.2) = 0.08;
uniform vec3 planet_color_top : source_color = vec3(1.0, 0.85, 0.3);
uniform vec3 planet_color_bot : source_color = vec3(0.9, 0.2, 0.08);
uniform float planet_hdr : hint_range(0.5, 4.0) = 1.5;

// ── Planet slices ──
uniform float slice_enabled : hint_range(0.0, 1.0) = 1.0;
uniform float slice_start : hint_range(0.1, 0.6) = 0.32;
uniform float slice_band_h : hint_range(0.02, 0.12) = 0.058;
uniform float slice_gap_base : hint_range(0.002, 0.03) = 0.005;
uniform float slice_gap_grow : hint_range(0.005, 0.04) = 0.015;

// ── Ring ──
uniform float ring_inner : hint_range(0.05, 0.5) = 0.10;
uniform float ring_outer : hint_range(0.1, 1.5) = 1.1;
uniform float ring_tilt : hint_range(0.05, 0.8) = 0.15;
uniform float ring_angle : hint_range(-0.8, 0.8) = 0.35;
uniform vec3 ring_color : source_color = vec3(0.1, 0.8, 1.0);
uniform float ring_hdr : hint_range(0.5, 6.0) = 2.5;
uniform float ring_hdr_back : hint_range(0.5, 6.0) = 1.25;
uniform float ring_band_width : hint_range(0.005, 0.08) = 0.018;
uniform float ring_gap_base : hint_range(0.002, 0.05) = 0.010;
uniform float ring_gap_grow : hint_range(0.0, 0.03) = 0.014;

// ── Planet tilt ──
uniform float planet_tilted : hint_range(0.0, 1.0) = 1.0;

// ── Atmosphere ──
uniform float atmo_glow : hint_range(0.0, 2.0) = 0.6;
uniform vec3 atmo_color : source_color = vec3(0.2, 0.6, 1.0);
uniform float ring_glow_size : hint_range(0.0, 0.03) = 0.008;

// ── Nebula ──
uniform vec3 accent_color : source_color = vec3(0.1, 0.8, 1.0);
uniform float nebula_intensity : hint_range(0.0, 0.5) = 0.12;
uniform float nebula_scale : hint_range(1.0, 8.0) = 3.5;
uniform float nebula_drift : hint_range(0.0, 0.1) = 0.015;

// ── Warp streaks ──
uniform vec3 warp_streak_color : source_color = vec3(0.1, 0.8, 1.0);
uniform float warp_streak_hdr : hint_range(0.5, 10.0) = 5.0;
uniform float warp_streak_intensity : hint_range(0.0, 2.0) = 0.5;
uniform float warp_streak_speed : hint_range(0.1, 5.0) = 1.0;
uniform float warp_streak_count : hint_range(4.0, 40.0) = 20.0;
uniform float warp_inner_radius : hint_range(0.05, 0.5) = 0.2;
uniform float warp_fade_width : hint_range(0.02, 0.3) = 0.1;
uniform float warp_max_length : hint_range(0.02, 0.4) = 0.12;
uniform float warp_streak_width : hint_range(0.0005, 0.006) = 0.0015;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += amp * value_noise(p);
		p *= 2.1;
		amp *= 0.45;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	float ar = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float planet_cy = horizon;

	// ── Sky gradient ──
	float dist_from_horizon = abs(uv.y - horizon) / max(horizon, 1.0 - horizon);
	float t = 1.0 - dist_from_horizon;
	vec3 col = (t > 0.5)
		? mix(sky_mid, sky_low, (t - 0.5) * 2.0)
		: mix(sky_top, sky_mid, t * 2.0);

	col += vec3(0.04, 0.0, 0.06) * smoothstep(0.3, 0.9, uv.x) * t;

	// ── Nebula wisps ──
	if (nebula_intensity > 0.001) {
		vec2 neb_uv = uv * nebula_scale + vec2(TIME * nebula_drift, TIME * nebula_drift * 0.6);
		float neb = fbm(neb_uv) * fbm(neb_uv * 1.4 + 5.3);
		neb = smoothstep(0.12, 0.45, neb) * nebula_intensity;
		neb *= smoothstep(0.05, 0.6, uv.x);
		neb *= smoothstep(0.0, 0.15, dist_from_horizon);
		col += accent_color * neb * 2.0;

		vec2 neb_uv2 = uv * nebula_scale * 0.7 + vec2(-TIME * nebula_drift * 0.8, TIME * nebula_drift * 0.3) + 20.0;
		float neb2 = fbm(neb_uv2) * fbm(neb_uv2 * 1.2 + 8.1);
		neb2 = smoothstep(0.18, 0.5, neb2) * nebula_intensity * 0.5;
		neb2 *= smoothstep(0.2, 0.8, uv.x);
		neb2 *= smoothstep(0.0, 0.2, dist_from_horizon);
		col += vec3(0.6, 0.1, 0.8) * neb2 * 1.5;
	}

	// ── Planet + rings ──
	vec2 pd = vec2((uv.x - planet_x) * ar, uv.y - planet_cy);
	float pdist = length(pd);
	bool on_planet = pdist < planet_radius;

	float ca = cos(ring_angle);
	float sa = sin(ring_angle);
	vec2 pd_rot = vec2(pd.x * ca - pd.y * sa, pd.x * sa + pd.y * ca);

	float rdist = length(vec2(pd_rot.x, pd_rot.y / ring_tilt));
	bool in_ring = rdist > ring_inner && rdist < ring_outer;
	// Soft front/back blend instead of hard boolean — SubViewport bloom can't
	// soften the boundary like root viewport bloom did in the original shader.
	float ring_front_blend = smoothstep(-0.015, 0.015, pd_rot.y);
	bool ring_front = pd_rot.y > 0.0;

	float ring_alpha = 0.0;
	if (in_ring) {
		float r_from_inner = rdist - ring_inner;
		ring_alpha = 1.0;
		float r_acc = 0.0;
		for (int i = 0; i < 25; i++) {
			r_acc += ring_band_width;
			float gap = ring_gap_base + float(i) * ring_gap_grow;
			if (r_from_inner >= r_acc && r_from_inner < r_acc + gap) {
				ring_alpha = 0.0;
				break;
			}
			r_acc += gap;
			if (r_acc > ring_outer - ring_inner) break;
		}
		ring_alpha *= smoothstep(ring_inner, ring_inner + 0.003, rdist);
		ring_alpha *= smoothstep(ring_outer, ring_outer - 0.003, rdist);
	}

	float ring_glow_val = 0.0;
	if (ring_glow_size > 0.001) {
		float di = abs(rdist - ring_inner);
		float do2 = abs(rdist - ring_outer);
		float closest = in_ring ? 0.0 : min(di, do2);
		ring_glow_val = exp(-closest / ring_glow_size) * 0.4;
		if (on_planet) { ring_glow_val *= 0.2; }
	}

	float grad_y = (planet_tilted > 0.5) ? pd_rot.y : pd.y;
	float ny = (grad_y + planet_radius) / (2.0 * planet_radius);

	float atmo = exp(-pdist * 5.5 / planet_radius) * atmo_glow;
	col += atmo_color * atmo;

	// Ring behind planet (blended by ring_front_blend)
	if (in_ring && !on_planet) {
		float back_amount = 1.0 - ring_front_blend;
		if (back_amount > 0.001) {
			col = mix(col, ring_color * ring_hdr_back, ring_alpha * back_amount);
		}
	}
	if (!on_planet) {
		float back_amount = 1.0 - ring_front_blend;
		col += ring_color * ring_glow_val * ring_hdr_back * back_amount;
	}

	if (on_planet) {
		vec3 pcol = mix(planet_color_top, planet_color_bot, clamp(ny, 0.0, 1.0));
		float shadow = smoothstep(-0.35, 0.45, -pd.x / planet_radius);
		shadow *= smoothstep(0.9, 0.3, ny);
		pcol *= 0.15 + 0.85 * shadow;

		if (slice_enabled > 0.5 && ny > slice_start) {
			float region = (ny - slice_start) / (1.0 - slice_start);
			float y_acc = 0.0;
			for (int i = 0; i < 9; i++) {
				float gap_h = slice_gap_base + float(i) * slice_gap_grow;
				y_acc += slice_band_h;
				if (region >= y_acc && region < y_acc + gap_h) {
					pcol = col;
					break;
				}
				y_acc += gap_h;
				if (y_acc > 1.0) break;
			}
		}

		float rim = smoothstep(0.5, 1.0, pdist / planet_radius);
		pcol += atmo_color * rim * atmo_glow;

		float edge = smoothstep(planet_radius, planet_radius - 0.003, pdist);
		col = mix(col, pcol * planet_hdr, edge);
	}

	// Ring in front of planet (blended by ring_front_blend)
	if (in_ring) {
		float front_alpha = ring_alpha * ring_front_blend;
		if (on_planet) { front_alpha *= 0.85; }
		col = mix(col, ring_color * ring_hdr, front_alpha);
	}
	if (!on_planet) {
		col += ring_color * ring_glow_val * ring_hdr * 0.5 * ring_front_blend;
	}

	// ── Warp streaks ──
	if (warp_streak_intensity > 0.01) {
		vec2 center = vec2(0.5, 0.5);
		vec2 to_center = vec2((uv.x - center.x) * ar, uv.y - center.y);
		float pixel_dist = length(to_center);
		float pixel_angle = atan(to_center.y, to_center.x);

		int streak_count = int(warp_streak_count);
		for (int i = 0; i < 40; i++) {
			if (i >= streak_count) break;
			float fi = float(i);
			float a = hash(vec2(fi, 44.4)) * 6.2832;

			float angle_diff = abs(mod(pixel_angle - a + 3.14159, 6.2832) - 3.14159);
			if (angle_diff > 0.06) { continue; }

			float period = 1.2 + hash(vec2(fi, 55.5)) * 2.0;
			float phase = hash(vec2(fi, 66.6));
			float spd = warp_streak_speed * (0.4 + hash(vec2(fi, 77.7)) * 0.8);
			float cycle = fract(TIME * spd / period + phase);

			float max_reach = 1.2;
			float head_d = warp_inner_radius + cycle * max_reach;
			float dist_ratio = (head_d - warp_inner_radius) / max_reach;
			float trail_len = warp_max_length * (0.15 + dist_ratio * 0.85);
			float tail_d = max(head_d - trail_len, warp_inner_radius);

			if (pixel_dist < tail_d || pixel_dist > head_d) { continue; }

			vec2 streak_dir = vec2(cos(a), sin(a));
			float perp = abs(to_center.x * streak_dir.y - to_center.y * streak_dir.x);

			float w = warp_streak_width + pixel_dist * 0.002;
			if (perp > w) { continue; }

			float along_t = (pixel_dist - tail_d) / max(head_d - tail_d, 0.001);
			float b2 = along_t;
			b2 *= smoothstep(w, w * 0.15, perp);
			b2 *= smoothstep(warp_inner_radius, warp_inner_radius + warp_fade_width, pixel_dist);
			b2 *= warp_streak_intensity;
			col += warp_streak_color * b2 * warp_streak_hdr;
		}
	}

	COLOR = vec4(col, 1.0);
}
