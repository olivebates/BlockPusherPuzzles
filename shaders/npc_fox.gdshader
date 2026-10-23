shader_type canvas_item;
void fragment() {
 vec4 pixel = texture(TEXTURE, UV) * COLOR;
 float brightness = max(pixel.r,max(pixel.g,pixel.b));
 vec3 yellow = vec3(1.0,0.85,0.27);
 pixel.rgb = mix(pixel.rgb, yellow * min(1.0,brightness*1.35+0.05),0.85);
 COLOR = pixel;
}
