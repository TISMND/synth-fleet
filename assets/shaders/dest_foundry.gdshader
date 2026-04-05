shader_type canvas_item;
// Foundry — Industrial molten metal processing complex. Horizontal channels
// of flowing hot metal crossing the view, structural housing pipes and
// valves, billowing heat haze, sparks from pour points, chimney flares.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 3.0;
uniform vec3 bg_color : source_color = vec3(0.02, 0.012, 0.015);
uniform vec3 metal_hull : source_color = vec3(0.12, 0.1, 0.11);
uniform vec3 metal_mid : source_color = vec3(0.28, 0.22, 0.20);
uniform vec3 molten_color : source_color = vec3(1.0, 0.35, 0.05);
uniform vec3 molten_hot : source_color = vec3(1.0, 0.85, 0.4);
uniform vec3 spark_color : source_color = vec3(1.0, 0.7, 0.25);
uniform vec3 pilot_color : source_color = vec3(0.3, 0.9, 1.0);
uniform float flow_speed : hint_range(0.0, 2.0) = 0.8;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
	           mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * vnoise(p); p *= 2.03; a *= 0.5; }
	return v;
}

float sd_rect(vec2 p, vec2 hs) {
	vec2 q = abs(p) - hs;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
}

void fragment() {
	vec2 uv = UV;
	float ar = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec3 col = bg_color;

	// Use full-frame UV (not centered). We'll build horizontal channels.

	// ══════════════════════════════════════════════
	// BACKGROUND HEAT GLOW
	// ══════════════════════════════════════════════
	// Radial warm wash from center-bottom (furnace)
	vec2 furnace_center = vec2(0.5, 0.72);
	float fdist = length((uv - furnace_center) * vec2(ar * 0.9, 1.0));
	col += molten_color * exp(-fdist * fdist * 7.0) * hdr_intensity * 0.25;
	col += molten_hot * exp(-fdist * fdist * 28.0) * hdr_intensity * 0.4;

	// Heat haze distortion (fake: just noise overlay)
	vec2 haze_uv = uv * vec2(15.0, 8.0) + vec2(0.0, -TIME * 0.3);
	float haze_n = fbm(haze_uv);
	col += molten_color * haze_n * smoothstep(0.9, 0.3, uv.y) * 0.06 * hdr_intensity;

	// ══════════════════════════════════════════════
	// MOLTEN CHANNELS — 3 horizontal streams crossing the view
	// ══════════════════════════════════════════════
	float channel_y[3] = float[3](0.28, 0.52, 0.78);
	float channel_h[3] = float[3](0.018, 0.025, 0.020);
	float channel_flow[3] = float[3](1.0, -0.7, 0.9);

	for (int c = 0; c < 3; c++) {
		float fc = float(c);
		float cy = channel_y[c];
		float ch = channel_h[c];
		float flow = channel_flow[c];
		float d_to_center = abs(uv.y - cy);
		if (d_to_center > ch * 3.0) continue;

		// Molten flow: noise scrolling along channel
		vec2 flow_uv = vec2(uv.x * 8.0 - TIME * flow * flow_speed, uv.y * 40.0 + fc * 3.0);
		float flow_n = fbm(flow_uv);
		float flow_n2 = fbm(flow_uv * 2.0 + 3.0);
		float turbulence = flow_n * 0.7 + flow_n2 * 0.3;

		// Inside channel
		if (d_to_center < ch) {
			// Gaussian brightness profile across channel width
			float profile = exp(-d_to_center * d_to_center / (ch * ch * 0.3));
			// Animated molten color
			vec3 molten = mix(molten_color, molten_hot, turbulence);
			// Hot streaks
			float streak = pow(turbulence, 3.0);
			molten += molten_hot * streak * 0.6;
			col = molten * profile * hdr_intensity * 1.1 + col * (1.0 - profile);
			// Cooled edges (darker red)
			float edge_cool = smoothstep(ch, ch * 0.85, d_to_center);
			col = mix(col, molten_color * 0.3, edge_cool * 0.4);
		} else {
			// Outside: glow halo
			float halo = exp(-d_to_center * d_to_center / (ch * ch * 1.8));
			col += molten_color * halo * hdr_intensity * 0.45;
			float halo_wide = exp(-d_to_center * d_to_center / (ch * ch * 10.0));
			col += molten_color * halo_wide * hdr_intensity * 0.12;
		}

		// Channel trough walls (dark metal strips above and below)
		float wall_outer = ch + 0.004;
		float wall_inner = ch + 0.001;
		if (d_to_center > wall_inner && d_to_center < wall_outer) {
			col = metal_hull * (0.8 + turbulence * 0.2);
		}

		// Bright rim on wall facing molten
		if (d_to_center > ch && d_to_center < wall_inner) {
			col = metal_mid + molten_hot * (1.0 - (d_to_center - ch) / 0.001) * hdr_intensity * 0.6;
		}
	}

	// ══════════════════════════════════════════════
	// STRUCTURAL HOUSING — vertical pipes, valves, supports
	// ══════════════════════════════════════════════
	// Vertical pipes at fixed x positions
	float pipe_x[5] = float[5](0.08, 0.22, 0.46, 0.68, 0.91);
	float pipe_w[5] = float[5](0.012, 0.008, 0.015, 0.010, 0.013);
	for (int p = 0; p < 5; p++) {
		float fp = float(p);
		float px = pipe_x[p];
		float pw = pipe_w[p];
		float dx = abs(uv.x - px);
		if (dx > pw + 0.004) continue;
		// Pipe body
		if (dx < pw) {
			float shade = 0.6 + 0.4 * smoothstep(pw, -pw, uv.x - px);
			col = metal_hull * shade * 1.1;
			// Rivet rows every 0.05 in y
			float rivet_y = fract(uv.y * 22.0);
			float rivet = smoothstep(0.08, 0.0, abs(rivet_y - 0.5));
			float rivet_x_mask = smoothstep(pw * 0.4, pw * 0.1, dx);
			col += metal_mid * rivet * rivet_x_mask * 0.4;
			// Heat glow from below (fade up)
			float heat_from_below = smoothstep(0.2, 0.9, uv.y);
			col = mix(col, col + molten_color * 0.15, heat_from_below);
		}
		// Rim
		float edge = abs(dx - pw);
		col += vec3(0.4, 0.42, 0.48) * smoothstep(0.002, 0.0, edge) * hdr_intensity * 0.35;

		// Valve bulges at intersections with channels
		for (int ch_i = 0; ch_i < 3; ch_i++) {
			float cy = channel_y[ch_i];
			float to_valve = length(vec2((uv.x - px) * ar, uv.y - cy));
			if (to_valve < 0.022) {
				float valve_core = smoothstep(0.022, 0.018, to_valve);
				col = metal_mid * 1.3;
				// Valve wheel
				float wheel = smoothstep(0.006, 0.004, abs(to_valve - 0.012));
				col += vec3(0.5, 0.52, 0.58) * wheel * 0.8;
				// Pilot light on valve
				vec2 pilot_pos = vec2(px + 0.008, cy - 0.012);
				float pd = length((uv - pilot_pos) * vec2(ar, 1.0));
				float pilot_blink = 0.5 + 0.5 * sin(TIME * 3.0 + fp * 2.0);
				col += pilot_color * exp(-pd * pd / 0.000004) * pilot_blink * hdr_intensity * 2.5;
			}
		}
	}

	// ══════════════════════════════════════════════
	// SPARK BURSTS — at channel pour points
	// ══════════════════════════════════════════════
	for (int sp = 0; sp < 6; sp++) {
		float fs = float(sp);
		float period = 0.8 + hash(vec2(fs, 7.0)) * 1.2;
		float phase = hash(vec2(fs, 11.0)) * period;
		float ct = mod(TIME + phase, period);
		float dur = 0.25;
		float alive = smoothstep(dur, dur - 0.04, ct) * smoothstep(0.0, 0.02, ct);
		if (alive < 0.01) continue;
		float flash = alive * smoothstep(dur, 0.0, ct);
		float sid = floor((TIME + phase) / period);
		// Position at a random point along a channel
		int ch_pick = int(hash(vec2(fs, sid * 3.0)) * 3.0) % 3;
		vec2 spark_pos = vec2(
			hash(vec2(fs, sid * 5.0)),
			channel_y[ch_pick] + (hash(vec2(fs, sid * 7.0)) - 0.5) * 0.08
		);
		// Draw several trailing sparks upward
		for (int tr = 0; tr < 4; tr++) {
			float ftr = float(tr);
			float spark_age = ct + ftr * 0.02;
			float spark_y_off = -spark_age * 0.25;
			float spark_x_off = (hash(vec2(fs + ftr, sid)) - 0.5) * 0.03 * spark_age * 3.0;
			vec2 spp = spark_pos + vec2(spark_x_off, spark_y_off);
			float sd_spark = length((uv - spp) * vec2(ar, 1.0));
			float tr_fade = 1.0 - float(tr) * 0.22;
			col += spark_color * exp(-sd_spark * sd_spark / 0.0000025) * flash * tr_fade * hdr_intensity * 3.0;
			col += spark_color * exp(-sd_spark * sd_spark / 0.00025) * flash * tr_fade * hdr_intensity * 0.35;
		}
	}

	// ══════════════════════════════════════════════
	// CHIMNEY FLARES — top of frame, 2 vertical flames
	// ══════════════════════════════════════════════
	for (int cf = 0; cf < 2; cf++) {
		float fcf = float(cf);
		float cx = 0.3 + fcf * 0.4;
		float dx = abs(uv.x - cx);
		if (dx > 0.025 || uv.y > 0.15) continue;
		float flame_y_t = 1.0 - uv.y / 0.15;
		float flame_width = mix(0.005, 0.018, flame_y_t);
		float flame_mask = exp(-dx * dx / (flame_width * flame_width));
		float flame_noise = fbm(vec2(dx * 30.0, uv.y * 60.0 + TIME * 6.0));
		float flame_shape = flame_mask * flame_noise * flame_y_t;
		col += molten_hot * flame_shape * hdr_intensity * 0.8;
		col += molten_color * flame_shape * hdr_intensity * 0.4;
	}

	// ══════════════════════════════════════════════
	// Ambient soot particles
	// ══════════════════════════════════════════════
	vec2 soot_uv = uv * vec2(80.0, 50.0) + vec2(0.0, -TIME * 0.15);
	float soot = vnoise(soot_uv);
	soot = smoothstep(0.75, 0.85, soot);
	col = mix(col, bg_color * 0.5, soot * 0.3);

	COLOR = vec4(col, 1.0);
}
