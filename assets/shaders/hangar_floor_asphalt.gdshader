shader_type canvas_item;
// Asphalt tarmac floor — dark granular surface, faded paint traces, weathering.

uniform vec3 base_color : source_color = vec3(0.07, 0.07, 0.08);
uniform float grain_scale : hint_range(0.5, 5.0) = 2.0;
uniform float grain_intensity : hint_range(0.0, 0.15) = 0.04;
uniform float wear_intensity : hint_range(0.0, 0.1) = 0.03;
uniform float patch_visibility : hint_range(0.0, 0.15) = 0.04;

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
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.1;
		a *= 0.48;
	}
	return v;
}

void fragment() {
	vec2 px = UV * vec2(textureSize(TEXTURE, 0));

	// Fine gravel grain
	float grain = (hash(floor(px * grain_scale)) - 0.5) * grain_intensity;
	// Medium aggregate
	float aggregate = (noise(px * 0.4) - 0.5) * grain_intensity * 0.8;

	// Wear patterns (lighter patches where traffic has worn the surface)
	float wear = fbm(px * 0.01);
	wear = smoothstep(0.4, 0.6, wear) * wear_intensity;

	// Repair patches (slightly different tone rectangles)
	float patch_id_x = floor(px.x / 200.0);
	float patch_id_y = floor(px.y / 180.0);
	float patch_hash = hash(vec2(patch_id_x, patch_id_y));
	float patch = step(0.7, patch_hash) * patch_visibility;

	// Subtle tar seams
	float tar_x = smoothstep(1.0, 0.0, abs(mod(px.x, 300.0) - 150.0) - 148.0) * 0.02;

	vec3 col = base_color + grain + aggregate + wear + patch - tar_x;

	COLOR = vec4(col, 1.0);
}
