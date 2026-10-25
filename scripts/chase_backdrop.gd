extends Node2D
## Screen-space artwork tracks the same camera as the world-space paving.
const FAR = preload("res://assets/backgrounds/chase_far.png")
const NEAR = preload("res://assets/backgrounds/chase_near.png")
const FAR_SPEED := 0.42
const NEAR_SPEED := 0.78
var camera: Camera2D
var corridor_width := 3600.0
var far_strip: Node2D
var near_strip: Node2D
var _palettes: Array[ShaderMaterial] = []
var _desaturation := 0.0
var color_mask := 7

func _ready() -> void:
	var state := get_node("/root/GameState")
	color_mask = state.offered_mask if state.has_offered_colors() else state.collected_mask
	z_index = -5
	var layer := CanvasLayer.new()
	layer.layer = -10
	add_child(layer)
	far_strip = _strip(layer, FAR, Color(0.84, 0.88, 0.88))
	near_strip = _strip(layer, NEAR, Color(0.78, 0.83, 0.84))

func _strip(parent: Node, texture: Texture2D, tint: Color) -> Node2D:
	var strip := Node2D.new()
	parent.add_child(strip)
	var palette := ShaderMaterial.new()
	palette.shader = preload("res://shaders/chase_spectrum.gdshader")
	palette.set_shader_parameter("color_mask", color_mask)
	_palettes.append(palette)
	for i in 3:
		var image := TextureRect.new()
		image.texture = texture
		image.material = palette
		image.position = Vector2(i * 1920, 0)
		image.size = Vector2(1920, 1080)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image.flip_h = i % 2 == 1
		image.modulate = tint
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.add_child(image)
	return strip

func set_desaturation(value: float) -> void:
	_desaturation = clampf(value, 0, 1)
	for palette in _palettes:
		palette.set_shader_parameter("monochrome_amount", _desaturation)
	queue_redraw()

func _stone(color: Color) -> Color:
	var gray := color.r * 0.299 + color.g * 0.587 + color.b * 0.114
	return color.lerp(Color(gray, gray, gray, color.a), _desaturation)

func _process(_delta: float) -> void:
	var distance := maxf(0, camera.position.x - 960)
	far_strip.position.x = -distance * FAR_SPEED
	near_strip.position.x = -distance * NEAR_SPEED

func _draw() -> void:
	draw_rect(Rect2(0, 900, corridor_width, 180), _stone(Color("#2D303A")))
	draw_rect(Rect2(0, 0, corridor_width, 180), _stone(Color("#1C2029")))
	draw_rect(Rect2(0, 910, corridor_width, 12), _stone(Color("#3A3F48")))
	draw_line(Vector2(0, 900), Vector2(corridor_width, 900), _stone(Color("#A8B6B2")), 3)
	var colours := [Color("#FF637E"), Color("#59CFFF"), Color("#73E2A5")]
	for i in 3:
		if color_mask & (1 << i):
			draw_rect(Rect2(i * corridor_width / 3.0, 902, corridor_width / 3.0, 7), Color(colours[i], 0.13 * (1.0 - _desaturation)))
	for i in 24:
		var x := i * 160.0
		draw_line(Vector2(x, 921), Vector2(x, 1080), Color(0.6, 0.7, 0.67, 0.12), 1)
		draw_polyline(PackedVector2Array([Vector2(x + 28, 1070), Vector2(x + 28, 990), Vector2(x + 80, 946), Vector2(x + 132, 990), Vector2(x + 132, 1070)]), Color(0.52, 0.62, 0.59, 0.11), 2, true)
