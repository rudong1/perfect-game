shader_type canvas_item;
render_mode unshaded;
void fragment() {
	COLOR.rgb = mix(COLOR.rgb, vec3(0.82), 0.68);
}
