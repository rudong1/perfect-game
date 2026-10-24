shader_type canvas_item;
render_mode unshaded;

// SpriteFrames use AtlasTexture margins on a 320x380 logical canvas.
// Vertex coordinates keep the smoke mask stable when atlas UVs change frame.
varying vec2 frame_uv;
void vertex() {
	frame_uv = (VERTEX + vec2(160.0, 342.0)) / vec2(320.0, 380.0);
}

float ink_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float ink_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(ink_hash(i), ink_hash(i + vec2(1.0, 0.0)), f.x),
		mix(ink_hash(i + vec2(0.0, 1.0)), ink_hash(i + vec2(1.0)), f.x), f.y);
}
void fragment() {
	vec4 sprite = COLOR;
	vec2 uv = frame_uv;
	float smoke = ink_noise(uv * vec2(5.0, 7.0) + vec2(TIME * 0.09, -TIME * 0.12));
	vec2 drift = vec2(smoke - 0.5, ink_noise(uv * 4.0 - TIME * 0.07) - 0.5) * 0.055;
	float radial = smoothstep(0.75, 0.35, length(uv - 0.5 + drift));
	float irregular = smoothstep(0.08, 0.55, smoke);
	vec3 moon = vec3(0.7843, 0.8039, 0.8392);
	COLOR = vec4(mix(sprite.rgb, moon, 0.78), min(sprite.a, 0.62) * radial * mix(0.7, 1.0, irregular));
}
