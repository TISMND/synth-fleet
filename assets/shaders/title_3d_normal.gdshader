shader_type canvas_item;
// TECHNIQUE: Normal-from-alpha lighting (Blinn-Phong on text)
//
// Estimates a surface normal at every pixel by taking the Sobel gradient of
// the glyph's alpha channel (8 neighbour samples). Interior pixels have a
// flat alpha → normal points straight up (0,0,1). Near edges, alpha drops
// off directionally → normal tilts outward. Shading this pseudo-normal with
// a directional light (diffuse + Blinn-Phong specular) gives real 3D feel
// on flat text without any geometry.
//
// This is the workhorse technique for fake-3D metallic text. Pair with an
// MSDF font for clean gradients and the effect gets noticeably better.

// ── Material colors ────────────────────────────────────────────────
uniform vec4 base_color : source_color = vec4(0.06, 0.10, 0.20, 1.0);
uniform vec4 highlight_color : source_color = vec4(0.65, 0.82, 1.00, 1.0);
uniform vec4 specular_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// ── Light direction (polar: angle around glyph + elevation above) ──
uniform float light_angle : hint_range(0.0, 6.28) = 2.36;      // radians, 0=right, pi/2=down
uniform float light_elevation : hint_range(0.05, 1.0) = 0.5;  // 0=grazing, 1=straight-on

// ── Lighting response ──────────────────────────────────────────────
uniform float ambient : hint_range(0.0, 2.0) = 0.55;
uniform float diffuse_strength : hint_range(0.0, 2.0) = 1.2;
uniform float specular_strength : hint_range(0.0, 4.0) = 1.8;
uniform float specular_power : hint_range(1.0, 256.0) = 48.0;

// ── Normal estimation ──────────────────────────────────────────────
uniform float normal_sample_radius : hint_range(0.5, 8.0) = 2.5;  // pixels
uniform float depth_scale : hint_range(0.1, 16.0) = 3.0;          // edge tilt strength

uniform float hdr_boost : hint_range(1.0, 4.0) = 1.3;

void fragment() {
	vec2 ps = SCREEN_PIXEL_SIZE;
	float center_a = texture(TEXTURE, UV).a * COLOR.a;
	if (center_a < 0.005) {
		discard;
	}

	// 8-tap Sobel gradient on alpha
	float r = normal_sample_radius;
	float a_l  = texture(TEXTURE, UV + vec2(-r,  0.0) * ps).a;
	float a_rr = texture(TEXTURE, UV + vec2( r,  0.0) * ps).a;
	float a_t  = texture(TEXTURE, UV + vec2( 0.0, -r) * ps).a;
	float a_b  = texture(TEXTURE, UV + vec2( 0.0,  r) * ps).a;
	float a_tl = texture(TEXTURE, UV + vec2(-r, -r) * ps).a;
	float a_tr = texture(TEXTURE, UV + vec2( r, -r) * ps).a;
	float a_bl = texture(TEXTURE, UV + vec2(-r,  r) * ps).a;
	float a_br = texture(TEXTURE, UV + vec2( r,  r) * ps).a;

	float dx = (a_tr + 2.0 * a_rr + a_br) - (a_tl + 2.0 * a_l + a_bl);
	float dy = (a_bl + 2.0 * a_b  + a_br) - (a_tl + 2.0 * a_t + a_tr);

	// Pseudo-normal: up in interior, curved outward at edges
	vec3 N = normalize(vec3(-dx * depth_scale, -dy * depth_scale, 1.0));

	// Light direction from polar params
	vec2 Lxy = vec2(cos(light_angle), sin(light_angle)) * (1.0 - light_elevation);
	vec3 L = normalize(vec3(Lxy.x, Lxy.y, light_elevation));

	// Diffuse (Lambert)
	float NdotL = max(dot(N, L), 0.0);

	// Specular (Blinn-Phong)
	vec3 V = vec3(0.0, 0.0, 1.0);
	vec3 H = normalize(L + V);
	float NdotH = max(dot(N, H), 0.0);
	float spec = pow(NdotH, specular_power) * specular_strength;

	vec3 col = base_color.rgb * ambient
		+ highlight_color.rgb * NdotL * diffuse_strength
		+ specular_color.rgb * spec;
	col *= hdr_boost;

	COLOR = vec4(col, center_a);
}
