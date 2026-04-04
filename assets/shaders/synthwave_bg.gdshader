shader_type canvas_item;

// Grid-only layer. Planet/rings/sky/stars render in a separate SubViewport
// with isolated bloom so their HDR never mixes with grid HDR in post-process.

// ── Grid ──
uniform vec3 grid_color : source_color = vec3(1.0, 0.08, 0.52);
uniform float camera_height : hint_range(0.2, 3.0) = 1.2;
uniform float grid_freq : hint_range(0.5, 5.0) = 2.0;
uniform float grid_line_w : hint_range(0.001, 0.03) = 0.008;
uniform float grid_bloom_w : hint_range(0.01, 0.15) = 0.06;
uniform float grid_core_brightness : hint_range(0.5, 12.0) = 6.0;
uniform float grid_core_tint : hint_range(0.0, 1.0) = 0.0;
uniform float grid_bloom_brightness : hint_range(0.5, 8.0) = 3.0;
uniform float scroll_speed : hint_range(0.0, 2.0) = 0.5;

// ── Corridor ──
uniform float horizon : hint_range(0.3, 0.65) = 0.50;
uniform float corridor_gap : hint_range(0.02, 0.25) = 0.10;
uniform float grid_fade_width : hint_range(0.02, 0.4) = 0.18;

// ── Planet reflection (synced from planet shader) ──
uniform float planet_x : hint_range(0.35, 0.85) = 0.63;
uniform vec3 atmo_color : source_color = vec3(0.2, 0.6, 1.0);

// ── Motion lights ──
uniform float light_speed : hint_range(0.05, 2.0) = 0.5;
uniform float light_brightness : hint_range(0.0, 3.0) = 0.5;

vec2 calc_grid(vec2 uv_in, float v_dist, float ar_in) {
	float persp = camera_height / max(v_dist, 0.001);
	float wx = (uv_in.x - 0.5) * persp;
	float wz = persp + TIME * scroll_speed;

	float gx_w = wx * grid_freq;
	float gz_w = wz * grid_freq;
	float gx = abs(fract(gx_w) - 0.5);
	float gz = abs(fract(gz_w) - 0.5);
	float fwx = fwidth(gx_w);
	float fwz = fwidth(gz_w);

	float density_x = 1.0 / max(fwx * 2.0, 1.0);
	float density_z = 1.0 / max(fwz * 2.0, 1.0);

	float core_x = 1.0 - smoothstep(grid_line_w - fwx * 0.5, grid_line_w + fwx * 0.5, gx);
	float core_z = 1.0 - smoothstep(grid_line_w - fwz * 0.5, grid_line_w + fwz * 0.5, gz);
	float core = max(core_x * density_x, core_z * density_z);

	float bloom_x = 1.0 - smoothstep(grid_line_w, grid_bloom_w + fwx, gx);
	float bloom_z = 1.0 - smoothstep(grid_line_w, grid_bloom_w + fwz, gz);
	float bloom = max(bloom_x * density_x, bloom_z * density_z);

	float fade = smoothstep(corridor_gap, corridor_gap + grid_fade_width, v_dist);

	return vec2(core * fade, bloom * fade);
}

void fragment() {
	vec2 uv = UV;
	float ar = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;

	// Transparent base — planet SubViewport shows through
	vec3 col = vec3(0.0);
	float alpha = 0.0;

	vec3 core_col = mix(vec3(1.0, 0.9, 0.95), grid_color * 1.5, grid_core_tint);

	float v_bot = uv.y - horizon;
	if (v_bot > 0.0) {
		vec2 g = calc_grid(uv, v_bot, ar);
		vec3 contrib = grid_color * g.y * grid_bloom_brightness
					 + core_col * g.x * grid_core_brightness;
		col += contrib;
		alpha = max(alpha, max(g.x, g.y));
	}

	float v_top = horizon - uv.y;
	if (v_top > 0.0) {
		vec2 g = calc_grid(uv, v_top, ar);
		vec3 contrib = grid_color * g.y * grid_bloom_brightness
					 + core_col * g.x * grid_core_brightness;
		col += contrib;
		alpha = max(alpha, max(g.x, g.y));
	}

	// Horizon glow
	float edge_bot = max(v_bot - corridor_gap, 0.0);
	float edge_top = max(v_top - corridor_gap, 0.0);
	float h_glow_bot = exp(-edge_bot * 25.0) * smoothstep(0.0, 0.02, edge_bot) * 0.4;
	float h_glow_top = exp(-edge_top * 25.0) * smoothstep(0.0, 0.02, edge_top) * 0.4;
	vec3 h_glow = vec3(0.9, 0.15, 0.45) * (h_glow_bot + h_glow_top) * 3.0;
	col += h_glow;
	alpha = max(alpha, (h_glow_bot + h_glow_top) * 3.0);

	// Planet reflection on bottom grid
	if (v_bot > corridor_gap) {
		float refl_x = abs(uv.x - planet_x);
		float refl = exp(-refl_x * 6.0 * ar) * exp(-edge_bot * 8.0) * 0.35;
		col += atmo_color * refl * 2.0;
		alpha = max(alpha, refl * 2.0);
	}

	// Motion point lights
	for (int i = 0; i < 8; i++) {
		float fi = float(i);
		float hash_val = fract(sin(fi * 7.13 + 42.7) * 43758.5453);
		float lane = (hash_val - 0.2) * 5.0;
		float phase = fract(sin(fi * 3.31 + 99.1) * 43758.5453);
		float spd = light_speed * (0.35 + fract(sin(fi * 5.17 + 77.3) * 43758.5453) * 0.9);
		float cycle = fract(phase - TIME * spd * 0.08);
		float lz = 0.5 + cycle * 14.0;

		float pv = camera_height / lz;
		float px = 0.5 + lane / lz;

		float py_bot = horizon + corridor_gap + pv;
		if (py_bot < 1.0 && px > -0.05 && px < 1.05) {
			vec2 ld = vec2((uv.x - px) * ar, uv.y - py_bot);
			float d2 = length(ld);
			float sz = 0.005 + 0.018 / lz;
			float g_val = exp(-d2 / sz) * light_brightness / (1.0 + lz * 0.15);
			float fade_val = smoothstep(0.0, 0.05, py_bot - horizon - corridor_gap);
			col += grid_color * g_val * fade_val * 2.5;
			alpha = max(alpha, g_val * fade_val);
		}

		float py_top = horizon - corridor_gap - pv;
		if (py_top > 0.0 && px > -0.05 && px < 1.05) {
			vec2 ld = vec2((uv.x - px) * ar, uv.y - py_top);
			float d2 = length(ld);
			float sz = 0.005 + 0.018 / lz;
			float g_val = exp(-d2 / sz) * light_brightness / (1.0 + lz * 0.15);
			float fade_val = smoothstep(0.0, 0.05, horizon - corridor_gap - py_top);
			col += grid_color * g_val * fade_val * 2.5;
			alpha = max(alpha, g_val * fade_val);
		}
	}

	alpha = clamp(alpha, 0.0, 1.0);
	COLOR = vec4(col, alpha);
}
