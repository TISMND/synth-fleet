shader_type canvas_item;
// Mid-layer scrolling background: top-down city district.
// Hierarchical grid: avenues → streets → building plots.
// Streets always connect. Buildings respect roads. Blocks have types.
// Aimed at looking intentional/designed, not random noise.

uniform vec4 road_color : source_color = vec4(0.04, 0.04, 0.05, 1.0);
uniform vec4 sidewalk_color : source_color = vec4(0.07, 0.07, 0.08, 1.0);
uniform vec4 building_base : source_color = vec4(0.1, 0.1, 0.12, 1.0);
uniform vec4 building_dark : source_color = vec4(0.06, 0.06, 0.07, 1.0);
uniform vec4 building_light : source_color = vec4(0.14, 0.13, 0.15, 1.0);
uniform vec4 park_color : source_color = vec4(0.02, 0.06, 0.03, 1.0);
uniform vec4 marking_color : source_color = vec4(0.15, 0.15, 0.12, 0.5);
uniform vec4 window_color : source_color = vec4(0.18, 0.16, 0.08, 0.7);
uniform vec4 light_color : source_color = vec4(0.9, 0.7, 0.3, 0.5);
uniform float scroll_speed : hint_range(0.0, 200.0) = 30.0;
uniform float avenue_spacing : hint_range(150.0, 500.0) = 280.0;
uniform float street_subdivisions : hint_range(2.0, 5.0) = 3.0;
uniform float avenue_width : hint_range(10.0, 40.0) = 22.0;
uniform float street_width : hint_range(6.0, 20.0) = 12.0;
uniform float building_setback : hint_range(2.0, 10.0) = 4.0;
uniform float night_glow : hint_range(0.0, 1.0) = 0.6;
uniform bool manual_scroll = false;
uniform float scroll_offset : hint_range(0.0, 100000.0) = 0.0;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec2 pmod(vec2 x, float s) {
	return fract(x / s) * s;
}

float pmod1(float x, float s) {
	return fract(x / s) * s;
}

