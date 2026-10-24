shader_type canvas_item;
render_mode unshaded;

uniform vec4 top_color : source_color = vec4(0.02, 0.03, 0.05, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.08, 0.10, 0.15, 1.0);
uniform vec4 accent_color : source_color = vec4(0.80, 0.88, 1.0, 1.0);
uniform float glow_strength : hint_range(0.0, 2.0) = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec3 col = mix(top_color.rgb, bottom_color.rgb, smoothstep(0.0, 1.0, uv.y));

	// Soft vertical light shaft from the prism direction.
	float shaft = smoothstep(0.09, 0.0, abs(uv.x - 0.50 - (uv.y - 0.45) * 0.28));
	col += accent_color.rgb * shaft * 0.035 * glow_strength;

	// Sparse stars / dust motes.
	vec2 cell = floor(uv * vec2(220.0, 130.0));
	float star = step(0.9978, hash(cell)) * (1.0 - smoothstep(0.55, 0.95, uv.y));
	col += accent_color.rgb * star * 0.7;

	// Faint prism halo.
	vec2 d = uv - vec2(0.5, 0.39);
	float halo = smoothstep(0.34, 0.0, length(d));
	col += accent_color.rgb * halo * 0.035 * glow_strength;

	vec2 centered = uv - 0.5;
	col *= 1.0 - dot(centered, centered) * 0.55;
	COLOR = vec4(col, 1.0);
}
