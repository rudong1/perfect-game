extends Area2D
## Respawn trigger below the playfield. Also returns the player to reality so
## a failed mirror crossing doesn't leave them confused.

@export var respawn_position := Vector2(160.0, 560.0)
@export var reset_mirror := true
@export var player_group := "player"


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(player_group):
		return
	if body.has_method("respawn"):
		body.call("respawn")
	elif body is CharacterBody2D:
		body.global_position = respawn_position
		body.velocity = Vector2.ZERO
	if reset_mirror:
		var mirror_state := get_node_or_null("/root/MirrorState")
		if mirror_state != null:
			mirror_state.call("reset")
