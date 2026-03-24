shader_type canvas_item;
// Mid-layer scrolling background: synthwave neon pink grid etched by drawing heads.
// Lines have blown-out white HDR cores with color visible in the glow.
// Both head and tail have wide etcher blooms that mask the line endpoints.
// Sparkle is irregular (hash noise, not sine).

uniform vec4 bg_color : source_color = vec4(0.02, 0.0, 0.06, 1.0);
uniform vec4 grid_color : source_color = vec4(1.0, 0.1, 0.55, 0.8);
uniform vec4 head_color : source_color = vec4(1.0, 0.85, 0.95, 1.0);
uniform vec4 band_color_a : source_color = vec4(0.5, 0.0, 0.35, 0.12);
uniform vec4 band_color_b : source_color = vec4(0.15, 0.0, 0.25, 0.08);
uniform float scroll_speed : hint_range(0.0, 200.0) = 35.0;
uniform float grid_spacing : hint_range(20.0, 120.0) = 60.0;
uniform float line_width : hint_range(0.5, 4.0) = 1.2;
uniform float glow_size : hint_range(0.0, 30.0) = 12.0;
uniform float etch_speed : hint_range(10.0, 400.0) = 140.0;
uniform float etcher_size : hint_range(10.0, 80.0) = 35.0;
uniform float speed_variation : hint_range(0.0, 1.0) = 0.7;
uniform float line_length : hint_range(2000.0, 6000.0) = 3500.0;
uniform float dark_gap : hint_range(100.0, 1500.0) = 600.0;
uniform float core_intensity : hint_range(0.0, 4.0) = 2.5;
uniform bool manual_scroll = false;
uniform float scroll_offset : hint_range(0.0, 100000.0) = 0.0;

float hash_f(float p) {
	return fract(sin(p * 127.1 + 311.7) * 43758.5453);
}

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 pmod(vec2 x, float s) {
	return fract(x / s) * s;
}

// Irregular sparkle — hash-based noise, not periodic sine
float sparkle(float t, float seed) {
	float s = 0.0;
	// Layer multiple non-harmonic hash lookups at different rates
	s += hash_f(floor(t * 12.0 + seed) * 3.7) * 0.4;
	s += hash_f(floor(t * 7.3 + seed * 2.1) * 5.3) * 0.3;
	s += hash_f(floor(t * 19.0 + seed * 0.7) * 11.1) * 0.3;
	// Occasional bright flash (rare)
	float flash = step(0.92, hash_f(floor(t * 3.0 + seed * 4.3) * 17.7));
	s += flash * 0.5;
	return 0.4 + s * 0.8; // range ~0.4 to ~1.2+
}

