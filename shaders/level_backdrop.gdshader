shader_type canvas_item;
render_mode unshaded;

uniform vec4 top_color : source_color = vec4(0.027, 0.031, 0.039, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.082, 0.090, 0.110, 1.0);
uniform vec4 accent_color : source_color = vec4(0.784, 0.804, 0.839, 1.0);
uniform float glow_strength : hint_range(0.0, 2.0) = 1.0;
uniform vec4 platform_color : source_color = vec4(0.173, 0.184, 0.212, 1.0);
uniform bool moss_enabled = false;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float stone_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), f.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), f.x), f.y);
}
float fbm2(vec2 p) {
	return (stone_noise(p) + 0.5 * stone_noise(p * 2.03 + 17.1)) / 1.5;
}
void fragment() {
	vec2 uv = UV;
	vec3 col = mix(top_color.rgb, bottom_color.rgb, smoothstep(0.0, 1.0, uv.y));
	float vertical = smoothstep(0.5, 0.0, abs(fract(uv.x * 10.67) - 0.5));
	float horizontal = smoothstep(0.5, 0.0, abs(fract(uv.y * 12.0) - 0.5));
	col += platform_color.rgb * (pow(vertical, 24.0) * 0.06 + pow(horizontal, 24.0) * 0.035);
	col *= 0.96 + 0.08 * fbm2(uv * vec2(28.0, 18.0));
	float shaft = smoothstep(0.09, 0.0, abs(uv.x - 0.5 - (uv.y - 0.45) * 0.28));
	col += accent_color.rgb * shaft * 0.025 * glow_strength;
	float dust = step(0.9983, hash(floor(uv * vec2(220.0, 130.0))));
	col += accent_color.rgb * dust * 0.10 * (1.0 - smoothstep(0.55, 0.95, uv.y));
	col += accent_color.rgb * smoothstep(0.34, 0.0, length(uv - vec2(0.5, 0.39))) * 0.025 * glow_strength;
	if (moss_enabled) {
		float edge_noise = (fbm2(uv * vec2(24.0, 15.0)) - 0.5) * 0.075;
		float moss = smoothstep(0.78 + edge_noise, 1.0, uv.y) * 0.18;
		col = mix(col, vec3(0.1804, 0.3569, 0.2431), moss);
	}
	vec2 centered = uv - 0.5;
	col *= 1.0 - dot(centered, centered) * 0.75;
	COLOR = vec4(col, 1.0);
}
