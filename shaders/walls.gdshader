shader_type canvas_item;
uniform vec4 tile_color : source_color = vec4(0.2,0.2,0.2,1.0);
void fragment() {
 vec4 base = texture(TEXTURE, UV);
 float rim = 1.0 - smoothstep(0.0, 0.045, UV.y);
 COLOR = vec4(tile_color.rgb + vec3(0.025) * rim, base.a);
}
