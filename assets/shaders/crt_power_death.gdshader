shader_type canvas_item;

// Single "power" uniform drives the entire effect. 1.0 = normal, 0.0 = dead.
// Alpha-blended overlay — game shows through where alpha is low.
uniform float power : hint_range(0.0, 1.0) = 1.0;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	float t = TIME;
	vec2 uv = UV;
	float decay = 1.0 - power;

	// ── Spatial warping — horizontal stretch bands that distort the overlay ──
	// Bands of UV displacement that grow with decay
	float warp_strength = decay * decay * 0.15;
	float warp_band1 = noise(vec2(floor(uv.y * 12.0), floor(t * 3.0)));
	float warp_band2 = noise(vec2(floor(uv.y * 40.0), floor(t * 6.0)));
	// Only warp where band noise is high — creates isolated stretchy bars
	float warp_mask = step(0.7 - decay * 0.3, warp_band1);
	float fine_warp = (warp_band2 - 0.5) * warp_mask * warp_strength;
	vec2 warped_uv = vec2(uv.x + fine_warp, uv.y);

	// ── Hard blackout cuts — screen goes black for random frames ──
	float cut_frequency = decay * 0.6;
	float cut_roll = hash(vec2(floor(t * 10.0), 7.0));
	float cut_hold = hash(vec2(floor(t * 10.0), 19.0));
	bool is_cut = cut_roll < cut_frequency && cut_hold < (0.3 + decay * 0.5);
	float sustained_roll = hash(vec2(floor(t * 2.0), 31.0));
	bool sustained_cut = decay > 0.6 && sustained_roll < (decay - 0.5) * 0.8;

	float cut_alpha = 0.0;
	float cut_brightness = 0.0;
	if (is_cut || sustained_cut) {
		float static_flash = hash(vec2(floor(t * 30.0), 53.0));
		if (static_flash < 0.15 * decay) {
			cut_brightness = hash(warped_uv * 800.0 + vec2(t * 200.0, 0.0)) * 0.15;
			cut_alpha = 0.9;
		} else {
			cut_alpha = 1.0;
		}
	}

	// ── Scanlines ──
	float scanline = decay * 0.4 * (0.5 + 0.5 * sin(warped_uv.y * 800.0));

	// ── Static noise — heavier at end, never fully gone ──
	float pixel_noise = hash(warped_uv * 1000.0 + vec2(t * 100.0, 0.0));
	float noise_overlay = pixel_noise * decay * decay * 0.3;

	// ── Horizontal glitch bands — dark streaks ──
	float band = step(0.97 - decay * 0.3, noise(vec2(floor(warped_uv.y * 20.0), floor(t * 4.0))));
	float band_darken = band * decay * 0.7;

	// ── Warp bar visual — bright edge along distortion boundaries ──
	float warp_edge = abs(fine_warp) * 8.0 * decay;

	// ── Rolling dark bar ──
	float bar_speed = 1.5 + decay * 2.0;
	float bar_pos = fract(t * bar_speed * 0.1);
	float bar_dist = abs(fract(warped_uv.y - bar_pos) - 0.5);
	float bar_width = 0.04 + decay * 0.08;
	float bar_darken = (1.0 - smoothstep(0.0, bar_width, bar_dist)) * decay * 0.4;

	// ── Vignette — edges darken first ──
	vec2 vig_uv = uv * 2.0 - 1.0;
	float vig_darken = dot(vig_uv, vig_uv) * decay * 0.6;

	// ── Overall darkening — ends at very dark + noise, not total black ──
	// At power=0: base_darken ~0.88, leaving ~12% for noise to show through
	float base_darken = (1.0 - pow(power, 0.4)) * 0.88;

	// ── End-state noise — when nearly dead, fill with heavy animated noise ──
	float end_noise = 0.0;
	if (decay > 0.8) {
		float end_amount = (decay - 0.8) * 5.0; // 0→1 over last 20% of decay
		float coarse_noise = noise(warped_uv * 200.0 + vec2(t * 50.0, t * 30.0));
		float fine_noise = hash(warped_uv * 600.0 + vec2(t * 150.0, 0.0));
		end_noise = mix(coarse_noise, fine_noise, 0.5) * end_amount * 0.12;
	}

	// ── Combine ──
	float normal_alpha = clamp(base_darken + scanline + noise_overlay + band_darken + bar_darken + vig_darken + warp_edge, 0.0, 1.0);
	float final_alpha = max(normal_alpha, cut_alpha);
	float final_brightness = max(cut_brightness, end_noise);

	COLOR = vec4(vec3(final_brightness), final_alpha);
}
