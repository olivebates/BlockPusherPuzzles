shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D hue_palette : repeat_disable, filter_linear;
uniform sampler2D exempt_texture : repeat_disable, filter_nearest;
uniform float palette_samples = 1536.0;
uniform vec4 ui_rects[4];
uniform int ui_rect_count = 0;

vec3 rgb_to_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 0.0000001)), d / (q.x + 0.0000001), q.x);
}

void fragment() {
	vec4 source = texture(screen_texture, SCREEN_UV);
	vec3 hsv = rgb_to_hsv(source.rgb);
	vec3 rainbow = texture(hue_palette, vec2((hsv.x * palette_samples + 0.5) / (palette_samples + 1.0), 0.5)).rgb;
	vec3 shifted = mix(vec3(1.0), rainbow, hsv.y) * hsv.z;
	vec4 exempt = texture(exempt_texture, SCREEN_UV);
	bool preserve = exempt.a > 0.01;
	// UI on top of exempt world pixels still receives the shared palette.
	for (int i = 0; i < 4; i++) {
		if (i >= ui_rect_count) { break; }
		vec4 rect = ui_rects[i];
		if (all(greaterThanEqual(SCREEN_UV, rect.xy)) && all(lessThanEqual(SCREEN_UV, rect.zw))) { preserve = false; }
	}
	COLOR = vec4(preserve ? source.rgb : shifted, source.a);
}
