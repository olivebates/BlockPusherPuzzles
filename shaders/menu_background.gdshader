shader_type canvas_item;
uniform bool reduced_motion = false;

void fragment() {
	vec2 p = UV;
	vec2 aspect = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	float t = reduced_motion ? 0.0 : TIME * 0.14;
	vec3 teal = vec3(0.01, 0.32, 0.35);
	vec3 lilac = vec3(0.40, 0.23, 0.58);
	vec3 col = vec3(0.008, 0.035, 0.055);
	col += teal * 0.42 * exp(-3.0 * length((p - vec2(0.18, 0.72)) * aspect));
	col += lilac * 0.34 * exp(-4.0 * length((p - vec2(0.85, 0.26)) * aspect));
	vec2 grid = abs(fract((p * aspect + vec2(t * 0.018, -t * 0.025)) * 18.0) - 0.5);
	float lines = 1.0 - smoothstep(0.005, 0.015, min(grid.x, grid.y));
	col += vec3(0.08, 0.31, 0.34) * lines * 0.10;
	for (int i = 0; i < 16; i++) {
		float f = float(i);
		vec2 center = vec2(fract(sin(f * 17.17) * 437.55), fract(cos(f * 23.31) * 519.29));
		center += vec2(sin(t + f * 1.8), cos(t * 0.7 + f * 2.1)) * 0.045;
		vec2 d = (p - center) * aspect;
		float angle = t * 0.3 + f * 0.71;
		d = mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle))) * d;
		float edge = max(abs(d.x), abs(d.y));
		float radius = 0.012 + fract(f * 0.37) * 0.018;
		float box = 1.0 - smoothstep(radius - 0.001, radius + 0.001, edge);
		float outline = exp(-abs(edge - radius) * 900.0);
		vec3 hue = mix(teal * 2.1, lilac * 1.8, fract(f * 0.61));
		col += hue * (box * 0.12 + outline * 0.38 + exp(-length(d) * 28.0) * 0.10);
	}
	float center_shade = exp(-5.0 * length((p - vec2(0.5, 0.48)) * vec2(1.1, 1.0)));
	col *= 1.0 - center_shade * 0.55;
	col *= 0.7 + 0.3 * (1.0 - length((p - 0.5) * 0.9));
	COLOR = vec4(col, 1.0);
}
