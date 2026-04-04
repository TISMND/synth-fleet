shader_type canvas_item;
// Neon Void Rift — Approach A: Perspective grid flowing into an elliptical void opening.
// Pink outrun neon rim, cloud wisps drifting around the rift edges.

uniform float hdr_intensity : hint_range(0.5, 8.0) = 3.0;
uniform vec3 bg_color : source_color = vec3(0.01, 0.0, 0.03);
uniform vec3 rift_color : source_color = vec3(1.0, 0.1, 0.55);
uniform vec3 cloud_color : source_color = vec3(0.6, 0.05, 0.35);
uniform float rift_width : hint_range(0.05, 0.4) = 0.18;
uniform float rift_height : hint_range(0.02, 0.25) = 0.08;
uniform float grid_freq : hint_range(1.0, 8.0) = 4.0;
uniform float grid_brightness : hint_range(0.5, 6.0) = 2.5;
uniform float cloud_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float scroll_speed : hint_range(0.0, 2.0) = 0.3;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
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
	float v = 0.0, a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * value_noise(p);
		p *= 2.1;
		a *= 0.45;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	float ar = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 center = vec2(0.5, 0.45);
	vec2 d = vec2((uv.x - center.x) * ar, uv.y - center.y);
	vec3 col = bg_color;

	// ── Rift ellipse ──
	float ex = d.x / rift_width;
	float ey = d.y / rift_height;
	float rift_dist = length(vec2(ex, ey));
	float rift_edge = smoothstep(1.0, 0.85, rift_dist);
	float rift_rim = smoothstep(0.7, 1.0, rift_dist) * smoothstep(1.4, 1.0, rift_dist);

	// Rift interior — deep void with subtle inner glow
	if (rift_dist < 1.0) {
		float inner = smoothstep(1.0, 0.3, rift_dist);
		col = mix(bg_color * 0.3, vec3(0.02, 0.0, 0.01), inner);
		// Inner swirl
		float angle = atan(d.y, d.x);
		float swirl = sin(angle * 3.0 + TIME * 0.5 + rift_dist * 8.0) * 0.5 + 0.5;
		col += rift_color * swirl * inner * 0.15 * hdr_intensity;
	}

	// Neon rim glow
	col += rift_color * rift_rim * hdr_intensity * 1.5;

	// Secondary softer glow halo
	float halo = exp(-max(rift_dist - 1.0, 0.0) * 4.0) * 0.6;
	col += rift_color * halo * hdr_intensity * 0.4;

	// ── Perspective grid (below rift, extending outward) ──
	float v_dist = uv.y - center.y - rift_height * 0.5;
	if (v_dist > 0.01) {
		float persp = 0.8 / max(v_dist, 0.001);
		float wx = (uv.x - 0.5) * persp;
		float wz = persp + TIME * scroll_speed;

		float gx = abs(fract(wx * grid_freq) - 0.5);
		float gz = abs(fract(wz * grid_freq) - 0.5);
		float fwx = fwidth(wx * grid_freq);
		float fwz = fwidth(wz * grid_freq);

		float density_x = 1.0 / max(fwx * 2.0, 1.0);
		float density_z = 1.0 / max(fwz * 2.0, 1.0);

		float line_w = 0.008;
		float core_x = 1.0 - smoothstep(line_w - fwx * 0.5, line_w + fwx * 0.5, gx);
		float core_z = 1.0 - smoothstep(line_w - fwz * 0.5, line_w + fwz * 0.5, gz);
		float core = max(core_x * density_x, core_z * density_z);

		float bloom_w = 0.05;
		float bloom_x = 1.0 - smoothstep(line_w, bloom_w + fwx, gx);
		float bloom_z = 1.0 - smoothstep(line_w, bloom_w + fwz, gz);
		float bloom = max(bloom_x * density_x, bloom_z * density_z);

		float fade = smoothstep(0.0, 0.05, v_dist) * smoothstep(0.55, 0.15, v_dist);
		// Fade grid near rift center
		float cx_dist = abs(uv.x - 0.5);
		float corridor_fade = smoothstep(0.0, 0.12, cx_dist + v_dist * 0.5);

		col += rift_color * bloom * grid_brightness * hdr_intensity * 0.3 * fade * corridor_fade;
		col += vec3(1.0, 0.8, 0.9) * core * grid_brightness * hdr_intensity * 0.5 * fade * corridor_fade;
	}

	// Also grid above (mirrored)
	float v_top = center.y - rift_height * 0.5 - uv.y;
	if (v_top > 0.01) {
		float persp = 0.8 / max(v_top, 0.001);
		float wx = (uv.x - 0.5) * persp;
		float wz = persp + TIME * scroll_speed;

		float gx = abs(fract(wx * grid_freq) - 0.5);
		float gz = abs(fract(wz * grid_freq) - 0.5);
		float fwx = fwidth(wx * grid_freq);
		float fwz = fwidth(wz * grid_freq);
		float density_x = 1.0 / max(fwx * 2.0, 1.0);
		float density_z = 1.0 / max(fwz * 2.0, 1.0);

		float line_w = 0.008;
		float core_x = 1.0 - smoothstep(line_w - fwx * 0.5, line_w + fwx * 0.5, gx);
		float core_z = 1.0 - smoothstep(line_w - fwz * 0.5, line_w + fwz * 0.5, gz);
		float core = max(core_x * density_x, core_z * density_z);

		float bloom_w = 0.05;
		float bloom_x = 1.0 - smoothstep(line_w, bloom_w + fwx, gx);
		float bloom_z = 1.0 - smoothstep(line_w, bloom_w + fwz, gz);
		float bloom = max(bloom_x * density_x, bloom_z * density_z);

		float fade = smoothstep(0.0, 0.05, v_top) * smoothstep(0.45, 0.1, v_top);
		float corridor_fade = smoothstep(0.0, 0.12, abs(uv.x - 0.5) + v_top * 0.5);
		col += rift_color * bloom * grid_brightness * hdr_intensity * 0.15 * fade * corridor_fade;
		col += vec3(1.0, 0.8, 0.9) * core * grid_brightness * hdr_intensity * 0.25 * fade * corridor_fade;
	}

	// ── Cloud wisps around rift ──
	if (cloud_intensity > 0.001) {
		vec2 neb_uv = uv * 4.0 + vec2(TIME * 0.02, TIME * 0.015);
		float neb = fbm(neb_uv) * fbm(neb_uv * 1.3 + 5.7);
		neb = smoothstep(0.1, 0.4, neb);
		// Concentrate near rift
		float prox = smoothstep(2.5, 0.8, rift_dist);
		float outside = smoothstep(0.9, 1.3, rift_dist);
		neb *= prox * outside * cloud_intensity;
		col += cloud_color * neb * hdr_intensity * 0.8;
	}

	// ── Stars ──
	for (int layer = 0; layer < 2; layer++) {
		float gs = (layer == 0) ? 90.0 : 140.0;
		float lo = float(layer) * 300.0;
		vec2 cell = floor(uv * vec2(gs, gs * 0.5));
		float h = hash(cell + lo);
		if (h > 0.94) {
			vec2 soff = vec2(hash(cell + lo + 111.0), hash(cell + lo + 222.0));
			vec2 sp = (cell + soff) / vec2(gs, gs * 0.5);
			float d_star = length((uv - sp) * vec2(ar, 1.0));
			float tw = 0.7 + 0.3 * sin(TIME * (1.0 + h * 3.0) + h * 6.283);
			float star = exp(-d_star * d_star / 0.000004) * tw;
			star *= smoothstep(0.0, 1.5, rift_dist); // dim near rift
			col += vec3(0.7, 0.8, 1.0) * star * 1.5;
		}
	}

	COLOR = vec4(col, 1.0);
}
