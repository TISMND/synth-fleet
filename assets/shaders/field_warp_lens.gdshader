shader_type canvas_item;
// Spatial distortion lens — warps the space around the ship with a
// visible rippling distortion field. Looks like heat haze or gravitational lensing.

uniform vec4 field_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float brightness : hint_range(0.0, 4.0) = 1.0;
uniform float animation_speed : hint_range(0.0, 3.0) = 1.0;
uniform float radius_ratio : hint_range(0.0, 1.0) = 0.8;
uniform float pulse_intensity : hint_range(0.0, 4.0) = 0.0;
uniform float pulse_tint : hint_range(0.0, 1.0) = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

// Per-shader params
uniform float warp_strength : hint_range(0.0, 0.3) = 0.08;
uniform float ripple_frequency : hint_range(1.0, 12.0) = 4.0;
uniform float ripple_speed : hint_range(0.0, 4.0) = 1.5;
uniform float edge_visibility : hint_range(0.0, 2.0) = 1.0;
uniform float chromatic_split : hint_range(0.0, 0.05) = 0.01;
uniform float outer_radius : hint_range(0.0, 1.0) = 0.95;

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

void fragment() {
	float modulate_alpha = COLOR.a;
	float t = TIME * animation_speed;
	vec2 uv = UV - 0.5;
	float raw_dist = length(uv) * 2.0;
	float dist = raw_dist / max(outer_radius, 0.01);
	float angle = atan(uv.y, uv.x);

	// Ring mask
	float outer_mask = smoothstep(1.0, 0.95, dist);
	float inner_mask = smoothstep(radius_ratio - 0.02, radius_ratio, dist);
	float ring = outer_mask * inner_mask;

	// Expanding ripple waves
	float ripple = sin((dist * ripple_frequency - t * ripple_speed) * TAU);
	ripple *= ring;

	// Warp displacement vector (radial)
	float warp = ripple * warp_strength * ring;
	vec2 warp_dir = normalize(uv + vec2(0.0001)); // avoid zero
	vec2 warped_uv = uv + warp_dir * warp;

	// Noise shimmer on the distortion boundary
	float shimmer = noise(vec2(angle * 5.0 + t * 2.0, dist * 10.0 - t * 1.5));
	shimmer = shimmer * 0.5 + 0.5;

	// Visible distortion edge — where warp gradient is strongest
	float warp_gradient = abs(ripple) * ring;
	float edge = warp_gradient * edge_visibility;

	// Chromatic aberration effect — color splits at distortion edges
	float r_offset = chromatic_split * ripple * ring;
	float split_r = smoothstep(0.0, 0.3, abs(sin((dist * ripple_frequency - t * ripple_speed + r_offset * 10.0) * TAU)) * ring);
	float split_b = smoothstep(0.0, 0.3, abs(sin((dist * ripple_frequency - t * ripple_speed - r_offset * 10.0) * TAU)) * ring);

	// Combine visible elements
	float base_intensity = edge * shimmer * brightness;
	base_intensity += base_intensity * pulse_intensity * 1.5;

	// Rim highlight at the field boundary
	float rim = smoothstep(0.88, 0.96, dist) * smoothstep(1.02, 0.96, dist) * 0.4 * brightness;
	rim += rim * pulse_intensity;

	vec3 col = field_color.rgb * (base_intensity + rim);
	// Add chromatic color split
	col.r += split_r * chromatic_split * 20.0 * brightness * field_color.r;
	col.b += split_b * chromatic_split * 20.0 * brightness * field_color.b;

	float alpha = clamp((edge * 0.6 + rim * 0.8) * opacity, 0.0, 1.0);
	if (raw_dist > 1.0) alpha = 0.0;

	float pt = pulse_tint * smoothstep(0.0, 0.3, pulse_intensity);
	col = mix(col, field_color.rgb * max(max(col.r, col.g), col.b), pt);
	COLOR = vec4(col, alpha * modulate_alpha);
}
