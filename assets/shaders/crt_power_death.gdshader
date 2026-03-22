shader_type canvas_item;

// Single "power" uniform drives the entire effect. 1.0 = normal, 0.0 = dead.
// Alpha-blended black overlay — game shows through where alpha is low.
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
		// Full black with occasional static flash
		float static_flash = hash(vec2(floor(t * 30.0), 53.0));
		if (static_flash < 0.15 * decay) {
			cut_brightness = hash(uv * 800.0 + vec2(t * 200.0, 0.0)) * 0.15;
			cut_alpha = 0.9;
		} else {
			cut_alpha = 1.0;
		}
	}

	// ── Scanlines ──
	float scanline = decay * 0.4 * (0.5 + 0.5 * sin(uv.y * 800.0));

	// ── Static noise patches ──
	float pixel_noise = hash(uv * 1000.0 + vec2(t * 100.0, 0.0));
	float noise_overlay = pixel_noise * decay * decay * 0.3;

	// ── Horizontal glitch bands ──
	float band = step(0.97 - decay * 0.3, noise(vec2(floor(uv.y * 20.0), floor(t * 4.0))));
	float band_darken = band * decay * 0.7;

	// ── Rolling dark bar ──
	float bar_speed = 1.5 + decay * 2.0;
	float bar_pos = fract(t * bar_speed * 0.1);
	float bar_dist = abs(fract(uv.y - bar_pos) - 0.5);
	float bar_width = 0.04 + decay * 0.08;
	float bar_darken = (1.0 - smoothstep(0.0, bar_width, bar_dist)) * decay * 0.4;

	// ── Vignette — edges darken first ──
	vec2 vig_uv = uv * 2.0 - 1.0;
	float vig_darken = dot(vig_uv, vig_uv) * decay * 0.6;

	// ── Overall darkening ──
	float base_darken = (1.0 - pow(power, 0.5)) * 0.7;

	// ── Combine ──
	float normal_alpha = clamp(base_darken + scanline + noise_overlay + band_darken + bar_darken + vig_darken, 0.0, 1.0);

	// Hard cuts override normal effects
	float final_alpha = max(normal_alpha, cut_alpha);
	float final_brightness = cut_brightness;

	COLOR = vec4(vec3(final_brightness), final_alpha);
}
