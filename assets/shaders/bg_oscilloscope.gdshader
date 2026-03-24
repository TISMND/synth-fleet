shader_type canvas_item;
// Mid-layer scrolling background: stacked oscilloscope waveform lines.
// Uses relative wave positioning so waves work correctly with scrolling.

uniform vec4 bg_color : source_color = vec4(0.01, 0.02, 0.03, 1.0);
uniform vec4 wave_color : source_color = vec4(0.1, 0.9, 0.3, 0.9);
uniform vec4 wave_color_alt : source_color = vec4(0.2, 0.6, 1.0, 0.7);
uniform float scroll_speed : hint_range(0.0, 200.0) = 30.0;
uniform float wave_spacing : hint_range(15.0, 80.0) = 45.0;
uniform float wave_thickness : hint_range(0.5, 4.0) = 1.8;
uniform float amplitude : hint_range(0.0, 30.0) = 14.0;
uniform float glow_size : hint_range(0.0, 25.0) = 10.0;
uniform float phosphor_persist : hint_range(0.0, 1.0) = 0.4;

float hash_f(float p) {
	return fract(sin(p * 127.1 + 311.7) * 43758.5453);
}

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Each waveform line has unique shape from combined sine waves
float waveform(float x, float seed) {
	float freq1 = 0.015 + hash_f(seed) * 0.025;
	float freq2 = 0.04 + hash_f(seed + 1.0) * 0.035;
	float freq3 = 0.008 + hash_f(seed + 2.0) * 0.012;
	float phase1 = hash_f(seed + 3.0) * 6.28;
	float phase2 = hash_f(seed + 4.0) * 6.28;
	float phase3 = hash_f(seed + 5.0) * 6.28;
	float amp1 = 0.5 + hash_f(seed + 6.0) * 0.5;
	float amp2 = 0.2 + hash_f(seed + 7.0) * 0.3;
	float amp3 = 0.3 + hash_f(seed + 8.0) * 0.4;
	float t = TIME * (0.5 + hash_f(seed + 9.0) * 2.0);

	return amp1 * sin(x * freq1 + t + phase1)
		+ amp2 * sin(x * freq2 - t * 0.7 + phase2)
		+ amp3 * sin(x * freq3 + t * 0.3 + phase3);
}

void fragment() {
	vec2 uv = FRAGCOORD.xy;
	float y_scroll = -TIME * scroll_speed;
	vec2 pos = uv + vec2(0.0, y_scroll);

	vec3 col = bg_color.rgb;

	// Faint CRT scan lines (screen-space, don't scroll)
	float scan = 0.92 + 0.08 * sin(uv.y * 1.5);
	col *= scan;

	// Find nearest wave lines relative to scrolled position
	float center_wave = floor(pos.y / wave_spacing);
	vec3 glow_accum = vec3(0.0);

	// Check 7 nearest wave lines (enough to cover glow bleed)
	for (int offset = -3; offset <= 3; offset++) {
		float wave_idx = center_wave + float(offset);
		float line_y = wave_idx * wave_spacing + wave_spacing * 0.5;
		float seed = wave_idx * 17.31;

		// Wave displacement
		float wave_val = waveform(pos.x, seed) * amplitude;
		float wave_y = line_y + wave_val;
		float dist = abs(pos.y - wave_y);

		// Sharp core line
		float core = 1.0 - smoothstep(0.0, wave_thickness, dist);

		// Phosphor glow halo
		float glow = exp(-dist * dist / max(glow_size * glow_size, 0.001)) * 0.6;

		// Phosphor persistence trail (fades below the wave)
		float trail = pos.y - wave_y;
		float persist = 0.0;
		if (trail > 0.0 && trail < wave_spacing * 0.4) {
			persist = exp(-trail * 0.08) * phosphor_persist * 0.4;
		}

		// Alternate green/blue per wave
		float is_alt = step(0.5, hash_f(seed + 100.0));
		vec3 w_col = mix(wave_color.rgb, wave_color_alt.rgb, is_alt);

		// Intensity flicker per wave
		float flicker = 0.85 + 0.15 * sin(TIME * (1.5 + hash_f(seed + 50.0) * 2.0));

		float signal = (core + glow + persist) * flicker;
		glow_accum += w_col * signal;
	}

	col += glow_accum;

	// Graticule dots (oscilloscope measurement grid)
	float grat_sp_x = 80.0;
	float grat_sp_y = wave_spacing;
	vec2 grat_local = vec2(
		fract(pos.x / grat_sp_x) * grat_sp_x,
		fract(pos.y / grat_sp_y) * grat_sp_y
	);
	float grat_d = length(grat_local - vec2(grat_sp_x * 0.5, grat_sp_y * 0.5));
	float grat_dot = (1.0 - smoothstep(0.5, 1.8, grat_d)) * 0.12;

	// Axis tick marks along center
	float axis_x = fract(pos.x / grat_sp_x) * grat_sp_x;
	float tick_dist = abs(grat_local.y - grat_sp_y * 0.5);
	float tick = (1.0 - smoothstep(0.0, 0.8, tick_dist)) * (1.0 - smoothstep(0.0, 1.0, abs(axis_x - grat_sp_x * 0.5))) * 0.08;

	col += vec3(grat_dot + tick) * wave_color.rgb * 0.4;

	COLOR = vec4(col, 1.0);
}
