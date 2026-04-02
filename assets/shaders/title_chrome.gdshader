shader_type canvas_item;
// Aggressive 80s chrome title shader.
// Multi-band metallic gradient, horizontal line texture, edge bevel,
// drop shadow, and animated gleam sweep.

// Chrome gradient bands — classic 80s pattern is dark-bright-dark-bright-dark
uniform vec4 chrome_color_top : source_color = vec4(0.08, 0.12, 0.18, 1.0);
uniform vec4 chrome_color_highlight1 : source_color = vec4(0.85, 0.9, 1.0, 1.0);
uniform vec4 chrome_color_mid : source_color = vec4(0.15, 0.2, 0.3, 1.0);
uniform vec4 chrome_color_highlight2 : source_color = vec4(0.6, 0.7, 0.9, 1.0);
uniform vec4 chrome_color_bottom : source_color = vec4(0.05, 0.08, 0.12, 1.0);

// Band positions (0=top, 1=bottom)
uniform float band1_pos : hint_range(0.0, 1.0) = 0.2;
uniform float band2_pos : hint_range(0.0, 1.0) = 0.45;
uniform float band3_pos : hint_range(0.0, 1.0) = 0.55;
uniform float band4_pos : hint_range(0.0, 1.0) = 0.8;
uniform float band_sharpness : hint_range(1.0, 40.0) = 12.0;

// Horizontal line texture
uniform float line_density : hint_range(0.0, 200.0) = 80.0;
uniform float line_strength : hint_range(0.0, 1.0) = 0.15;

// Edge bevel / outline
uniform float bevel_strength : hint_range(0.0, 2.0) = 0.8;
uniform float bevel_size : hint_range(0.5, 4.0) = 1.5;
uniform vec4 bevel_light_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 bevel_shadow_color : source_color = vec4(0.0, 0.0, 0.05, 1.0);

// Drop shadow
uniform float shadow_offset_x : hint_range(-8.0, 8.0) = 2.0;
uniform float shadow_offset_y : hint_range(-8.0, 8.0) = 3.0;
uniform float shadow_softness : hint_range(0.0, 8.0) = 2.0;
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.1, 0.8);

// Animated gleam sweep
uniform float gleam_enabled : hint_range(0.0, 1.0) = 1.0;
uniform float gleam_speed : hint_range(0.1, 4.0) = 0.8;
uniform float gleam_width : hint_range(0.02, 0.3) = 0.08;
uniform float gleam_intensity : hint_range(0.0, 3.0) = 1.5;
uniform float gleam_angle : hint_range(-1.0, 1.0) = 0.3;

// Overall
uniform float hdr_boost : hint_range(1.0, 4.0) = 1.2;

varying vec4 vert_color;

void vertex() {
	vert_color = COLOR;
}

