extends StaticBody2D
## Push the mirror with A/D; E reflects the protagonist across its current X.
signal transported(body: CharacterBody2D)
signal transport_failed
const ART = preload("res://assets/props/mirror_slab.tres")
@export var min_x := 660.0
@export var max_x := 1200.0
@export var height := 400.0
var push_velocity := 0.0
var _origin := Vector2.ZERO
var _shape: RectangleShape2D
var _player: CharacterBody2D
var used := false
var last_exit := Vector2.ZERO
var _notice_time := 0.0
var _hint: CanvasLayer

func _ready() -> void:
	add_to_group("mirror_slabs")
	_origin = global_position
	collision_layer = 1
	collision_mask = 1 | 2 | 4
	_shape = RectangleShape2D.new()
	_shape.size = Vector2(24, height)
	var collider := CollisionShape2D.new()
	collider.shape = _shape
	collider.position.y = -height * 0.5
	add_child(collider)
	_player = get_tree().get_first_node_in_group("player")
	get_node("/root/MirrorState").reset_requested.connect(reset)
	_hint = CanvasLayer.new()
	_hint.set_script(preload("res://scripts/readable_hint.gd"))
	_hint.target = self
	_hint.world_offset = Vector2(0, -height + 60)
	_hint.text = "A / D 推镜 · E 穿镜"
	_hint.tint = Color("#C8CDD6")
	add_child(_hint)
	var graphic := Sprite2D.new()
	graphic.texture = ART
	graphic.scale = Vector2(40.0 / ART.get_width(), height / ART.get_height())
	graphic.position = Vector2(0, -height * 0.5)
	add_child(graphic)

func reset() -> void:
	global_position = _origin
	push_velocity = 0.0
	used = false
	last_exit = Vector2.ZERO
	_notice_time = 0.0

func exit_for(entry: Vector2) -> Vector2:
	return Vector2(2.0 * global_position.x - entry.x, entry.y)

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(_player) or not _player.is_physics_processing():
		return
	if event.is_action_pressed("interact") and not event.is_echo() and absf(_player.global_position.x - global_position.x) <= 180:
		try_transport(_player)
		get_viewport().set_input_as_handled()

func try_transport(body: CharacterBody2D) -> bool:
	var destination := exit_for(body.global_position)
	if not MirrorSafety.is_clear(body, destination):
		_notice_time = 1.5
		transport_failed.emit()
		return false
	body.global_position = destination
	body.velocity.x = -body.velocity.x
	used = true
	last_exit = destination
	transported.emit(body)
	return true

func is_being_pushed_by(body: CharacterBody2D, input_x: float) -> bool:
	var dx := body.global_position.x - global_position.x
	var center_y: float = body.global_position.y - 75.0 * body.gravity_sign
	var near_height: bool = center_y + 75 > global_position.y - height and center_y - 75 < global_position.y
	return absf(dx) < 66 and near_height and input_x * dx < 0

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player) or not _player.is_physics_processing():
		return
	var input_x := Input.get_axis("move_left", "move_right")
	var pushing := is_being_pushed_by(_player, input_x)
	push_velocity = move_toward(push_velocity, input_x * 120.0 if pushing else 0.0, (600.0 if pushing else 1200.0) * delta)
	var destination := clampf(global_position.x + push_velocity * delta, min_x, max_x)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _shape
	query.transform = Transform2D(0, Vector2(destination, global_position.y - height * 0.5))
	query.collision_mask = 1 | 2 | 4
	query.exclude = [get_rid(), _player.get_rid()]
	# A tiny inset avoids treating contact with the supporting floor as blockage.
	query.transform.origin.y -= 0.5
	if get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
		global_position.x = destination
	else:
		push_velocity = 0.0
	_notice_time = maxf(0, _notice_time - delta)
	_hint.text = "镜面另一侧被挡住了" if _notice_time > 0 else "A / D 推镜 · E 穿镜"
	queue_redraw()
