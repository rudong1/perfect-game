shader_type canvas_item;
render_mode unshaded;

// A restrained "the mirror is answering" anomaly: a slow hand-held wobble,
// a hint of chromatic split and a pale red edge wash. Driven from 0 to 1 by
// title_screen.gd while M is held on the sealed start screen.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;
	vec2 drift = vec2(
		sin(uv.y * 13.0 + t * 7.0) * 0.0024 + sin(t * 5.3) * 0.0009,
		cos(uv.x * 11.0 + t * 8.5) * 0.0028 + cos(t * 4.1) * 0.0007
	) * amount;
	vec2 warped = clamp(uv + drift, vec2(0.0), vec2(1.0));
	float split = 0.0022 * amount;
	vec3 col;
	col.r = texture(screen_texture, clamp(warped + vec2(split, 0.0), vec2(0.0), vec2(1.0))).r;
	col.g = texture(screen_texture, warped).g;
	col.b = texture(screen_texture, clamp(warped - vec2(split, 0.0), vec2(0.0), vec2(1.0))).b;
	float edge = smoothstep(0.12, 0.72, length(uv - vec2(0.5)));
	col = mix(col, col * vec3(1.10, 0.91, 0.94), amount * 0.55);
	col.r += amount * 0.06 * edge;
	COLOR = vec4(col, 1.0);
}
