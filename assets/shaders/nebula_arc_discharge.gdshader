shader_type canvas_item;

uniform vec4 nebula_color : source_color = vec4(0.3, 0.7, 1.0, 1.0);
uniform float brightness : hint_range(0.5, 4.0) = 2.0;
uniform float animation_speed : hint_range(0.0, 3.0) = 0.8;
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
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

// Arc between two points: parameterize along the line, displace perpendicular with noise
float arc_dist(vec2 uv, vec2 p_a, vec2 p_b, float time_seed) {
	vec2 ab = p_b - p_a;
	float len = length(ab);
	if (len < 0.001) return 1.0;
	vec2 dir = ab / len;
	vec2 perp = vec2(-dir.y, dir.x);

	vec2 ap = uv - p_a;
	float along = dot(ap, dir) / len; // 0..1 parameterization
	if (along < 0.0 || along > 1.0) return 1.0;

	float perp_dist = dot(ap, perp);

	// Noise displacement perpendicular to the arc
	float wobble = noise(vec2(along * 10.0, time_seed)) * 0.08
				 + noise(vec2(along * 20.0, time_seed + 7.0)) * 0.04
				 + noise(vec2(along * 40.0, time_seed + 13.0)) * 0.02;
	// Taper at endpoints
	float taper = smoothstep(0.0, 0.1, along) * smoothstep(1.0, 0.9, along);
	wobble *= taper;

	return abs(perp_dist - wobble + 0.07);
}

void fragment() {
	float modulate_alpha = COLOR.a;
	float t = TIME * animation_speed;
	vec2 uv = UV;
	vec2 offset_uv = UV + seed_offset;

	float cloud = fbm(offset_uv * 3.0 + vec2(t * 0.04, -t * 0.03));
	cloud = pow(cloud, 2.5 - density * 0.3);

	vec2 ctr = UV - 0.5;
	float dist = length(ctr) * 2.0;
	float falloff = smoothstep(1.0, 0.2, dist);

	float flash_cycle = t * 0.9;
	float cycle_id = floor(flash_cycle);
	float phase = fract(flash_cycle);

	// Two arcs per cycle, staggered
	float env1 = smoothstep(0.0, 0.02, phase) * smoothstep(0.35, 0.02, phase);
	float env2 = smoothstep(0.3, 0.32, phase) * smoothstep(0.7, 0.32, phase);

	// Random endpoints anchored near edges, arcing across the nebula
	vec2 a1 = vec2(0.1 + hash(vec2(cycle_id, seed_offset + 1.0)) * 0.2,
				   0.15 + hash(vec2(cycle_id, seed_offset + 2.0)) * 0.3);
	vec2 b1 = vec2(0.7 + hash(vec2(cycle_id, seed_offset + 3.0)) * 0.2,
				   0.55 + hash(vec2(cycle_id, seed_offset + 4.0)) * 0.3);
	vec2 a2 = vec2(0.3 + hash(vec2(cycle_id + 0.5, seed_offset + 5.0)) * 0.4,
				   0.1 + hash(vec2(cycle_id + 0.5, seed_offset + 6.0)) * 0.15);
	vec2 b2 = vec2(0.2 + hash(vec2(cycle_id + 0.5, seed_offset + 7.0)) * 0.5,
				   0.75 + hash(vec2(cycle_id + 0.5, seed_offset + 8.0)) * 0.15);

	float d1 = arc_dist(uv, a1, b1, cycle_id * 4.3 + seed_offset);
	float d2 = arc_dist(uv, a2, b2, (cycle_id + 0.5) * 6.1 + seed_offset);

	float arc1 = (smoothstep(0.005, 0.0, d1) + smoothstep(0.04, 0.0, d1) * 0.4) * env1;
	float arc2 = (smoothstep(0.005, 0.0, d2) + smoothstep(0.04, 0.0, d2) * 0.4) * env2;
	float arcs = arc1 + arc2;

	// Flash glow at midpoints
	vec2 mid1 = mix(a1, b1, 0.5);
	vec2 mid2 = mix(a2, b2, 0.5);
	float glow1 = exp(-length(uv - mid1) * 6.0) * env1 * 0.4;
	float glow2 = exp(-length(uv - mid2) * 6.0) * env2 * 0.3;

	float total = arcs + glow1 + glow2;
	float nebula = cloud * falloff;
	vec3 col = nebula_color.rgb * nebula * brightness * 1.0;
	col += vec3(0.85, 0.92, 1.0) * total * brightness * 2.0 * falloff;
	col += nebula_color.rgb * (glow1 + glow2) * cloud * brightness;

	float alpha = max(nebula, total * 0.7) * nebula_color.a;
	alpha *= smoothstep(1.0, 0.4, dist);
	COLOR = vec4(col, alpha * modulate_alpha);
}
