shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0);
uniform float energy : hint_range(0.0, 1.0) = 0.0;
varying vec2 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
 vec4 base = texture(TEXTURE, UV) * COLOR;
 float sweep = pow(max(0.0, sin(local_position.y * 0.39 - TIME * 3.0)), 12.0);
 COLOR = vec4(base.rgb * tint.rgb + tint.rgb * (0.04 + energy * 0.3) * sweep, base.a * tint.a);
}
