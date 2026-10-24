shader_type canvas_item;
render_mode unshaded;

// Full-screen vertical mirror used by the M key. The game world, sprites and
// lower CanvasLayers are captured into screen_texture before this overlay is
// drawn. axis_y is MirrorState.axis_y projected into normalized screen space.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float axis_y = 0.5;
uniform float mirrored : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	uv.y = mix(uv.y, 2.0 * axis_y - uv.y, mirrored);
	COLOR = (uv.y >= 0.0 && uv.y <= 1.0) ? texture(screen_texture, uv) : vec4(0.02, 0.03, 0.05, 1.0);
}
