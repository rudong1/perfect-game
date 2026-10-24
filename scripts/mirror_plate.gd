extends Area2D
## A reflection-only pressure plate. It is invisible and inert in normal view;
## while mirrored, the player can stand on it to unlock the exit.

signal activated

@export var requires_mirror := true
@export var player_group := "player"

var is_activated := false
var _mirror_state: Node


func _ready() -> void:
	_mirror_state = get_node_or_null("/root/MirrorState")
	if _mirror_state == null:
		push_error("MirrorState autoload not found")
		return
	_mirror_state.connect("mirror_changed", _on_mirror_changed)
	_on_mirror_changed(bool(_mirror_state.get("mirrored")))


func _is_available() -> bool:
	var is_mirrored := bool(_mirror_state.get("mirrored"))
	return is_mirrored if requires_mirror else not is_mirrored


func _on_mirror_changed(_is_mirrored: bool) -> void:
	visible = _is_available() or is_activated


func _physics_process(_delta: float) -> void:
	if is_activated or not _is_available():
		return
	for body in get_overlapping_bodies():
		if body.is_in_group(player_group):
			_activate()
			return


func _activate() -> void:
	is_activated = true
	visible = true
	modulate = Color(0.7, 0.95, 1.0, 1.0)
	activated.emit()
