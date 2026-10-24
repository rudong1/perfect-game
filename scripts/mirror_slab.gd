extends StaticBody2D
## Reusable pushable prop. Campaign puzzles use only flips and the shadow.
@export var min_x := 660.0
@export var max_x := 1200.0
@export var height := 400.0
var push_velocity := 0.0
var _origin := Vector2.ZERO
var _shape: RectangleShape2D
var _player: CharacterBody2D

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

func reset() -> void:
	global_position = _origin
	push_velocity = 0.0

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
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-12, -height, 24, height), Color(0.3, 0.55, 0.7, 0.9))
	draw_line(Vector2(0, -height + 8), Vector2(0, -8), Color(0.7, 0.95, 1), 4)
