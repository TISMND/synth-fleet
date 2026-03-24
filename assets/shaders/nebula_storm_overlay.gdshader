shader_type canvas_item;
// Storm overlay layer — renders ONLY lightning bolts on a transparent background.
// Composited on top of any base nebula style as a separate layer.

uniform vec4 nebula_color : source_color = vec4(0.5, 0.6, 1.0, 1.0);
uniform float animation_speed : hint_range(0.0, 3.0) = 1.0;
uniform float seed_offset : hint_range(0.0, 1000.0) = 0.0;
uniform float radial_spread : hint_range(0.05, 1.0) = 0.2;
uniform float brightness : hint_range(0.5, 4.0) = 2.0;

// Storm controls
uniform float storm_frequency : hint_range(0.0, 1.0) = 0.4;
uniform float storm_strike_size : hint_range(0.02, 0.4) = 0.12;
uniform float storm_duration : hint_range(0.05, 0.5) = 0.2;
uniform float storm_glow_diameter : hint_range(0.0, 1.0) = 0.3;

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

// Short bolt along an arbitrary line segment with noise displacement
float bolt_segment_dist(vec2 uv, vec2 p_a, vec2 p_b, float time_seed) {
	vec2 ab = p_b - p_a;
	float len = length(ab);
	if (len < 0.001) return 1.0;
	vec2 dir = ab / len;
	vec2 perp = vec2(-dir.y, dir.x);

	vec2 ap = uv - p_a;
	float along = dot(ap, dir) / len;
	if (along < 0.0 || along > 1.0) return 1.0;

	float perp_dist = dot(ap, perp);

	// Noise driven by actual distance along bolt so zigzag density stays consistent
	// regardless of bolt length. Wobble amplitude scales with len so short bolts
	// stay thin and proportional — a short strike isn't visibly wider than a long one.
	float dist_along = along * len;
	float amp = min(len * 0.5, 0.06);
	float wobble = noise(vec2(dist_along * 60.0, time_seed)) * amp
				 + noise(vec2(dist_along * 120.0, time_seed + 5.0)) * amp * 0.5
				 + noise(vec2(dist_along * 240.0, time_seed + 10.0)) * amp * 0.25;

	float taper = smoothstep(0.0, 0.12, along) * smoothstep(1.0, 0.88, along);
	wobble *= taper;

	return abs(perp_dist - wobble);
}

void fragment() {
	float modulate_alpha = COLOR.a;
	float t = TIME * animation_speed;
	vec2 uv = UV;

	vec2 center = UV - 0.5;
	float dist = length(center) * 2.0;
	float falloff = smoothstep(1.0, 1.0 - radial_spread, dist);

	float total_flash = 0.0;

	// Glow falloff factor from diameter: smaller diameter = tighter glow
	float glow_falloff = max(1.0 / max(storm_glow_diameter, 0.001) * 0.3, 1.0);

	// 6 independent storm cells scattered through the nebula
	for (int cell = 0; cell < 6; cell++) {
		float cf = float(cell);

		// Storm cell center
		vec2 cell_center = vec2(
			0.2 + hash(vec2(cf, seed_offset + 1.0)) * 0.6,
			0.2 + hash(vec2(cf + 10.0, seed_offset + 2.0)) * 0.6
		);

		// Independent timing per cell
		float cell_rate = 0.5 + hash(vec2(cf, seed_offset + 50.0)) * 0.7;
		float cell_time = t * cell_rate + hash(vec2(cf, seed_offset + 100.0)) * 20.0;
		float cell_cycle = floor(cell_time);
		float cell_phase = fract(cell_time);

		// Skip most cycles — controlled by storm_frequency
		float skip = hash(vec2(cell_cycle, cf + seed_offset + 200.0));
		if (skip > max(storm_frequency, 0.001)) continue;

		// Flash envelope — duration controlled by storm_duration uniform
		float dur = storm_duration * (0.6 + hash(vec2(cell_cycle + 0.1, cf + seed_offset + 250.0)) * 0.8);
		float env = smoothstep(0.0, 0.01, cell_phase) * smoothstep(dur, 0.01, cell_phase);
		if (env < 0.001) continue;

		// Zip-zap animation: bolt reshapes several times during flash
		float zap_rate = 12.0 + hash(vec2(cf + 3.0, seed_offset + 150.0)) * 16.0;
		float zap_frame = floor(cell_phase * zap_rate);
		float zap_seed = cell_cycle * 3.7 + cf * 5.0 + seed_offset + zap_frame * 7.13;

		// Short bolt — size controlled by storm_strike_size uniform
		float bolt_angle = hash(vec2(cell_cycle + 0.3, cf + seed_offset + 300.0)) * 6.2832;
		float bolt_len = storm_strike_size * (0.5 + hash(vec2(cell_cycle + 0.5, cf + seed_offset + 400.0)));
		// Per-frame jitter
		float angle_jitter = (hash(vec2(zap_frame, cf + seed_offset + 330.0)) - 0.5) * 0.6;
		vec2 bolt_dir = vec2(cos(bolt_angle + angle_jitter), sin(bolt_angle + angle_jitter));
		float endpoint_jitter = (hash(vec2(zap_frame + 1.0, cf + seed_offset + 340.0)) - 0.5) * 0.03;
		vec2 p_a = cell_center - bolt_dir * bolt_len * 0.5 + vec2(endpoint_jitter, -endpoint_jitter);
		vec2 p_b = cell_center + bolt_dir * bolt_len * 0.5 + vec2(-endpoint_jitter, endpoint_jitter);

		float d = bolt_segment_dist(uv, p_a, p_b, zap_seed);

		// Core + glow halo
		float bolt = (smoothstep(0.005, 0.0, d) + smoothstep(0.04, 0.0, d) * 0.35) * env;

		// Localized area flash — size controlled by storm_glow_diameter
		float glow = exp(-length(uv - cell_center) * glow_falloff) * env * 0.25;

		total_flash += bolt + glow;

		// Occasional secondary fork
		float fork_chance = hash(vec2(cell_cycle + 0.7, cf + seed_offset + 500.0));
		if (fork_chance < 0.35) {
			float fork_angle = bolt_angle + angle_jitter + (hash(vec2(zap_frame + 2.0, cf + seed_offset + 600.0)) - 0.5) * 1.8;
			float fork_len = bolt_len * (0.3 + hash(vec2(cell_cycle + 0.9, cf + seed_offset + 700.0)) * 0.4);
			vec2 fork_origin = mix(p_a, p_b, 0.4 + hash(vec2(zap_frame + 3.0, cf + seed_offset + 800.0)) * 0.4);
			vec2 fork_dir = vec2(cos(fork_angle), sin(fork_angle));
			vec2 fork_end = fork_origin + fork_dir * fork_len;
			float fd = bolt_segment_dist(uv, fork_origin, fork_end, zap_seed + 50.0);
			float fork_bolt = (smoothstep(0.004, 0.0, fd) + smoothstep(0.03, 0.0, fd) * 0.25) * env * 0.7;
			total_flash += fork_bolt;
		}
	}

	// Output: white-blue lightning on transparent background for compositing
	vec3 bolt_color = vec3(0.8, 0.9, 1.0) * total_flash * brightness * 2.0 * falloff;
	bolt_color += nebula_color.rgb * total_flash * brightness * 0.3 * falloff;
	float alpha = total_flash * 0.8 * falloff;
	alpha *= smoothstep(1.0, 0.4, dist);
	COLOR = vec4(bolt_color, alpha * modulate_alpha);
}
