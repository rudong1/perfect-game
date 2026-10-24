shader_type canvas_item;
render_mode unshaded;

uniform vec4 top_color : source_color = vec4(0.027, 0.031, 0.039, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.082, 0.090, 0.110, 1.0);
uniform vec4 accent_color : source_color = vec4(0.784, 0.804, 0.839, 1.0);
uniform vec4 platform_color : source_color = vec4(0.173, 0.184, 0.212, 1.0);
uniform vec4 light_color : source_color = vec4(0.86, 0.89, 0.95, 1.0);
uniform float glow_strength : hint_range(0.0, 2.0) = 1.0;
uniform float light_dir : hint_range(-1.0, 1.0) = -1.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
uniform float fog_amount : hint_range(0.0, 1.0) = 0.0;
uniform bool moss_enabled = false;
uniform sampler2D scene_texture : source_color, filter_linear;
uniform bool use_scene_texture = false;

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

float fbm3(vec2 p) {
	return (stone_noise(p) + 0.5 * stone_noise(p * 2.03 + 17.1) + 0.25 * stone_noise(p * 4.07 + 41.3)) / 1.75;
}

void fragment() {
	vec2 uv = UV;

	// Flipped light frame: the burial world is lit from the floor up, so every
	// light-dependent term reads the mirrored vertical coordinate.
	float flips = step(0.0, light_dir);
	float ly = mix(uv.y, 1.0 - uv.y, flips);

	vec3 col = mix(top_color.rgb, bottom_color.rgb, smoothstep(0.0, 1.0, uv.y));

	// Engaged columns: nine shafts, subtler than a full radius falloff.
	float cell_u = fract(uv.x * 9.0);
	float body = smoothstep(0.0, 0.12, cell_u) * smoothstep(1.0, 0.88, cell_u);
	col *= mix(1.0, mix(1.08, 0.54, cell_u), body * 0.50);

	// Capital bands catch a thin line of light.
	float band = pow(smoothstep(0.5, 0.0, abs(fract(ly * 5.0) - 0.5)), 30.0);
	col += platform_color.rgb * band * 0.14 * body;

	// The vault away from the light sinks into shadow.
	col *= mix(1.0, 0.44, smoothstep(0.46, 0.02, ly));

	// Stone grain and mortar joints, kept restrained so they read as texture
	// rather than as a bright grid.
	col *= 0.90 + 0.16 * fbm3(uv * vec2(34.0, 22.0));
	float vertical = smoothstep(0.5, 0.0, abs(fract(uv.x * 10.67) - 0.5));
	float horizontal = smoothstep(0.5, 0.0, abs(fract(ly * 12.0) - 0.5));
	col += platform_color.rgb * (pow(vertical, 20.0) * 0.10 + pow(horizontal, 20.0) * 0.06);

	// Three shafts spilling out of the rose window.
	vec2 window = vec2(0.5, mix(0.278, 0.722, flips));
	for (int i = 0; i < 3; i++) {
		float spread = -0.34 + 0.34 * float(i);
		float t = clamp((ly - 0.278) / 0.722, 0.0, 1.0);
		float beam_x = window.x + spread * t;
		float width = 0.018 + 0.060 * t;
		float beam = smoothstep(width, 0.0, abs(uv.x - beam_x)) * step(0.278, ly);
		col += light_color.rgb * beam * 0.085 * (1.0 - t * 0.45) * glow_strength;
	}

	// Halo around the window itself.
	col += light_color.rgb * smoothstep(0.30, 0.0, length(uv - window)) * 0.055 * glow_strength;

	// Light pooling on the surface opposite the window.
	col += light_color.rgb * smoothstep(0.90, 1.0, ly) * 0.035;

	// Dust motes drifting through the shafts.
	float dust = step(0.9980, hash(floor(uv * vec2(220.0, 130.0))));
	col += light_color.rgb * dust * 0.11 * (1.0 - smoothstep(0.55, 0.98, ly));

	// Ground fog.
	if (fog_amount > 0.0) {
		float fog = smoothstep(0.60, 1.0, ly) * fog_amount;
		fog *= 0.6 + 0.4 * fbm3(uv * vec2(9.0, 6.0));
		col = mix(col, mix(accent_color.rgb, light_color.rgb, 0.5), fog * 0.38);
	}

	// Moss creeping over the burial ground.
	if (moss_enabled) {
		float edge_noise = (fbm3(uv * vec2(24.0, 15.0)) - 0.5) * 0.09;
		float moss = smoothstep(0.72 + edge_noise, 1.0, uv.y) * 0.24;
		col = mix(col, vec3(0.1804, 0.3569, 0.2431), moss);
	}

	// Push or drain the palette per world.
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, saturation);

	// Keep the room genuinely dark: the light sources above are the only relief.
	col *= 0.80;

	// Vignette.
	vec2 centered = uv - 0.5;
	col *= 1.0 - dot(centered, centered) * 1.05;

	if (use_scene_texture) {
		// Cover the viewport without stretching the authored architecture.
		vec2 image_size = vec2(textureSize(scene_texture, 0));
		float image_aspect = image_size.x / image_size.y;
		float screen_aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
		vec2 cover = vec2(min(1.0, screen_aspect / image_aspect), min(1.0, image_aspect / screen_aspect));
		vec2 scene_uv = (uv - 0.5) * cover + 0.5;
		col = texture(scene_texture, scene_uv).rgb * 0.88;
		// Keep the per-world direction and fog over the illustrated stone.
		col += light_color.rgb * (1.0 - smoothstep(0.0, 0.18, ly)) * 0.012;
		col = mix(col, light_color.rgb * 0.28, smoothstep(0.70, 1.0, ly) * fog_amount * 0.08);
		col *= 1.0 - dot(centered, centered) * 0.18;
	}
	COLOR = vec4(col, 1.0);
}
