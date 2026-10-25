extends Area2D
## Momentary pressure plate: it is activated only while a body from
## `player_group` overlaps it. `latching` keeps it pressed after the first hit.
signal pressure_changed(pressed: bool)
@export var latching := false
@export var player_group := "mirror_actors"
var is_activated := false
var _mirror_state: Node

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 | 4
	_mirror_state = get_node("/root/MirrorState")
	_mirror_state.reset_requested.connect(reset)

func _physics_process(_delta: float) -> void:
	var pressed := false
	for body in get_overlapping_bodies():
		if body.is_in_group(player_group):
			pressed = true
	_set_pressed(pressed or (latching and is_activated))

func _set_pressed(value: bool) -> void:
	if value == is_activated:
		return
	is_activated = value
	modulate = Color(1.2, 1.2, 1.2) if value else Color.WHITE
	pressure_changed.emit(value)

func reset() -> void:
	_set_pressed(false)
