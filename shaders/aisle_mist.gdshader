shader_type canvas_item;
render_mode unshaded;
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), f.x), mix(hash(cell + vec2(0.0, 1.0)), hash(cell + 1.0), f.x), f.y);
}
void fragment() {
	vec2 p = UV * vec2(5.0, 9.0) + vec2(TIME * 0.025, 0.0);
	float mist = (noise(p) + 0.5 * noise(p * 2.03 + 9.1)) / 1.5;
	float ground = smoothstep(0.55, 0.83, UV.y) * (1.0 - smoothstep(0.83, 0.88, UV.y));
	COLOR = vec4(0.52, 0.66, 0.78, ground * mist * 0.13);
}
