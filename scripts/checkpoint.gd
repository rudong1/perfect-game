extends Area2D
## A room checkpoint. Touching it updates the respawn point and writes
## the run to user://mirror_save.cfg, so the title screen can continue later.

@export var respawn_position := Vector2.ZERO

var _active := false
var _state: Node


func _ready() -> void:
	collision_mask = 2
	_state = get_node_or_null("/root/GameState")
	body_entered.connect(_on_body_entered)
	if _state != null and bool(_state.get("has_checkpoint")):
		if int(_state.get("checkpoint_level")) == int(_state.get("current_level")):
			var saved: Vector2 = _state.get("checkpoint_position")
			if saved.distance_to(respawn_position) < 4.0:
				_set_active()


func _on_body_entered(body: Node2D) -> void:
	if _active or not body.is_in_group("player"):
		return
	if body.has_method("set_respawn_position"):
		body.call("set_respawn_position", respawn_position)
	if _state != null:
		var puzzle := get_parent().get_node_or_null("RoomPuzzle")
		var stage: int = puzzle.solved_steps if puzzle != null else 0
		_state.call("save_checkpoint", int(_state.get("current_level")), respawn_position, stage)
	_set_active()


func _set_active() -> void:
	if _active:
		return
	_active = true
	modulate = Color(1.2, 1.2, 1.2, 1.0)
