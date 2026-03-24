shader_type canvas_item;
// Mid-layer scrolling background: volcanic landscape — large patches of scorched
// black rock with lava flowing in veins between them. Balance of land vs lava.

uniform vec4 rock_color : source_color = vec4(0.018, 0.015, 0.012, 1.0);
uniform vec4 rock_dark : source_color = vec4(0.003, 0.002, 0.002, 1.0);
uniform vec4 obsidian_color : source_color = vec4(0.005, 0.005, 0.008, 1.0);
uniform vec4 ash_color : source_color = vec4(0.03, 0.025, 0.02, 1.0);
uniform vec4 lava_color : source_color = vec4(1.0, 0.35, 0.0, 1.0);
uniform vec4 lava_hot : source_color = vec4(1.0, 0.85, 0.2, 1.0);
uniform vec4 ember_color : source_color = vec4(1.0, 0.5, 0.1, 1.0);
uniform float scroll_speed : hint_range(0.0, 200.0) = 20.0;
uniform float crack_scale : hint_range(0.5, 4.0) = 1.5;
uniform float lava_brightness : hint_range(0.0, 3.0) = 1.2;
uniform float pulse_speed : hint_range(0.0, 3.0) = 0.8;
uniform float crack_width : hint_range(0.01, 0.15) = 0.05;
uniform float rock_coverage : hint_range(0.0, 1.0) = 0.65;
uniform float ember_density : hint_range(0.0, 1.0) = 0.5;
uniform bool manual_scroll = false;
uniform float scroll_offset : hint_range(0.0, 100000.0) = 0.0;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash22(vec2 p) {
	return vec2(
		fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453),
		fract(sin(dot(p, vec2(269.5, 183.3))) * 43758.5453)
	);
}

