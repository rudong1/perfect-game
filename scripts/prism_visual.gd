extends Control
## Flat 2D prism display. A white beam enters the glass, refracts, and leaves
## as one continuous rainbow band. R, G and B components are restored one by
## one as the player clears the three coloured worlds.

var completed := 0
var final := false
var colors: Array[Color] = []

var _anim := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func set_state(completed_levels: int, ray_colors: Array[Color], is_final: bool) -> void:
	completed = completed_levels
	final = is_final
	colors = ray_colors
	_anim = 0.0
	visible = true
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	if _anim < 1.0:
		_anim = minf(_anim + delta / 1.6, 1.0)
		queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var anim := _anim
	var restored := clampi(completed - 1, 0, 3)
	# Red world restores R, blue world restores B, green world restores G.
	var mask := Vector3(
		1.0 if restored >= 1 else 0.0,
		1.0 if restored >= 3 else 0.0,
		1.0 if restored >= 2 else 0.0
	)

	# Soft halo behind the glass.
	for i in range(6, 0, -1):
		draw_circle(Vector2(900, 470), 150.0 + i * 32.0, Color(0.72, 0.86, 1.0, 0.008 * anim))

	# Ground shadow.
	draw_colored_polygon(_ellipse(Vector2(900, 708), 260, 18, 32), Color(0.0, 0.0, 0.0, 0.24 * anim))

	# Symmetric, upright prism.
	var apex := Vector2(900, 300)
	var left := Vector2(680, 700)
	var right := Vector2(1120, 700)
	var base_center := Vector2(900, 700)
	var glass := Color(0.78, 0.9, 1.0, 0.09 * anim)

	draw_colored_polygon(PackedVector2Array([apex, left, right]), glass)
	draw_colored_polygon(PackedVector2Array([apex, left, base_center]), Color(0.92, 0.97, 1.0, 0.06 * anim))
	draw_colored_polygon(PackedVector2Array([apex, base_center, right]), Color(0.48, 0.68, 0.9, 0.055 * anim))
	draw_polyline(PackedVector2Array([apex, left, right, apex]), Color(0.88, 0.96, 1.0, 0.68 * anim), 3.0, true)
	draw_line(apex, base_center, Color(0.88, 0.96, 1.0, 0.20 * anim), 1.5, true)
	draw_line(apex, left, Color(0.95, 0.99, 1.0, 0.34 * anim), 1.5, true)
	draw_line(left, right, Color(0.88, 0.96, 1.0, 0.48 * anim), 2.0, true)

	# White light entering the left face and crossing the glass.
	var entry := Vector2(785, 510)
	var exit_point := Vector2(1015, 510)
	var beam_reveal := clampf(anim * 2.8, 0.0, 1.0)
	var beam_start := Vector2(170, 510)
	draw_line(beam_start, beam_start.lerp(entry, beam_reveal), Color(1, 1, 1, 0.88), 9.0, true)
	draw_line(beam_start, beam_start.lerp(entry, beam_reveal), Color(0.75, 0.88, 1.0, 0.16), 22.0, true)
	if beam_reveal > 0.98:
		draw_line(entry, exit_point, Color(1, 1, 1, 0.55 * anim), 3.0, true)

	# Dispersion inside the glass: a thin spectral fan at low alpha.
	var inside_count := 20
	for i in inside_count:
		var t := float(i) / float(inside_count - 1)
		var inner_color := _channel_color(_spectrum(t), mask)
		inner_color.a = 0.18 * anim
		draw_line(entry, exit_point + Vector2(0, (t - 0.5) * 18.0), inner_color, 1.2, true)

	# Continuous rainbow band leaving the right face. It widens toward the
	# right edge, like a flat stylised spectrum.
	var strips := 84
	var alpha_base := (0.18 + 0.20 * restored) * anim
	if final:
		alpha_base = 0.9 * anim
	for i in strips:
		var t0 := float(i) / float(strips)
		var t1 := float(i + 1) / float(strips)
		var start_top := Vector2(1018, lerpf(492.0, 528.0, t0))
		var start_bottom := Vector2(1018, lerpf(492.0, 528.0, t1))
		var end_top := Vector2(1900, lerpf(300.0, 760.0, t0))
		var end_bottom := Vector2(1900, lerpf(300.0, 760.0, t1))
		var mid := (t0 + t1) * 0.5
		var band_color := _channel_color(_spectrum(mid), mask)
		band_color.a = alpha_base
		draw_colored_polygon(PackedVector2Array([start_top, start_bottom, end_bottom, end_top]), band_color)

	# Finale sparkle along the band.
	if final:
		for i in 7:
			var y := 300.0 + i * 72.0
			draw_line(Vector2(1110, 510), Vector2(1840, y), Color(1, 1, 1, 0.05), 3.0, true)

	# R/G/B restoration chips.
	_draw_channel_chips(font, mask)


func _spectrum(t: float) -> Color:
	return Color.from_hsv(lerpf(0.0, 0.78, t), 0.92, 1.0)


func _channel_color(c: Color, mask: Vector3) -> Color:
	var gray := (c.r + c.g + c.b) / 3.0
	var neutral := gray * 0.10
	return Color(
		lerpf(neutral, c.r, mask.x),
		lerpf(neutral, c.g, mask.y),
		lerpf(neutral, c.b, mask.z),
		1.0
	)


func _draw_channel_chips(font: Font, mask: Vector3) -> void:
	var labels := ["R", "G", "B"]
	var colors_rgb := [Color("#ff5c71"), Color("#69e39d"), Color("#51c8ff")]
	var values := [mask.x, mask.y, mask.z]
	for i in 3:
		var pos := Vector2(1470 + i * 96, 862)
		var on: bool = float(values[i]) > 0.5
		var c: Color = colors_rgb[i]
		draw_circle(pos, 23.0, Color(c.r, c.g, c.b, 0.20 if on else 0.04))
		draw_arc(pos, 23.0, 0.0, TAU, 32, Color(c.r, c.g, c.b, 0.9 if on else 0.25), 2.0, true)
		draw_string(font, pos + Vector2(-8, 8), labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 22,
			Color(c.r, c.g, c.b, 1.0 if on else 0.28))


func _ellipse(center: Vector2, radius_x: float, radius_y: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return points
