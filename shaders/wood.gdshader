shader_type spatial;
render_mode specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.32, 0.21, 0.12, 1.0);
uniform vec4 grain_color : source_color = vec4(0.19, 0.11, 0.055, 1.0);
uniform float plank_width = 0.18;
uniform float plank_length = 1.75;
uniform bool planked = true;
uniform float grain_strength : hint_range(0.0, 1.0) = 0.58;
uniform float roughness_amount : hint_range(0.0, 1.0) = 0.92;
varying vec3 world_position;
varying vec3 world_normal;

float hash21(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec2 timber_plane(vec3 p, vec3 n) {
	vec3 a = abs(n);
	// Horizontal faces run fore-to-aft. Vertical hull planks run horizontally.
	if (a.y > a.x && a.y > a.z) { return p.zx; }
	if (a.x > a.z) { return p.zy; }
	return p.xy;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec2 plane = timber_plane(world_position, world_normal);
	float width = max(plank_width, 0.05);
	float length_m = max(plank_length, 0.4);
	float row = floor(plane.y / width);
	float shift = hash21(vec2(row, 6.4)) * length_m;
	float column = floor((plane.x + shift) / length_m);
	vec2 board_id = vec2(column, row);
	float seed = hash21(board_id + vec2(13.7, 4.8));
	vec2 local = vec2(mod(plane.x + shift, length_m), mod(plane.y, width));
	vec2 grain_position = local;
	if (!planked) {
		grain_position = plane;
		seed = 0.37;
	}
	// Long, wandering growth rings with broad irregular stain, not fine stripes.
	vec2 wood_uv = grain_position + vec2(seed * 7.2, seed * 4.7);
	float warp = noise2(wood_uv * vec2(0.7, 8.0)) * 5.8;
	warp += noise2(wood_uv * vec2(1.5, 3.0)) * 2.1;
	vec2 growth_center = vec2(length_m * (0.22 + seed * 0.65), -width * (0.3 + seed));
	vec2 growth = (grain_position - growth_center) * vec2(0.16, 1.0);
	float phase = length(growth) * 205.0 + warp;
	float grain_aa = 1.0 - smoothstep(0.65, 2.4, length(vec2(dFdx(phase), dFdy(phase))));
	float fibres = noise2(vec2(wood_uv.x * 1.3, wood_uv.y * 53.0 + warp));
	float rings = (sin(phase) * 0.36 + (fibres - 0.5) * 0.7) * grain_aa;
	float broad = noise2(wood_uv * vec2(1.1, 17.0));
	float stain = noise2(plane * vec2(0.46, 1.8));
	float knot = 0.0;
	if (planked) {
		vec2 knot_center = vec2(length_m * (0.2 + seed * 0.58), width * (0.25 + hash21(board_id + 1.3) * 0.5));
		vec2 knot_delta = (local - knot_center) * vec2(0.48, 1.8);
		float knot_radius = length(knot_delta);
		float present = step(0.68, hash21(board_id + 9.1));
		float knot_falloff = (1.0 - smoothstep(0.025, 0.14, knot_radius)) * present;
		float knot_phase = knot_radius * 170.0;
		float knot_aa = 1.0 - smoothstep(0.6, 2.2, fwidth(knot_phase));
		rings = mix(rings, sin(knot_phase) * 0.38 * knot_aa, knot_falloff * 0.68);
		knot = (1.0 - smoothstep(0.005, 0.026, knot_radius)) * present * 0.15;
	}
	float grain = clamp(0.34 + rings * 0.48 + (broad - 0.5) * 0.32 + knot, 0.05, 0.85);
	vec3 color = mix(base_color.rgb, grain_color.rgb, grain * grain_strength);
	color *= 0.94 + stain * 0.09;
	if (planked) {
		color *= 0.92 + seed * 0.16;
		float edge_distance = min(min(local.x, length_m - local.x), min(local.y, width - local.y));
		float footprint = max(length(dFdx(plane)), length(dFdy(plane)));
		float aa = max(footprint * 0.7, 0.00035);
		float seam = 1.0 - smoothstep(0.0010 - aa, 0.0017 + aa, edge_distance);
		// Fade hairline seams before they become a distant dark shimmering grid.
		seam *= 1.0 - smoothstep(0.018, 0.07, footprint);
		color *= 1.0 - seam * 0.36;
	}
	ALBEDO = color;
	METALLIC = 0.0;
	ROUGHNESS = clamp(roughness_amount + (stain - 0.5) * 0.035, 0.85, 1.0);
	SPECULAR = 0.12;
}
