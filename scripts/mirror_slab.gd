extends StaticBody2D
## Push with A/D at either face, use E nearby to reflect across this slab's X.
signal transported(body: CharacterBody2D)
signal transport_failed
@export var min_x := 660.0
@export var max_x := 1200.0
@export var height := 400.0
var push_velocity := 0.0
var used := false
var _origin := Vector2.ZERO
var _shape: RectangleShape2D
var _player: CharacterBody2D
var _preview := Vector2.ZERO
var _preview_clear := false
var _notice := ""
var _notice_time := 0.0

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
	used = false

func exit_for(entry: Vector2) -> Vector2:
	return Vector2(2.0 * global_position.x - entry.x, entry.y)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player) or not _player.is_physics_processing():
		return
	var input_x := Input.get_axis("move_left", "move_right")
	var dx := _player.global_position.x - global_position.x
	var center_y: float = _player.global_position.y - 75.0 * _player.gravity_sign
	var near_height: bool = center_y + 75 > global_position.y - height and center_y - 75 < global_position.y
	var pushing: bool = absf(dx) < 66 and near_height and input_x * dx < 0
	push_velocity = move_toward(push_velocity, input_x * 150.0 if pushing else 0.0, (600.0 if pushing else 1200.0) * delta)
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
	_preview = exit_for(_player.global_position)
	_preview_clear = MirrorSafety.is_clear(_player, _preview)
	_notice_time = maxf(0, _notice_time - delta)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(_player) or not _player.is_physics_processing():
		return
	if event.is_action_pressed("interact") and not event.is_echo() and absf(_player.global_position.x - global_position.x) <= 180.0:
		try_transport(_player)
		get_viewport().set_input_as_handled()

func try_transport(body: CharacterBody2D) -> bool:
	var destination := exit_for(body.global_position)
	if not MirrorSafety.is_clear(body, destination):
		_notice = "出口被挡住"
		_notice_time = 1.5
		transport_failed.emit()
		return false
	body.global_position = destination
	body.velocity.x = -body.velocity.x
	used = true
	transported.emit(body)
	return true

func _draw() -> void:
	draw_rect(Rect2(-12, -height, 24, height), Color(0.3, 0.55, 0.7, 0.9))
	draw_line(Vector2(0, -height + 8), Vector2(0, -8), Color(0.7, 0.95, 1), 4)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-100, -height - 20), "A/D 推镜 · E 穿镜", HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	if is_instance_valid(_player) and absf(_player.global_position.x - global_position.x) <= 180:
		var point := to_local(_preview)
		draw_circle(point + Vector2(0, -70 * _player.gravity_sign), 24, Color(0.4, 1, 0.7, 0.5) if _preview_clear else Color(1, 0.3, 0.3, 0.5))
		draw_string(font, Vector2(-120, -height - 48), "落点 x = %.0f" % _preview.x, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	if _notice_time > 0:
		draw_string(font, Vector2(-90, -height - 75), _notice, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 0.5, 0.4))
