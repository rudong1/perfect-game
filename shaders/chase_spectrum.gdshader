shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/rgb_palette.gdshaderinc"
uniform int color_mask = 7; // collected red, blue, green bits
uniform float monochrome_amount : hint_range(0.0, 1.0) = 0.0;
varying vec4 vertex_tint;
void vertex() {
	vertex_tint = COLOR;
}
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec3 col = without_amber(source.rgb);
	float lightness = dot(col, vec3(0.299, 0.587, 0.114));
	bool red = col.r > max(col.g, col.b);
	bool blue = col.b >= max(col.r, col.g);
	int family = red ? 1 : (blue ? 2 : 4);
	if ((color_mask & family) == 0) {
		col = vec3(lightness);
	}
	// The final corridor carries the three collected colours through its glass.
	// Separate shafts avoid turning their overlap into an extra yellow light.
	for (int i = 0; i < 3; i++) {
		int flag = 1 << i;
		if ((color_mask & flag) == 0) { continue; }
		vec3 tint = i == 0 ? vec3(1.0, 0.20, 0.30) : (i == 1 ? vec3(0.18, 0.52, 1.0) : vec3(0.20, 1.0, 0.45));
		float x = 0.17 + float(i) * 0.33;
		float shaft = exp(-pow((UV.x - x) / 0.105, 2.0)) * smoothstep(0.15, 0.7, UV.y);
		float breath = 0.95 + 0.05 * sin(TIME * 0.8 + float(i) * 2.1);
		col += tint * shaft * breath * 0.025;
	}
	col = without_amber(col);
	col = mix(col, vec3(dot(col, vec3(0.299, 0.587, 0.114))), monochrome_amount);
	COLOR = vec4(col, source.a) * vertex_tint;
}