vec3 voronoi(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float min_d1 = 10.0;
	float min_d2 = 10.0;
	vec2 closest = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 point = hash22(i + neighbor);
			vec2 diff = neighbor + point - f;
			float d = dot(diff, diff);
			if (d < min_d1) {
				min_d2 = min_d1;
				min_d1 = d;
				closest = i + neighbor;
			} else if (d < min_d2) {
				min_d2 = d;
			}
		}
	}
	return vec3(sqrt(min_d1), sqrt(min_d2), hash21(closest));
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.1;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = FRAGCOORD.xy;
	float y_scroll = manual_scroll ? -scroll_offset : -TIME * scroll_speed;
	vec2 pos = (uv + vec2(0.0, y_scroll)) * 0.005 * crack_scale;

	// Primary voronoi — defines rock plates and lava channels
	vec3 vor1 = voronoi(pos * 4.0);
	// Secondary voronoi — finer crack detail
	vec3 vor2 = voronoi(pos * 8.0 + vec2(5.0, 3.0));

	float edge1 = vor1.y - vor1.x;
	float edge2 = vor2.y - vor2.x;

	// ── Lava veins — only in the cracks ──
	float crack1 = 1.0 - smoothstep(0.0, crack_width, edge1);
	float crack2 = 1.0 - smoothstep(0.0, crack_width * 0.6, edge2);
	float crack = max(crack1, crack2 * 0.5);

	// Lava glow — contained close to cracks, not flooding the rock
	float glow_spread = crack_width * 3.0;
	float glow1 = exp(-edge1 * edge1 / max(glow_spread * glow_spread, 0.001)) * 0.6;
	float glow2 = exp(-edge2 * edge2 / max(glow_spread * glow_spread * 0.5, 0.001)) * 0.3;

	// Per-cell lava activity — some cells are cooler (less/no lava at edges)
	float cell_heat = vor1.z; // 0-1 per cell
	float is_active = smoothstep(1.0 - rock_coverage, 1.0 - rock_coverage + 0.3, cell_heat);
	// Cool cells have no lava at their borders
	float lava_activity = mix(0.1, 1.0, is_active);

	float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed + vor1.z * 6.28);
	float glow = max(glow1, glow2) * pulse * lava_activity;
	crack *= lava_activity;

	// ── Rock surface — the dominant visual ──
	// Distance from crack center determines rock vs lava transition
	float rock_mask = smoothstep(crack_width * 0.8, crack_width * 2.5, edge1);

	// Rock type varies per cell
	float rock_type = hash21(floor(pos * 4.0) + vec2(7.0, 13.0));

	// Base rock texture — rough basalt
	float basalt_tex = fbm(pos * 20.0) * 0.08;
	float basalt_rough = noise(pos * 40.0) * 0.04;

	// Large-scale terrain variation
	float terrain_var = fbm(pos * 1.5 + vec2(3.0, 7.0));

	// Scorched black patches — large areas of completely dark ground
	float scorch_noise = fbm(pos * 2.0 + vec2(11.0, 5.0));
	float scorched = smoothstep(0.35, 0.55, scorch_noise);

	// Obsidian patches — glassy volcanic glass
	float obsidian_noise = fbm(pos * 3.5 + vec2(23.0, 17.0));
	float obsidian = smoothstep(0.6, 0.7, obsidian_noise) * (1.0 - scorched);

	// Ash deposits — lighter patches
	float ash_noise = fbm(pos * 2.5 + vec2(41.0, 29.0));
	float ash = smoothstep(0.55, 0.65, ash_noise) * (1.0 - scorched) * (1.0 - obsidian);

	// Cooling rim — dark crust forming at the edge of lava veins
	float cool_rim = smoothstep(crack_width * 0.3, crack_width * 1.5, edge1)
		* (1.0 - smoothstep(crack_width * 1.5, crack_width * 4.0, edge1));

	// ── Ember particles ──
	float ember_total = 0.0;
	float ember_heat = 0.0;
	for (int layer = 0; layer < 3; layer++) {
		float lf = float(layer);
		float e_scale = 8.0 + lf * 4.0;
		vec2 e_offset = vec2(
			sin(TIME * (0.3 + lf * 0.2)) * (5.0 + lf * 3.0),
			TIME * (15.0 + lf * 10.0)
		);
		vec2 e_pos = pos * e_scale + e_offset + vec2(lf * 17.0, lf * 31.0);
		vec2 e_cell = floor(e_pos);
		vec2 e_fract = fract(e_pos);
		float e_hash = hash21(e_cell + vec2(lf * 7.0, 0.0));
		if (e_hash > 1.0 - ember_density * 0.25) {
			vec2 e_center = vec2(0.5) + 0.3 * sin(TIME * vec2(1.5 + lf, 0.8 + lf * 0.5) + e_hash * 6.28);
			float e_d = length(e_fract - e_center);
			float e_size = 0.04 + e_hash * 0.06;
			float life = fract(TIME * (0.15 + e_hash * 0.25) + e_hash);
			float life_bright = sin(life * 3.14159);
			life_bright *= life_bright;
			float ember = exp(-e_d * e_d / max(e_size * e_size, 0.0001)) * life_bright;
			ember_total += ember * 0.5;
			ember_heat += exp(-e_d * e_d / max(e_size * e_size * 0.3, 0.0001)) * life_bright * 0.2;
		}
	}

	// ── Compose ──
	// Start with base rock
	vec3 col = rock_color.rgb;
	col += vec3(basalt_tex * 0.4, basalt_tex * 0.15, 0.0);
	col += vec3(basalt_rough * 0.2, basalt_rough * 0.08, 0.0);

	// Terrain color variation
	col *= 0.85 + terrain_var * 0.3;

	// Scorched black patches
	col = mix(col, rock_dark.rgb, scorched * 0.8);

	// Obsidian patches (darker, slightly reflective)
	col = mix(col, obsidian_color.rgb, obsidian * 0.7);

	// Ash deposits (lighter gray)
	col = mix(col, ash_color.rgb, ash * 0.5);

	// Cooling rim (darkened ring around lava veins)
	col = mix(col, rock_dark.rgb, cool_rim * 0.4 * lava_activity);

	// Apply rock mask — rock is dominant, lava only in cracks
	vec3 rock_final = col;

	// Subtle underglow near active cracks
	col += lava_color.rgb * glow * 0.15;

	// Lava in cracks — confined to narrow veins
	vec3 lava = mix(lava_color.rgb, lava_hot.rgb, crack * pulse) * lava_brightness;
	col = mix(col, lava, crack);

	// Very narrow glow halo around lava (contained)
	col += lava_color.rgb * glow * lava_brightness * 0.12;

	// Hot spots at some crack junctions
	float hot = exp(-vor1.x * vor1.x * 30.0) * step(0.7, vor1.z) * pulse * lava_activity;
	col += lava_hot.rgb * hot * lava_brightness * 0.5;

	// Embers (sparse, near lava areas)
	vec3 e_col = mix(ember_color.rgb, lava_hot.rgb, ember_heat);
	col += e_col * ember_total * lava_brightness * lava_activity;

	COLOR = vec4(col, 1.0);
}
