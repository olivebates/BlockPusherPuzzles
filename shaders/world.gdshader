shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float impact = 0.0;
void fragment() {
 vec2 uv = SCREEN_UV;
 vec2 offset = (uv - 0.5) * impact * 0.001;
 vec3 c = texture(screen_texture, uv).rgb;
 c.r = texture(screen_texture, uv + offset).r;
 c.b = texture(screen_texture, uv - offset).b;
 float vignette = 1.0 - smoothstep(0.18, 0.8, distance(uv, vec2(0.5)));
 c *= mix(0.78, 1.0, vignette);
 c += sin(uv.y * 540.0 * 3.14159) * 0.004;
 COLOR = vec4(c, 1.0);
}
