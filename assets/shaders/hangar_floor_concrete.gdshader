shader_type canvas_item;
// Concrete bunker floor — rough aggregate texture, expansion joints, stains, cracks.

uniform vec3 base_color : source_color = vec3(0.14, 0.14, 0.13);
uniform vec3 joint_color : source_color = vec3(0.06, 0.06, 0.05);
uniform float joint_spacing : hint_range(50.0, 300.0) = 150.0;
uniform float joint_width : hint_range(0.5, 4.0) = 2.0;
uniform float roughness : hint_range(0.0, 0.2) = 0.06;
uniform float stain_intensity : hint_range(0.0, 0.15) = 0.04;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
	           mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
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

void fragment() {
	vec2 px = UV * vec2(textureSize(TEXTURE, 0));

	// Concrete aggregate texture (multi-octave noise)
	float grain = fbm(px * 0.15) * roughness;
	float fine = (noise(px * 0.8) - 0.5) * roughness * 0.5;

	// Expansion joints
	vec2 joint_uv = mod(px, joint_spacing);
	float jx = smoothstep(0.0, joint_width, joint_uv.x) * smoothstep(0.0, joint_width, joint_spacing - joint_uv.x);
	float jy = smoothstep(0.0, joint_width, joint_uv.y) * smoothstep(0.0, joint_width, joint_spacing - joint_uv.y);
	float joint = jx * jy;

	// Dark oil stains (large blotchy noise)
	float stain = fbm(px * 0.02);
	stain = smoothstep(0.45, 0.55, stain) * stain_intensity;

	// Subtle cracks
	float crack_noise = fbm(px * 0.08);
	float crack = smoothstep(0.48, 0.5, crack_noise) * smoothstep(0.52, 0.5, crack_noise);
	crack *= 0.08;

	vec3 col = base_color + grain + fine - stain - crack;
	col = mix(joint_color, col, joint);

	COLOR = vec4(col, 1.0);
}
