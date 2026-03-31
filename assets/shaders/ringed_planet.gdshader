shader_type canvas_item;

uniform vec3 bg_color : source_color = vec3(0.01, 0.0, 0.04);
uniform float forced_aspect : hint_range(0.0, 3.0) = 0.0;

// ── Planet body ──
uniform float planet_radius : hint_range(0.05, 0.35) = 0.15;
uniform vec3 planet_color_top : source_color = vec3(1.0, 0.8, 0.3);
uniform vec3 planet_color_bot : source_color = vec3(0.9, 0.15, 0.08);
uniform float planet_hdr : hint_range(0.5, 4.0) = 2.0;

// ── Slices (planet) ──
uniform float slice_enabled : hint_range(0.0, 1.0) = 1.0;
uniform float slice_start : hint_range(0.1, 0.6) = 0.32;
uniform float slice_band_h : hint_range(0.02, 0.12) = 0.058;
uniform float slice_gap_base : hint_range(0.002, 0.03) = 0.005;
uniform float slice_gap_grow : hint_range(0.005, 0.04) = 0.015;

// ── Ring geometry ──
uniform float ring_inner : hint_range(0.08, 0.45) = 0.20;
uniform float ring_outer : hint_range(0.15, 0.55) = 0.35;
uniform float ring_tilt : hint_range(0.1, 0.8) = 0.3;
uniform float ring_angle : hint_range(-0.8, 0.8) = 0.35;
uniform vec3 ring_color : source_color = vec3(1.0, 0.4, 0.2);
uniform float ring_hdr : hint_range(0.5, 6.0) = 2.5;
uniform float ring_gap_pos : hint_range(0.1, 0.9) = 0.4;
uniform float ring_gap_width : hint_range(0.0, 0.15) = 0.03;
uniform float ring_bands : hint_range(2.0, 40.0) = 12.0;

// ── Ring slats (horizontal cuts through the rings) ──
uniform float ring_slats_enabled : hint_range(0.0, 1.0) = 1.0;
uniform float ring_slat_spacing : hint_range(0.005, 0.06) = 0.02;
uniform float ring_slat_thickness : hint_range(0.001, 0.02) = 0.004;

// ── Planet tilt ──
uniform float planet_tilted : hint_range(0.0, 1.0) = 0.0;

// ── Glow ──
uniform float atmo_glow : hint_range(0.0, 2.0) = 0.6;
uniform vec3 atmo_color : source_color = vec3(0.3, 0.7, 1.0);
uniform float ring_glow_size : hint_range(0.0, 0.03) = 0.008;

void fragment() {
	vec2 uv = UV;
	float ar = forced_aspect > 0.01 ? forced_aspect : SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec3 col = bg_color;

	vec2 center = vec2(0.5, 0.48);
	vec2 d = vec2((uv.x - center.x) * ar, uv.y - center.y);
	float pdist = length(d);
	bool on_planet = pdist < planet_radius;

	// Rotate into ring plane
	float ca = cos(ring_angle);
	float sa = sin(ring_angle);
	vec2 d_rot = vec2(d.x * ca - d.y * sa, d.x * sa + d.y * ca);

	float rdist = length(vec2(d_rot.x, d_rot.y / ring_tilt));
	bool in_ring = rdist > ring_inner && rdist < ring_outer;
	bool ring_front = d_rot.y > 0.0;

	// ── Ring band pattern ──
	float ring_alpha = 0.0;
	if (in_ring) {
		float ring_t = (rdist - ring_inner) / (ring_outer - ring_inner);
		ring_alpha = 1.0;
		// Cassini gap
		if (abs(ring_t - ring_gap_pos) < ring_gap_width * 0.5) {
			ring_alpha = 0.0;
		}
		// Density bands
		float band_val = sin(ring_t * ring_bands * 3.14159) * 0.5 + 0.5;
		ring_alpha *= 0.5 + band_val * 0.5;
		// Edge softness
		ring_alpha *= smoothstep(ring_inner, ring_inner + 0.005, rdist);
		ring_alpha *= smoothstep(ring_outer, ring_outer - 0.005, rdist);
	}

	// ── Ring slats (concentric dark gaps following ring curvature) ──
	float ring_slat_mask = 1.0;
	if (ring_slats_enabled > 0.5 && in_ring && ring_slat_spacing > 0.001) {
		float slat_pos = mod(rdist - ring_inner, ring_slat_spacing);
		if (slat_pos < ring_slat_thickness) {
			ring_slat_mask = 0.0;
		}
	}
	ring_alpha *= ring_slat_mask;

	// Ring glow
	float ring_glow_val = 0.0;
	if (ring_glow_size > 0.001) {
		float dist_inner = abs(rdist - ring_inner);
		float dist_outer = abs(rdist - ring_outer);
		float closest = in_ring ? 0.0 : min(dist_inner, dist_outer);
		ring_glow_val = exp(-closest / ring_glow_size) * 0.4;
		if (on_planet) { ring_glow_val *= 0.2; }
	}

	// Planet gradient direction
	float grad_y = (planet_tilted > 0.5) ? d_rot.y : d.y;
	float ny = (grad_y + planet_radius) / (2.0 * planet_radius);

	// ── Ring behind planet ──
	if (in_ring && !ring_front && !on_planet) {
		col = mix(col, ring_color * ring_hdr * 0.5, ring_alpha);
	}
	if (!ring_front && !on_planet) {
		col += ring_color * ring_glow_val * ring_hdr * 0.3;
	}

	// ── Planet body ──
	if (on_planet) {
		vec3 pcol = mix(planet_color_top, planet_color_bot, clamp(ny, 0.0, 1.0));

		// Terminator shadow
		float shadow = smoothstep(-0.35, 0.45, -d.x / planet_radius);
		shadow *= smoothstep(0.9, 0.3, ny);
		pcol *= 0.15 + 0.85 * shadow;

		// Planet slices — stark black cuts
		if (slice_enabled > 0.5 && ny > slice_start) {
			float region = (ny - slice_start) / (1.0 - slice_start);
			float y_acc = 0.0;
			for (int i = 0; i < 9; i++) {
				float gap_h = slice_gap_base + float(i) * slice_gap_grow;
				y_acc += slice_band_h;
				if (region >= y_acc && region < y_acc + gap_h) {
					pcol = bg_color;
					break;
				}
				y_acc += gap_h;
				if (y_acc > 1.0) break;
			}
		}

		float rim = smoothstep(0.5, 1.0, pdist / planet_radius);
		pcol += atmo_color * rim * atmo_glow;

		float edge = smoothstep(planet_radius, planet_radius - 0.003, pdist);
		col = mix(col, pcol * planet_hdr, edge);
	}

	// ── Ring in front ──
	if (in_ring && ring_front) {
		float front_alpha = ring_alpha;
		if (on_planet) { front_alpha *= 0.85; }
		col = mix(col, ring_color * ring_hdr, front_alpha);
	}
	if (ring_front || !on_planet) {
		col += ring_color * ring_glow_val * ring_hdr * 0.5;
	}

	// ── Atmosphere halo ──
	float atmo = exp(-pdist * 5.5 / planet_radius) * atmo_glow;
	col += atmo_color * atmo;

	COLOR = vec4(col, 1.0);
}
