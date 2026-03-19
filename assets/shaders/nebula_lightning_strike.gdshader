shader_type canvas_item;

uniform vec4 nebula_color : source_color = vec4(0.5, 0.6, 1.0, 1.0);
uniform float brightness : hint_range(0.5, 4.0) = 2.0;
uniform float animation_speed : hint_range(0.0, 3.0) = 1.0;
uniform float density : hint_range(0.5, 4.0) = 2.0;
uniform float seed_offset : hint_range(0.0, 1000.0) = 0.0;

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

// Continuous zigzag bolt: noise displaces a vertical line, distance field approach
float bolt_dist(vec2 uv, float time_seed, float x_center) {
	// Noise-displaced center line — continuous function of y, so no breaks
	float wobble = noise(vec2(uv.y * 8.0, time_seed)) * 0.15
				 + noise(vec2(uv.y * 16.0, time_seed + 5.0)) * 0.07
				 + noise(vec2(uv.y * 32.0, time_seed + 10.0)) * 0.03;
	float bolt_x = x_center + wobble - 0.125;
	return abs(uv.x - bolt_x);
}

void fragment() {
	float modulate_alpha = COLOR.a;
	float t = TIME * animation_speed;
	vec2 uv = UV;
	vec2 offset_uv = UV + seed_offset;

	// Background cloud
	float cloud = fbm(offset_uv * 3.0 + vec2(t * 0.05, -t * 0.03));
	cloud = pow(cloud, 2.5 - density * 0.3);

	vec2 center = UV - 0.5;
	float dist = length(center) * 2.0;
	float falloff = smoothstep(1.0, 0.2, dist);

	// Three bolts on staggered flash timers
	float flash_cycle = t * 1.2;
	float cycle_id = floor(flash_cycle);

	// Flash envelopes — sharp attack, quick decay
	float f1 = fract(flash_cycle);
	float f2 = fract(flash_cycle + 0.35);
	float f3 = fract(flash_cycle + 0.65);
	float env1 = smoothstep(0.0, 0.01, f1) * smoothstep(0.25, 0.01, f1);
	float env2 = smoothstep(0.0, 0.01, f2) * smoothstep(0.18, 0.01, f2);
	float env3 = smoothstep(0.0, 0.01, f3) * smoothstep(0.2, 0.01, f3);

	// Each bolt gets a unique position and noise seed per cycle
	float x1 = 0.25 + hash(vec2(cycle_id, seed_offset + 1.0)) * 0.5;
	float x2 = 0.2 + hash(vec2(cycle_id + 0.35, seed_offset + 2.0)) * 0.6;
	float x3 = 0.3 + hash(vec2(cycle_id + 0.65, seed_offset + 3.0)) * 0.4;

	float d1 = bolt_dist(uv, cycle_id * 3.7 + seed_offset, x1);
	float d2 = bolt_dist(uv, (cycle_id + 0.35) * 5.1 + seed_offset, x2);
	float d3 = bolt_dist(uv, (cycle_id + 0.65) * 2.3 + seed_offset, x3);

	// Core + glow from distance field
	float b1 = (smoothstep(0.006, 0.0, d1) + smoothstep(0.05, 0.0, d1) * 0.35) * env1;
	float b2 = (smoothstep(0.006, 0.0, d2) + smoothstep(0.05, 0.0, d2) * 0.35) * env2;
	float b3 = (smoothstep(0.006, 0.0, d3) + smoothstep(0.05, 0.0, d3) * 0.35) * env3;
	float bolts = b1 + b2 + b3;

	// Area flash glow
	float glow1 = exp(-length(uv - vec2(x1, 0.5)) * 5.0) * env1 * 0.5;
	float glow2 = exp(-length(uv - vec2(x2, 0.5)) * 5.0) * env2 * 0.3;
	float total_flash = bolts + glow1 + glow2;

	float nebula = cloud * falloff;
	vec3 col = nebula_color.rgb * nebula * brightness * 1.0;
	col += vec3(0.8, 0.9, 1.0) * total_flash * brightness * 2.0 * falloff;
	col += nebula_color.rgb * (glow1 + glow2) * cloud * brightness;

	float alpha = max(nebula, total_flash * 0.7) * nebula_color.a;
	alpha *= smoothstep(1.0, 0.4, dist);
	COLOR = vec4(col, alpha * modulate_alpha);
}
