extends Node2D
## A real, momentary bridge. Planks disappear in order after shadow pressure ends.
var plate: Area2D
var width := 340.0
var plank_count := 9
var release_time := 0.55
var activated_once := false
var _age := 99.0
var _colliders: Array[CollisionShape2D] = []
var _active: Array[bool] = []
var _edge := Color.WHITE

func _ready() -> void:
	add_to_group("shadow_bridges")
	_edge = get_node("/root/GameState").get_level().edge
	for i in plank_count:
		var body := StaticBody2D.new()
		body.position.x = i * width / plank_count
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(width / plank_count + 0.5, 22)
		collision.position = shape.size * 0.5
		collision.shape = shape
		collision.disabled = true
		body.add_child(collision)
		add_child(body)
		_colliders.append(collision)
		_active.append(false)
	get_node("/root/MirrorState").reset_requested.connect(reset)

func reset() -> void:
	activated_once = false
	_age = 99
	for i in plank_count:
		_active[i] = false
		_colliders[i].set_deferred("disabled", true)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if plate.is_activated:
		_age = 0
		activated_once = true
	else:
		_age += delta
	for i in plank_count:
		var live := _age < release_time + i * 0.11
		if live != _active[i]:
			_active[i] = live
			_colliders[i].set_deferred("disabled", not live)
	queue_redraw()

func _draw() -> void:
	for i in plank_count:
		var box := Rect2(i * width / plank_count, 0, width / plank_count - 2, 20)
		draw_rect(box, Color(_edge, 0.4 if _active[i] else 0.035))
		draw_line(box.position, box.position + Vector2(box.size.x, 0), Color(_edge, 1.0 if _active[i] else 0.15), 3)
