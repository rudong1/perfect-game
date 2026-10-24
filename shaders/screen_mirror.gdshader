shader_type canvas_item;
render_mode unshaded;

// Full-screen vertical mirror used by the M key. The game world, sprites and
// lower CanvasLayers are captured into screen_texture before this overlay is
// drawn; flipping SCREEN_UV.y mirrors the whole frame without touching physics.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float mirrored : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	uv.y = mix(uv.y, 1.0 - uv.y, mirrored);
	COLOR = texture(screen_texture, uv);
}