void fragment() {
	vec2 ps = SCREEN_PIXEL_SIZE;
	vec4 tex = texture(TEXTURE, UV);
	float base_alpha = tex.a * vert_color.a;

	// ── Drop shadow ─────────────────────────────────────────────────
	float shadow_alpha = 0.0;
	if (shadow_softness > 0.01 || abs(shadow_offset_x) > 0.01 || abs(shadow_offset_y) > 0.01) {
		if (shadow_softness < 0.1) {
			vec2 shadow_uv = UV - vec2(shadow_offset_x, shadow_offset_y) * ps;
			shadow_alpha = texture(TEXTURE, shadow_uv).a;
		} else {
			float sw = 0.0;
			int r = int(ceil(shadow_softness));
			for (int y = -r; y <= r; y++) {
				for (int x = -r; x <= r; x++) {
					vec2 off = vec2(float(x) - shadow_offset_x, float(y) - shadow_offset_y) * ps;
					float s = texture(TEXTURE, UV + off).a;
					float d2 = float(x * x + y * y);
					float w = exp(-d2 / max(shadow_softness * shadow_softness * 0.5, 0.01));
					shadow_alpha += s * w;
					sw += w;
				}
			}
			shadow_alpha /= max(sw, 0.001);
		}
	}

	// ── Edge detection for bevel ────────────────────────────────────
	float edge_light = 0.0;
	float edge_dark = 0.0;
	if (bevel_strength > 0.01) {
		// Sample neighbors to detect edges
		float a_left  = texture(TEXTURE, UV + vec2(-bevel_size * ps.x, 0.0)).a;
		float a_right = texture(TEXTURE, UV + vec2( bevel_size * ps.x, 0.0)).a;
		float a_up    = texture(TEXTURE, UV + vec2(0.0, -bevel_size * ps.y)).a;
		float a_down  = texture(TEXTURE, UV + vec2(0.0,  bevel_size * ps.y)).a;

		// Light comes from top-left
		edge_light = clamp((base_alpha - a_right) + (base_alpha - a_down), 0.0, 1.0);
		edge_dark  = clamp((base_alpha - a_left) + (base_alpha - a_up), 0.0, 1.0);
		// Only on edges (where alpha gradient exists)
		float edge_mask = clamp(abs(a_left - a_right) + abs(a_up - a_down), 0.0, 1.0);
		edge_light *= edge_mask;
		edge_dark *= edge_mask;
	}

	// ── Multi-band chrome gradient ──────────────────────────────────
	float y = UV.y;
	vec3 chrome;
	if (y < band1_pos) {
		float t = clamp(y / max(band1_pos, 0.001), 0.0, 1.0);
		t = pow(t, 1.0 / max(band_sharpness * 0.3, 0.1));
		chrome = mix(chrome_color_top.rgb, chrome_color_highlight1.rgb, t);
	} else if (y < band2_pos) {
		float t = clamp((y - band1_pos) / max(band2_pos - band1_pos, 0.001), 0.0, 1.0);
		t = pow(t, max(band_sharpness * 0.1, 0.1));
		chrome = mix(chrome_color_highlight1.rgb, chrome_color_mid.rgb, t);
	} else if (y < band3_pos) {
		float t = clamp((y - band2_pos) / max(band3_pos - band2_pos, 0.001), 0.0, 1.0);
		chrome = mix(chrome_color_mid.rgb, chrome_color_highlight2.rgb, t);
	} else if (y < band4_pos) {
		float t = clamp((y - band3_pos) / max(band4_pos - band3_pos, 0.001), 0.0, 1.0);
		t = pow(t, max(band_sharpness * 0.1, 0.1));
		chrome = mix(chrome_color_highlight2.rgb, chrome_color_bottom.rgb, t);
	} else {
		float t = clamp((y - band4_pos) / max(1.0 - band4_pos, 0.001), 0.0, 1.0);
		chrome = mix(chrome_color_bottom.rgb, chrome_color_top.rgb * 0.5, t);
	}

	// ── Horizontal line texture ─────────────────────────────────────
	if (line_density > 0.01 && line_strength > 0.001) {
		float lines = sin(y * line_density * 3.14159 * 2.0) * 0.5 + 0.5;
		// Hard contrast: darken troughs, brighten peaks
		chrome *= mix(1.0 - line_strength, 1.0 + line_strength * 0.6, lines);
	}

	// ── Apply bevel ─────────────────────────────────────────────────
	chrome += bevel_light_color.rgb * edge_light * bevel_strength;
	chrome -= bevel_shadow_color.rgb * edge_dark * bevel_strength * 0.5;
	chrome = max(chrome, vec3(0.0));

	// ── Animated gleam sweep ────────────────────────────────────────
	// Smooth roll from left to right, then long pause before next sweep.
	// gleam_speed controls sweep duration; pause is 2x the sweep time.
	if (gleam_enabled > 0.5) {
		float cycle = fract(TIME * gleam_speed);
		// Sweep occupies first 1/3 of cycle, pause for remaining 2/3
		float sweep_t = clamp(cycle * 3.0, 0.0, 1.0);
		// Smooth ease in/out
		sweep_t = sweep_t * sweep_t * (3.0 - 2.0 * sweep_t);
		float sweep_pos = mix(-0.2, 1.2, sweep_t);
		float gleam_x = UV.x + UV.y * gleam_angle;
		float gleam = exp(-pow((gleam_x - sweep_pos) / max(gleam_width, 0.001), 2.0));
		// Fade out gleam during pause (cycle > 0.333)
		float active = 1.0 - smoothstep(0.3, 0.4, cycle);
		chrome += vec3(gleam * gleam_intensity * active);
	}

	// ── HDR boost ───────────────────────────────────────────────────
	chrome *= hdr_boost;

	// ── Composite: shadow behind, chrome text on top ────────────────
	vec3 final_col = shadow_color.rgb * shadow_alpha * shadow_color.a;
	float final_alpha = shadow_alpha * shadow_color.a;

	// Blend chrome text on top
	final_col = mix(final_col, chrome, base_alpha);
	final_alpha = clamp(final_alpha + base_alpha, 0.0, 1.0);

	COLOR = vec4(final_col, final_alpha);
}