void fragment() {
	vec2 uv = FRAGCOORD.xy;
	float y_scroll = manual_scroll ? -scroll_offset : -TIME * scroll_speed;
	vec2 pos = uv + vec2(0.0, y_scroll);

	// Subtle horizontal color bands (screen-space)
	float band = 0.5 + 0.5 * sin(uv.y * 0.003 * 6.28 + TIME * 0.15);
	vec3 band_col = mix(band_color_b.rgb, band_color_a.rgb, band);
	float band_alpha = mix(band_color_b.a, band_color_a.a, band);

	// Grid local coords
	vec2 local = pmod(pos, grid_spacing);
	float h_dist = min(local.y, grid_spacing - local.y);
	float v_dist = min(local.x, grid_spacing - local.x);

	// Line with HDR white core: core is blown-out white, color lives in the glow
	float h_core = 1.0 - smoothstep(0.0, line_width * 0.5, h_dist);
	float h_line_raw = 1.0 - smoothstep(0.0, line_width, h_dist);
	float v_core = 1.0 - smoothstep(0.0, line_width * 0.5, v_dist);
	float v_line_raw = 1.0 - smoothstep(0.0, line_width, v_dist);

	// ── Horizontal line etching — moving segment ──
	float h_row = round(pos.y / grid_spacing);
	float h_hash = hash_f(h_row * 7.31 + 0.5);
	float h_speed = etch_speed * (1.0 - speed_variation + h_hash * speed_variation * 2.0);
	float h_total = 1920.0 + line_length + dark_gap;
	float h_cycle = h_total / h_speed;
	float h_time = mod(TIME + h_hash * h_cycle * 5.3, h_cycle);
	float h_head_x = h_time * h_speed;
	float h_tail_x = h_head_x - line_length;

	// Wide soft transition at both endpoints (etcher covers the cutoff)
	float h_front = 1.0 - smoothstep(h_head_x - etcher_size, h_head_x, uv.x);
	float h_back = smoothstep(h_tail_x, h_tail_x + etcher_size, uv.x);
	float h_etch = h_front * h_back;

	// Head etcher bloom — wide enough to mask the line endpoint
	float h_head_dist = abs(uv.x - h_head_x);
	float h_near_line = exp(-h_dist * h_dist / 20.0);
	float h_head_visible = step(-80.0, h_head_x) * step(h_head_x, 2000.0);
	float h_sparkle_val = sparkle(TIME, h_hash * 100.0);
	float h_head_bloom = exp(-h_head_dist * h_head_dist / (etcher_size * etcher_size))
		* h_near_line * h_sparkle_val * h_head_visible;

	// Tail etcher bloom — same size, own sparkle
	float h_tail_dist = abs(uv.x - h_tail_x);
	float h_tail_visible = step(-80.0, h_tail_x) * step(h_tail_x, 2000.0);
	float h_tail_sparkle = sparkle(TIME, h_hash * 73.0 + 50.0);
	float h_tail_bloom = exp(-h_tail_dist * h_tail_dist / (etcher_size * etcher_size))
		* h_near_line * h_tail_sparkle * h_tail_visible;

	// ── Vertical line etching ──
	float v_col_idx = round(pos.x / grid_spacing);
	float v_hash = hash_f(v_col_idx * 13.17 + 2.3);
	float v_speed = etch_speed * (1.0 - speed_variation + v_hash * speed_variation * 2.0);
	float v_total = 1080.0 + line_length + dark_gap;
	float v_cycle = v_total / v_speed;
	float v_time = mod(TIME + v_hash * v_cycle * 4.1, v_cycle);
	float v_head_y = v_time * v_speed;
	float v_tail_y = v_head_y - line_length;

	float v_front = 1.0 - smoothstep(v_head_y - etcher_size, v_head_y, uv.y);
	float v_back = smoothstep(v_tail_y, v_tail_y + etcher_size, uv.y);
	float v_etch = v_front * v_back;

	float v_head_dist = abs(uv.y - v_head_y);
	float v_near_line = exp(-v_dist * v_dist / 20.0);
	float v_head_visible = step(-80.0, v_head_y) * step(v_head_y, 1160.0);
	float v_sparkle_val = sparkle(TIME, v_hash * 90.0 + 20.0);
	float v_head_bloom = exp(-v_head_dist * v_head_dist / (etcher_size * etcher_size))
		* v_near_line * v_sparkle_val * v_head_visible;

	float v_tail_dist = abs(uv.y - v_tail_y);
	float v_tail_visible = step(-80.0, v_tail_y) * step(v_tail_y, 1160.0);
	float v_tail_sparkle = sparkle(TIME, v_hash * 67.0 + 30.0);
	float v_tail_bloom = exp(-v_tail_dist * v_tail_dist / (etcher_size * etcher_size))
		* v_near_line * v_tail_sparkle * v_tail_visible;

	// Apply etching
	float h_line = h_line_raw * h_etch;
	float h_core_val = h_core * h_etch;
	float v_line = v_line_raw * v_etch;
	float v_core_val = v_core * v_etch;

	// Glow (wider color halo, etched)
	float h_glow = exp(-h_dist * h_dist / max(glow_size * glow_size, 0.001)) * 0.3 * h_etch;
	float v_glow = exp(-v_dist * v_dist / max(glow_size * glow_size, 0.001)) * 0.3 * v_etch;

	// Intersection + node
	float intersection = h_line * v_line;
	vec2 corner = round(pos / grid_spacing) * grid_spacing;
	float node_dist = length(pos - corner);
	float node_fresh = min(h_etch, v_etch);
	float node = exp(-node_dist * node_dist / 36.0) * node_fresh * 0.8;

	// ── Compose ──
	vec3 col = bg_color.rgb;
	col += band_col * band_alpha;

	// Color glow (wider, this is where the pink lives)
	col += grid_color.rgb * h_glow;
	col += grid_color.rgb * v_glow;

	// Line body — color layer
	col = mix(col, grid_color.rgb, h_line * grid_color.a);
	col = mix(col, grid_color.rgb, v_line * grid_color.a);

	// HDR white-hot core — blown out center pushes to white
	col += vec3(h_core_val * core_intensity);
	col += vec3(v_core_val * core_intensity);

	// Intersection + node
	col += grid_color.rgb * intersection * 0.4;
	col += grid_color.rgb * node;
	// Node HDR core
	float node_core = exp(-node_dist * node_dist / 12.0) * node_fresh;
	col += vec3(node_core * core_intensity * 0.5);

	// Etcher blooms — both head and tail, bright HDR
	float total_head_bloom = max(h_head_bloom, v_head_bloom);
	float total_tail_bloom = max(h_tail_bloom, v_tail_bloom);
	col += head_color.rgb * total_head_bloom * 3.0;
	col += head_color.rgb * total_tail_bloom * 2.5;

	COLOR = vec4(col, 1.0);
}
