shader_type spatial;
render_mode unshaded;

uniform vec4 phosphor : source_color = vec4(0.25, 0.85, 0.66, 1.0);
uniform float intensity = 1.15;

void fragment() {
	vec2 uv = UV;
	float scan = 0.86 + 0.14 * sin(uv.y * 560.0);
	float grid = step(0.97, fract(uv.x * 16.0)) + step(0.97, fract(uv.y * 12.0));
	float wave = 0.5 + sin(uv.x * 26.0 + TIME * 0.65) * 0.12 + sin(uv.x * 73.0) * 0.025;
	float trace = 1.0 - smoothstep(0.008, 0.014, abs(uv.y - wave));
	float border = smoothstep(0.0, 0.055, min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y)));
	float sweep = 0.97 + 0.03 * sin(uv.y * 3.0 - TIME * 2.0);
	vec3 color = phosphor.rgb * (0.035 + grid * 0.035 + trace * 0.85) * scan * border * sweep;
	ALBEDO = color * 0.4;
	EMISSION = color * intensity;
}
