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

func _ready() -> void:
	z_index = -5
	var layer := CanvasLayer.new()
	layer.layer = -10
	add_child(layer)
	far_strip = _strip(layer, FAR, Color(0.84, 0.88, 0.88))
	near_strip = _strip(layer, NEAR, Color(0.78, 0.83, 0.84))

func _strip(parent: Node, texture: Texture2D, tint: Color) -> Node2D:
	var strip := Node2D.new()
	parent.add_child(strip)
	for i in 3:
		var image := TextureRect.new()
		image.texture = texture
		image.position = Vector2(i * 1920, 0)
		image.size = Vector2(1920, 1080)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image.flip_h = i % 2 == 1
		image.modulate = tint
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.add_child(image)
	return strip

func _process(_delta: float) -> void:
	var distance := maxf(0, camera.position.x - 960)
	far_strip.position.x = -distance * FAR_SPEED
	near_strip.position.x = -distance * NEAR_SPEED

func _draw() -> void:
	draw_rect(Rect2(0, 900, corridor_width, 180), Color("#293431"))
	draw_rect(Rect2(0, 0, corridor_width, 180), Color("#1B2423"))
	draw_rect(Rect2(0, 910, corridor_width, 12), Color("#364340"))
	draw_line(Vector2(0, 900), Vector2(corridor_width, 900), Color("#A8B6B2"), 3)
	for i in 24:
		var x := i * 160.0
		draw_line(Vector2(x, 921), Vector2(x, 1080), Color(0.6, 0.7, 0.67, 0.12), 1)
		draw_polyline(PackedVector2Array([Vector2(x + 28, 1070), Vector2(x + 28, 990), Vector2(x + 80, 946), Vector2(x + 132, 990), Vector2(x + 132, 1070)]), Color(0.52, 0.62, 0.59, 0.11), 2, true)
