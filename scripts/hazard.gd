extends Area2D
## Contact hazard. Sends the player back to the room spawn point.

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("respawn"):
		body.call("respawn")
