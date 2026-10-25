shader_type canvas_item;

// The painted reflection is already in the illustration. Only its glass
// shimmers; flipping the source would replace the girl with another image.
uniform vec2 gate_center = vec2(0.77, 0.47);
uniform vec2 gate_size = vec2(0.176, 0.77);
uniform float arch_frac : hint_range(0.0, 1.0) = 0.24;
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
	float edge_fade = arch_mask(uv);
	vec2 glass_uv = uv;
	glass_uv.x += sin(uv.y * 30.0 + TIME * 1.1) * 0.00065 * ripple * edge_fade;
	vec3 col = texture(TEXTURE, glass_uv).rgb;
	vec2 local = (uv - gate_center) / gate_size + vec2(0.5);
	float sheen = pow(max(0.0, 1.0 - abs(local.x - 0.5) * 2.0), 3.0);
	col += glass_tint.rgb * sheen * 0.012 * ripple * (0.6 + 0.4 * sin(TIME * 1.3));
	COLOR = vec4(col, edge_fade * glass_alpha);
}
