shader_type canvas_item;

uniform vec4 weapon_color : source_color = vec4(0.4, 0.8, 1.0, 1.0);
uniform float crystal_density : hint_range(2.0, 10.0) = 5.0;
uniform float shimmer_speed : hint_range(0.5, 4.0) = 2.0;
uniform float fracture_sharpness : hint_range(0.5, 3.0) = 1.5;
uniform sampler2D mask_texture : hint_default_white;
uniform bool use_mask = false;

// Universal params
uniform float brightness : hint_range(0.5, 4.0) = 1.0;
uniform float color_mix : hint_range(0.0, 1.0) = 0.0;
uniform float animation_speed : hint_range(0.1, 3.0) = 1.0;
uniform float edge_softness : hint_range(0.0, 1.0) = 0.5;

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

// Voronoi-like cell distance for crystal facets
vec2 voronoi(vec2 p) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	float md = 8.0;
	float md2 = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = vec2(hash(n + g), hash(n + g + vec2(17.0, 31.0)));
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < md) {
				md2 = md;
				md = d;
			} else if (d < md2) {
				md2 = d;
			}
		}
	}
	return vec2(sqrt(md), sqrt(md2));
}

void fragment() {
	float modulate_alpha = COLOR.a;
	float t = TIME * animation_speed;
	vec2 uv = UV - 0.5;
	float dist = length(uv) * 2.0;

	// Crystal facet pattern
	vec2 crystal_uv = UV * crystal_density;
	vec2 vor = voronoi(crystal_uv);
	float edges = smoothstep(0.0, 0.15 / fracture_sharpness, vor.y - vor.x);

	// Shimmer — traveling bright spots along facet edges
	float shimmer = noise(crystal_uv * 2.0 + t * shimmer_speed);
	shimmer = pow(shimmer, 2.0) * (1.0 - edges);

	// Inner glow
	float core = smoothstep(0.9, 0.1, dist);

	// Fracture lines glow bright
	float fracture_glow = (1.0 - edges) * fracture_sharpness * 0.5;

	// Combine
	float intensity = (core * 0.6 + fracture_glow * 0.8 + shimmer * 0.6);

	vec3 base_col = mix(weapon_color.rgb, vec3(1.0), color_mix);
	vec3 col = base_col * intensity * 2.0 * brightness;
	col += vec3(0.8, 0.95, 1.0) * shimmer * 0.5; // white shimmer highlights
	col += vec3(1.0) * fracture_glow * 0.3; // bright fracture lines

	float soft = mix(0.6, 0.95, edge_softness);
	float alpha = smoothstep(1.0, soft, dist) * weapon_color.a;

	if (use_mask) {
		float mask_alpha = texture(mask_texture, UV).a;
		alpha *= mask_alpha;
	}

	COLOR = vec4(col, alpha * modulate_alpha);
}
