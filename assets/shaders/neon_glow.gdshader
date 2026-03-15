shader_type canvas_item;

uniform float glow_radius : hint_range(1.0, 20.0) = 4.0;
uniform float glow_intensity : hint_range(0.0, 5.0) = 2.0;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.08;
uniform float scanline_spacing : hint_range(1.0, 8.0) = 2.0;

void fragment() {
	vec2 ps = TEXTURE_PIXEL_SIZE;
	vec4 src = texture(TEXTURE, UV);

	// Sample surrounding pixels for bloom
	vec4 bloom = vec4(0.0);
	float total_weight = 0.0;
	int radius = int(glow_radius);
	for (int x = -radius; x <= radius; x++) {
		for (int y = -radius; y <= radius; y++) {
			float dist = length(vec2(float(x), float(y)));
			if (dist > glow_radius) continue;
			float w = exp(-dist * dist / (glow_radius * 0.8));
			vec4 s = texture(TEXTURE, UV + vec2(float(x), float(y)) * ps);
			// Only bloom bright pixels (the neon lines)
			float brightness = max(s.r, max(s.g, s.b)) * s.a;
			bloom += s * w * brightness;
			total_weight += w;
		}
	}
	bloom /= total_weight;

	// Combine source with glow
	vec4 result = src + bloom * glow_intensity;

	// Scanline overlay
	float scanline = 1.0 - scanline_strength * step(0.5, fract(FRAGCOORD.y / scanline_spacing));
	result.rgb *= scanline;

	COLOR = result;
}