void fragment() {
	vec2 uv = FRAGCOORD.xy;
	float y_scroll = manual_scroll ? -scroll_offset : -TIME * scroll_speed;
	vec2 pos = uv + vec2(0.0, y_scroll);

	// ═══════════════════════════════════════════
	// LEVEL 1: Avenue grid (major roads)
	// ═══════════════════════════════════════════
	vec2 ave_cell = floor(pos / avenue_spacing);
	vec2 ave_local = pmod(pos, avenue_spacing);
	float ave_hash = hash21(ave_cell);
	float ave_hash2 = hash21(ave_cell + vec2(7.0, 13.0));

	// Distance to nearest avenue (horizontal and vertical)
	float ave_dx = min(ave_local.x, avenue_spacing - ave_local.x);
	float ave_dy = min(ave_local.y, avenue_spacing - ave_local.y);
	float half_ave = avenue_width * 0.5;

	float on_h_avenue = step(ave_dy, half_ave);
	float on_v_avenue = step(ave_dx, half_ave);
	float on_avenue = max(on_h_avenue, on_v_avenue);

	// Sidewalk zone (just outside road)
	float sidewalk_w = 3.0;
	float near_h_ave = step(ave_dy, half_ave + sidewalk_w) * (1.0 - step(ave_dy, half_ave));
	float near_v_ave = step(ave_dx, half_ave + sidewalk_w) * (1.0 - step(ave_dx, half_ave));
	float on_ave_sidewalk = max(near_h_ave, near_v_ave) * (1.0 - on_avenue);

	// Road markings on avenues
	float ave_marking = 0.0;
	// Center line (dashed)
	if (on_h_avenue > 0.5) {
		float center_d = abs(ave_dy - 0.5); // distance from exact center
		float dash = step(pmod1(pos.x, 20.0), 12.0);
		ave_marking = (1.0 - smoothstep(0.0, 1.0, center_d)) * dash * 0.4;
	}
	if (on_v_avenue > 0.5) {
		float center_d = abs(ave_dx - 0.5);
		float dash = step(pmod1(pos.y, 20.0), 12.0);
		ave_marking = max(ave_marking, (1.0 - smoothstep(0.0, 1.0, center_d)) * dash * 0.4);
	}

	// ═══════════════════════════════════════════
	// LEVEL 2: Street grid within avenue blocks
	// ═══════════════════════════════════════════
	// Interior of avenue block (excluding avenues themselves)
	float block_interior_x = ave_local.x - half_ave - sidewalk_w;
	float block_interior_y = ave_local.y - half_ave - sidewalk_w;
	float block_w = avenue_spacing - avenue_width - sidewalk_w * 2.0;

	float street_sp = block_w / street_subdivisions;
	float half_street = street_width * 0.5;

	// Street distance within block
	float st_local_x = pmod1(block_interior_x, street_sp);
	float st_local_y = pmod1(block_interior_y, street_sp);
	float st_dx = min(st_local_x, street_sp - st_local_x);
	float st_dy = min(st_local_y, street_sp - st_local_y);

	// Some streets are missing (not all subdivisions have cross streets)
	vec2 st_cell = floor(vec2(block_interior_x, block_interior_y) / street_sp);
	float st_h_on = step(0.25, hash21(st_cell + ave_cell * 10.0 + vec2(0.0, 5.0)));
	float st_v_on = step(0.3, hash21(st_cell + ave_cell * 10.0 + vec2(5.0, 0.0)));

	float on_h_street = step(st_dy, half_street) * st_h_on;
	float on_v_street = step(st_dx, half_street) * st_v_on;
	float on_street = max(on_h_street, on_v_street);

	// Only count streets inside the block interior
	float in_block = step(0.0, block_interior_x) * step(block_interior_x, block_w)
		* step(0.0, block_interior_y) * step(block_interior_y, block_w);
	on_street *= in_block * (1.0 - on_avenue) * (1.0 - on_ave_sidewalk);

	// Street sidewalks
	float st_sidewalk_w = 2.0;
	float near_h_st = step(st_dy, half_street + st_sidewalk_w) * (1.0 - step(st_dy, half_street)) * st_h_on;
	float near_v_st = step(st_dx, half_street + st_sidewalk_w) * (1.0 - step(st_dx, half_street)) * st_v_on;
	float on_st_sidewalk = max(near_h_st, near_v_st) * in_block * (1.0 - on_avenue) * (1.0 - on_ave_sidewalk) * (1.0 - on_street);

	float on_any_road = max(on_avenue, on_street);
	float on_any_sidewalk = max(on_ave_sidewalk, on_st_sidewalk);

	// ═══════════════════════════════════════════
	// LEVEL 3: Block type + building footprints
	// ═══════════════════════════════════════════
	// Each city block (area between streets) has a type
	vec2 city_block = floor(vec2(block_interior_x, block_interior_y) / street_sp) + ave_cell * 10.0;
	float block_type_hash = hash21(city_block);
	// 0=residential(dense small), 1=commercial(medium), 2=park, 3=parking, 4=large building
	float block_type = 0.0;
	if (block_type_hash > 0.88) { block_type = 2.0; }       // park
	else if (block_type_hash > 0.82) { block_type = 3.0; }  // parking lot
	else if (block_type_hash > 0.65) { block_type = 4.0; }  // large single building
	else if (block_type_hash > 0.35) { block_type = 1.0; }  // commercial
	// else 0 = residential

	// Building plot coordinates (within a city block)
	float plot_area = street_sp - street_width - st_sidewalk_w * 2.0;
	float plot_offset_x = st_local_x - half_street - st_sidewalk_w;
	float plot_offset_y = st_local_y - half_street - st_sidewalk_w;
	float in_plot_area = step(0.0, plot_offset_x) * step(plot_offset_x, plot_area)
		* step(0.0, plot_offset_y) * step(plot_offset_y, plot_area)
		* in_block * (1.0 - on_any_road) * (1.0 - on_any_sidewalk);

	float building = 0.0;
	float building_shade = 0.5; // 0=dark, 1=light
	float rooftop_detail = 0.0;
	float park = 0.0;
	float parking = 0.0;
	float windows = 0.0;

	if (block_type < 0.5 && in_plot_area > 0.5) {
		// RESIDENTIAL: subdivide plot into small buildings
		float res_sp = max(plot_area / 3.0, 12.0);
		vec2 res_local = vec2(pmod1(plot_offset_x, res_sp), pmod1(plot_offset_y, res_sp));
		vec2 res_cell = floor(vec2(plot_offset_x, plot_offset_y) / res_sp);
		float res_hash = hash21(res_cell + city_block * 7.0);
		float setback = building_setback + res_hash * 2.0;
		float in_bldg = step(setback, res_local.x) * step(res_local.x, res_sp - setback * 0.5)
			* step(setback, res_local.y) * step(res_local.y, res_sp - setback * 0.5);
		building = in_bldg * step(0.1, res_hash); // some plots empty
		building_shade = res_hash;
		// Windows (small dots in grid)
		float win_sp = 4.0;
		float win = step(pmod1(res_local.x, win_sp), 1.5) * step(pmod1(res_local.y, win_sp), 1.5);
		windows = win * building * step(0.5, hash21(res_cell + vec2(33.0, 17.0)));

	} else if (block_type < 1.5 && in_plot_area > 0.5) {
		// COMMERCIAL: fewer, larger buildings
		float com_sp = max(plot_area / 2.0, 18.0);
		vec2 com_local = vec2(pmod1(plot_offset_x, com_sp), pmod1(plot_offset_y, com_sp));
		vec2 com_cell = floor(vec2(plot_offset_x, plot_offset_y) / com_sp);
		float com_hash = hash21(com_cell + city_block * 11.0);
		float setback = building_setback;
		building = step(setback, com_local.x) * step(com_local.x, com_sp - setback)
			* step(setback, com_local.y) * step(com_local.y, com_sp - setback);
		building *= step(0.15, com_hash);
		building_shade = 0.3 + com_hash * 0.4;
		// Rooftop AC units
		float ac_x = abs(com_local.x - com_sp * 0.3) ;
		float ac_y = abs(com_local.y - com_sp * 0.3);
		rooftop_detail = step(max(ac_x, ac_y), 3.0) * building * 0.4;
		// Window grid
		float win_sp = 5.0;
		windows = step(pmod1(com_local.x, win_sp), 1.8) * step(pmod1(com_local.y, win_sp), 1.8)
			* building * 0.7;

	} else if (block_type < 2.5 && in_plot_area > 0.5) {
		// PARK: organic shapes, darker green
		park = in_plot_area;
		// Tree canopy circles
		float tree_sp = 14.0;
		vec2 tree_local = vec2(pmod1(plot_offset_x, tree_sp), pmod1(plot_offset_y, tree_sp));
		float tree_d = length(tree_local - vec2(tree_sp * 0.5));
		float tree_hash = hash21(floor(vec2(plot_offset_x, plot_offset_y) / tree_sp) + city_block);
		float tree = (1.0 - smoothstep(3.0, 5.0, tree_d)) * step(0.3, tree_hash);
		park += tree * 0.3;
		// Path through park
		float path_d = abs(plot_offset_x - plot_area * 0.5);
		park -= step(path_d, 2.5) * 0.5;

	} else if (block_type < 3.5 && in_plot_area > 0.5) {
		// PARKING LOT: regular parallel lines
		float lot_line_sp = 8.0;
		float lot_line = step(pmod1(plot_offset_x, lot_line_sp), 1.0);
		parking = in_plot_area * 0.3;
		parking += lot_line * 0.15;
		// Occasional car (small rectangle)
		float car_sp_x = lot_line_sp;
		float car_sp_y = 12.0;
		vec2 car_local = vec2(pmod1(plot_offset_x, car_sp_x), pmod1(plot_offset_y, car_sp_y));
		vec2 car_cell = floor(vec2(plot_offset_x / car_sp_x, plot_offset_y / car_sp_y));
		float car_on = step(0.4, hash21(car_cell + city_block * 3.0));
		float car = step(2.0, car_local.x) * step(car_local.x, car_sp_x - 1.0)
			* step(2.0, car_local.y) * step(car_local.y, 8.0) * car_on;
		parking += car * 0.2;

	} else if (block_type > 3.5 && in_plot_area > 0.5) {
		// LARGE BUILDING: single structure filling most of the plot
		float lg_setback = building_setback * 1.5;
		building = step(lg_setback, plot_offset_x) * step(plot_offset_x, plot_area - lg_setback)
			* step(lg_setback, plot_offset_y) * step(plot_offset_y, plot_area - lg_setback);
		building_shade = 0.2; // darker = taller
		// Helipad circle on some
		float hp_hash = hash21(city_block + vec2(99.0, 77.0));
		if (hp_hash > 0.6) {
			float hp_d = length(vec2(plot_offset_x, plot_offset_y) - vec2(plot_area * 0.5));
			float helipad = (1.0 - smoothstep(6.0, 8.0, hp_d))
				- (1.0 - smoothstep(4.0, 6.0, hp_d));
			rooftop_detail = max(rooftop_detail, max(helipad, 0.0) * building * 0.5);
			// H marking
			float hx = abs(plot_offset_x - plot_area * 0.5);
			float hy = abs(plot_offset_y - plot_area * 0.5);
			float h_mark = step(hx, 1.0) * step(hy, 4.0) + step(hy, 1.0) * step(hx, 3.0);
			rooftop_detail = max(rooftop_detail, h_mark * (1.0 - smoothstep(5.0, 7.0, hp_d)) * building * 0.3);
		}
		// Facade lines
		float facade = step(pmod1(plot_offset_y, 6.0), 0.8) * building * 0.08;
		rooftop_detail = max(rooftop_detail, facade);
	}

	// ═══════════════════════════════════════════
	// Street lights (dots at intersections)
	// ═══════════════════════════════════════════
	float street_light = 0.0;
	if (night_glow > 0.01) {
		// Lights at avenue intersections
		vec2 ave_corner = round(pos / avenue_spacing) * avenue_spacing;
		float light_d = length(pos - ave_corner);
		street_light = exp(-light_d * light_d / 200.0) * 0.4;
		// Lights along avenues
		float lamp_sp = 60.0;
		if (on_h_avenue > 0.5) {
			float lamp_x = pmod1(pos.x, lamp_sp);
			float lamp_d = length(vec2(lamp_x - lamp_sp * 0.5, ave_dy - half_ave + 2.0));
			street_light = max(street_light, exp(-lamp_d * lamp_d / 30.0) * 0.25);
		}
		if (on_v_avenue > 0.5) {
			float lamp_y = pmod1(pos.y, lamp_sp);
			float lamp_d = length(vec2(ave_dx - half_ave + 2.0, lamp_y - lamp_sp * 0.5));
			street_light = max(street_light, exp(-lamp_d * lamp_d / 30.0) * 0.25);
		}
	}

	// ═══════════════════════════════════════════
	// COMPOSE
	// ═══════════════════════════════════════════
	vec3 col = road_color.rgb;

	// Sidewalks
	col = mix(col, sidewalk_color.rgb, on_any_sidewalk);

	// Road markings
	col += marking_color.rgb * ave_marking * on_avenue;

	// Park
	col = mix(col, park_color.rgb, park * (1.0 - on_any_road) * (1.0 - on_any_sidewalk));

	// Parking lot
	col = mix(col, sidewalk_color.rgb * 0.8, parking * (1.0 - on_any_road) * (1.0 - on_any_sidewalk));

	// Buildings
	vec3 bldg_col = mix(building_dark.rgb, building_light.rgb, building_shade);
	// Add subtle per-building texture
	float bldg_tex = noise(pos * 0.3) * 0.02;
	bldg_col += vec3(bldg_tex);
	col = mix(col, bldg_col, building);

	// Rooftop details (slightly different shade)
	col = mix(col, building_dark.rgb * 0.8, rooftop_detail * building);

	// Windows (warm glow at night)
	col += window_color.rgb * windows * night_glow;

	// Street lights
	col += light_color.rgb * street_light * night_glow;

	COLOR = vec4(col, 1.0);
}
