shader_type canvas_item;

uniform vec4 nebula_color : source_color = vec4(0.7, 0.85, 1.0, 1.0);
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

// Lightning bolt: trace a jagged vertical path with noise displacement
float bolt(vec2 uv, float time_seed, float x_origin) {
	float bolt_x = x_origin;
	float intensity = 0.0;
	float segment_h = 0.05;
	for (int i = 0; i < 16; i++) {
		float y_start = float(i) * segment_h;
		float y_end = y_start + segment_h;
		if (uv.y >= y_start && uv.y < y_end) {
			// Jag the bolt sideways using noise
			bolt_x += (hash(vec2(float(i) * 7.13, time_seed)) - 0.5) * 0.12;
			float dx = abs(uv.x - bolt_x);
			// Thin bright core + wider glow
			float core = smoothstep(0.008, 0.0, dx);
			float glow = smoothstep(0.06, 0.0, dx) * 0.4;
			intensity = core + glow;
			break;
		}
		bolt_x += (hash(vec2(float(i) * 7.13, time_seed)) - 0.5) * 0.12;
	}
	return intensity;
}

void fragment() {
	float modulate_alpha = COLOR.a;
	float t = TIME * animation_speed;
	vec2 uv = UV;
	vec2 offset_uv = UV + seed_offset;

	// Soft background cloud
	float cloud = fbm(offset_uv * 3.0 + vec2(t * 0.05, -t * 0.03));
	cloud = pow(cloud, 2.5 - density * 0.3);

	vec2 center = UV - 0.5;
	float dist = length(center) * 2.0;
	float falloff = smoothstep(1.0, 0.2, dist);

	// Flash timing — localized flashes that appear and fade
	float flash_cycle = t * 1.5;
	float flash1_phase = fract(flash_cycle);
	float flash2_phase = fract(flash_cycle + 0.4);
	float flash3_phase = fract(flash_cycle + 0.7);

	// Each flash: bright burst that decays quickly
	float flash1_intensity = smoothstep(0.0, 0.02, flash1_phase) * smoothstep(0.2, 0.02, flash1_phase);
	float flash2_intensity = smoothstep(0.0, 0.02, flash2_phase) * smoothstep(0.15, 0.02, flash2_phase);
	float flash3_intensity = smoothstep(0.0, 0.02, flash3_phase) * smoothstep(0.18, 0.02, flash3_phase);

	// Bolt positions vary per flash cycle
	float cycle_id = floor(flash_cycle);
	float bolt1 = bolt(uv, cycle_id * 3.7 + seed_offset, 0.3 + hash(vec2(cycle_id, 1.0)) * 0.4) * flash1_intensity;
	float bolt2 = bolt(uv, (cycle_id + 0.4) * 5.1 + seed_offset, 0.2 + hash(vec2(cycle_id, 2.0)) * 0.5) * flash2_intensity;
	float bolt3 = bolt(uv, (cycle_id + 0.7) * 2.3 + seed_offset, 0.35 + hash(vec2(cycle_id, 3.0)) * 0.35) * flash3_intensity;

	float bolts = bolt1 + bolt2 + bolt3;

	// Localized area flash glow around bolt origins
	float flash_glow1 = exp(-length(uv - vec2(0.3 + hash(vec2(cycle_id, 1.0)) * 0.4, 0.4)) * 6.0) * flash1_intensity * 0.6;
	float flash_glow2 = exp(-length(uv - vec2(0.2 + hash(vec2(cycle_id, 2.0)) * 0.5, 0.5)) * 6.0) * flash2_intensity * 0.4;

	float total_flash = bolts + flash_glow1 + flash_glow2;

	// Combine cloud + lightning
	float nebula = cloud * falloff;
	vec3 col = nebula_color.rgb * nebula * brightness * 1.2;
	// Lightning is white-blue
	col += vec3(0.8, 0.9, 1.0) * total_flash * brightness * 2.0 * falloff;
	// Subtle cloud illumination from flashes
	col += nebula_color.rgb * (flash_glow1 + flash_glow2) * cloud * brightness;

	float alpha = max(nebula, total_flash * 0.7) * nebula_color.a;
	alpha *= smoothstep(1.0, 0.4, dist);
	COLOR = vec4(col, alpha * modulate_alpha);
}
