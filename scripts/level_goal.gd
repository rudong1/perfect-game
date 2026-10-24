extends Area2D
## A prism fragment at the end of a room. Touching it finishes the room.

signal reached

var _used := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _used or not body.is_in_group("player"):
		return
	_used = true
	reached.emit()
