shader_type canvas_item;

// A full-frame mirror layer that only survives inside a gothic lancet window.
// The node is a sprite covering the same area as the backdrop photo, so the
// reflected cathedral lines up with the real one behind it.
uniform vec2 gate_center = vec2(0.505, 0.387);
uniform vec2 gate_size = vec2(0.266, 0.874);
uniform float arch_frac : hint_range(0.0, 1.0) = 0.53;
uniform float ripple : hint_range(0.0, 1.0) = 0.0;
uniform vec4 glass_tint : source_color = vec4(0.72, 0.80, 0.95, 1.0);
uniform float glass_alpha : hint_range(0.0, 1.0) = 0.95;

float arch_mask(vec2 uv) {
	vec2 local = (uv - gate_center) / gate_size + vec2(0.5);
	if (local.x < 0.0 || local.x > 1.0 || local.y < 0.0 || local.y > 1.0) {
		return 0.0;
	}
	float y = 1.0 - local.y;
	float springline = 1.0 - arch_frac;
	if (y <= springline) {
		return 1.0;
	}
	float t = clamp((y - springline) / arch_frac, 0.0, 1.0);
	float half_width = pow(max(0.0, 1.0 - t * t), 0.62) * 0.5;
	return smoothstep(half_width + 0.008, half_width - 0.008, abs(local.x - 0.5));
}

void fragment() {
	vec2 uv = UV;
	// The reflection is the same nave seen from the far side of the glass.
	vec2 mirrored = vec2(1.0 - uv.x, uv.y);
	float wave = sin(uv.y * 24.0 + TIME * 1.5) * 0.0022 * (0.4 + ripple);
	float swell = sin(uv.y * 6.0 - TIME * 2.2) * 0.0026 * ripple;
	mirrored.x += wave + swell;

	vec3 col = texture(TEXTURE, mirrored).rgb;
	col = mix(col, col * glass_tint.rgb, 0.55);
	// Brighter where light grazes the glass, darker where the stone frame blocks it.
	vec2 local = (uv - gate_center) / gate_size + vec2(0.5);
	float edge = smoothstep(0.0, 0.10, local.x) * smoothstep(1.0, 0.90, local.x);
	col *= 0.70 + 0.34 * edge;
	col += glass_tint.rgb * 0.05 * (0.5 + 0.5 * sin(TIME * 1.1));

	// A rim of caught light along the stone frame makes the glass legible
	// against the photo behind it.
	float mask = arch_mask(uv);
	float rim = smoothstep(0.0, 0.05, mask) * (1.0 - smoothstep(0.05, 0.16, mask));
	col += glass_tint.rgb * rim * 0.85;

	COLOR = vec4(col, mask * glass_alpha);
}
