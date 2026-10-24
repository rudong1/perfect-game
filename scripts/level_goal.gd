extends Area2D
## A prism fragment at the end of a room. Touching it finishes the room.

signal reached

var _used := false
var unlocked := true


func _ready() -> void:
	collision_mask = 2
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _used or not unlocked or not body.is_in_group("player"):
		return
	_used = true
	reached.emit()


func _physics_process(_delta: float) -> void:
	modulate.a = 1.0 if unlocked else 0.22
	if unlocked and not _used:
		for body in get_overlapping_bodies():
			_on_body_entered(body)
