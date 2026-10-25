shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/rgb_palette.gdshaderinc"
uniform float monochrome_amount : hint_range(0.0, 1.0) = 0.0;
varying vec4 vertex_tint;
void vertex() {
	vertex_tint = COLOR;
}
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec3 col = without_amber(source.rgb);
	float lightness = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lightness), monochrome_amount);
	COLOR = vec4(col, source.a) * vertex_tint;
}
