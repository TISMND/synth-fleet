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
	float decay2 = decay * decay;

	// ── Spatial warping — horizontal stretch bands ──
	float warp_strength = decay2 * 0.25;
	float warp_slow = noise(vec2(floor(uv.y * 8.0), floor(t * 2.0)));
	float warp_fast = noise(vec2(floor(uv.y * 30.0), floor(t * 7.0)));
	float warp_mask = step(0.55 - decay * 0.3, warp_slow);
	float fine_warp = (warp_fast - 0.5) * warp_mask * warp_strength;
	float thick_band = noise(vec2(floor(uv.y * 5.0 + t * 0.5), floor(t * 1.5)));
	float thick_mask = step(0.75 - decay * 0.2, thick_band);
	float thick_warp = thick_mask * (noise(vec2(uv.y * 3.0, t * 4.0)) - 0.5) * decay * 0.12;
	vec2 warped_uv = vec2(uv.x + fine_warp + thick_warp, uv.y);

	// ── Flicker detection — hard cuts to static snow ──
	float flicker_fade = smoothstep(0.85, 0.65, decay);
	float cut_frequency = decay * 0.7 * flicker_fade;
	float cut_roll = hash(vec2(floor(t * 10.0), 7.0));
	float cut_hold = hash(vec2(floor(t * 10.0), 19.0));
	bool is_cut = cut_roll < cut_frequency && cut_hold < (0.4 + decay * 0.4);
	float sustained_roll = hash(vec2(floor(t * 2.0), 31.0));
	bool sustained_cut = decay > 0.5 && decay < 0.8 && sustained_roll < (decay - 0.4) * 0.9;
	bool flickering = is_cut || sustained_cut;

	// ── Static snow during flickers ──
	float snow_alpha = 0.0;
	float snow_brightness = 0.0;
	if (flickering) {
		float coarse = noise(warped_uv * 150.0 + vec2(t * 60.0, t * 35.0));
		float fine_n = hash(warped_uv * 600.0 + vec2(t * 200.0, 0.0));
		snow_brightness = mix(coarse, fine_n, 0.5) * 0.06 * (0.5 + decay * 0.5);
		snow_alpha = 0.7 + decay * 0.15;
	}

	// ── Scanlines — always present, stronger with decay ──
	// These show on the final dark screen too, giving it the "monitor on" look
	float scanline_raw = 0.5 + 0.5 * sin(uv.y * 800.0);
	float scanline_strength = 0.15 + decay * 0.35;  // Always at least 15%, up to 50%
	float scanline = scanline_raw * scanline_strength;

	// ── Distortion effects (between flickers) ──
	float pixel_noise = hash(warped_uv * 1000.0 + vec2(t * 100.0, 0.0));
	float noise_overlay = pixel_noise * decay2 * 0.25;
	float band = step(0.95 - decay * 0.35, noise(vec2(floor(warped_uv.y * 20.0), floor(t * 4.0))));
	float band_darken = band * decay * 0.8;
	float warp_edge = abs(fine_warp + thick_warp) * 10.0 * decay;
	float bar_pos = fract(t * (1.5 + decay * 2.0) * 0.1);
	float bar_dist = abs(fract(warped_uv.y - bar_pos) - 0.5);
	float bar_darken = (1.0 - smoothstep(0.0, 0.04 + decay * 0.1, bar_dist)) * decay * 0.5;
	vec2 vig_uv = uv * 2.0 - 1.0;
	float vig_darken = dot(vig_uv, vig_uv) * decay * 0.7;

	// ── Overall darkening — nearly black at death ──
	float base_darken = (1.0 - pow(power, 0.35)) * 0.99;

	// ── End state — push to full opacity ──
	float end_alpha_boost = 0.0;
	if (decay > 0.7) {
		float end_t = (decay - 0.7) / 0.3;
		end_alpha_boost = end_t * (1.0 - base_darken);
	}

	float normal_alpha = clamp(base_darken + end_alpha_boost + scanline + noise_overlay + band_darken + bar_darken + vig_darken + warp_edge, 0.0, 1.0);

	// ── Final output ──
	float final_alpha = mix(normal_alpha, snow_alpha, flickering ? 1.0 : 0.0);

	// Final brightness: nearly black with visible scanlines baked in
	// At death: base is 0.005, scanlines modulate it slightly so you see the lines
	float dead_screen = 0.005 + scanline_raw * 0.008 * decay;
	float final_brightness = flickering ? snow_brightness : dead_screen;

	COLOR = vec4(vec3(final_brightness), final_alpha);
}
