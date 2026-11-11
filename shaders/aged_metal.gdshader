shader_type spatial;
render_mode specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.16, 0.22, 0.23, 1.0);
uniform vec4 wear_color : source_color = vec4(0.29, 0.31, 0.28, 1.0);
uniform float metallic_amount : hint_range(0.0, 1.0) = 0.35;
uniform float roughness_amount : hint_range(0.0, 1.0) = 0.86;
uniform float weathering : hint_range(0.0, 1.0) = 0.3;
uniform float bump_strength : hint_range(0.0, 1.0) = 0.025;
uniform bool tread_plate = false;
uniform bool hazard_stripe = false;
varying vec3 world_position;
varying vec3 world_normal;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash31(i), hash31(i + vec3(1,0,0)), f.x),
		mix(hash31(i + vec3(0,1,0)), hash31(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash31(i + vec3(0,0,1)), hash31(i + vec3(1,0,1)), f.x),
		mix(hash31(i + vec3(0,1,1)), hash31(i + vec3(1,1,1)), f.x), f.y), f.z);
}

vec2 surface_plane(vec3 p, vec3 n) {
	vec3 a = abs(n);
	if (a.y > a.x && a.y > a.z) { return p.xz; }
	if (a.x > a.z) { return p.zy; }
	return p.xy;
}

float tread(vec2 p) {
	vec2 cell = floor(p / 0.19);
	vec2 q = fract(p / 0.19) - 0.5;
	float side = mod(cell.x + cell.y, 2.0) * 2.0 - 1.0;
	q = vec2(q.x + q.y * side, -q.x * side + q.y) * 0.7071;
	vec2 d = abs(q) - vec2(0.29, 0.055);
	float sdf = length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
	return 1.0 - smoothstep(0.015, 0.075, sdf);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 p = world_position;
	vec2 plane = surface_plane(p, world_normal);
	float broad = noise3(p * 0.82);
	float grain = noise3(p * 12.0);
	float scuff = noise3(p * vec3(8.0, 21.0, 7.0));
	float grime = smoothstep(0.34, 0.78, broad);
	float scratches = smoothstep(0.62, 0.88, scuff) * weathering * 0.16;
	vec3 col = base_color.rgb * (0.98 + grain * 0.025);
	col = mix(col, col * vec3(0.49, 0.43, 0.35), grime * weathering * 0.52);
	col = mix(col, wear_color.rgb, scratches * 0.45);
	float height = grain * 0.0001 + scuff * 0.00004;
	float rough = roughness_amount + (grime - 0.5) * 0.055;
	if (tread_plate) {
		float footprint = max(length(dFdx(plane)), length(dFdy(plane)));
		float detail_visibility = 1.0 - smoothstep(0.012, 0.07, footprint);
		float raised = mix(0.22, tread(plane), detail_visibility);
		height += raised * 0.0035 * detail_visibility;
		col *= 0.91 + raised * 0.15;
		rough -= raised * 0.07;
	}
	if (hazard_stripe) {
		float stripe = step(0.5, fract((plane.x + plane.y) * 2.1));
		col = mix(vec3(0.035, 0.033, 0.027), vec3(0.32, 0.23, 0.11), stripe);
		col *= 0.72 + broad * 0.27;
		col = mix(col, wear_color.rgb, scratches * 0.8);
	}
	// Screen-space surface gradient gives the same small bevel on every mesh axis.
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float determinant = dot(dpdx, r1);
	vec3 gradient = sign(determinant) * (dFdx(height) * r1 + dFdy(height) * r2);
	NORMAL = normalize(abs(determinant) * NORMAL - bump_strength * gradient + vec3(0.0, 0.0, 0.00000001));
	ALBEDO = col;
	METALLIC = min(metallic_amount, 0.5);
	ROUGHNESS = clamp(rough, 0.75, 1.0);
	SPECULAR = 0.2;
}
