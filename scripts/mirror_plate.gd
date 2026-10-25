extends Area2D
## Momentary by default. Visibility and contact availability are independent:
## a faint other-world plate still has honest collision/pressure semantics.
signal activated
signal pressure_changed(pressed: bool)
@export var requires_mirror := true
@export var phase_independent := false
@export var latching := false
@export var player_group := "mirror_actors"
var is_activated := false
var _mirror_state: Node

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 | 4
	_mirror_state = get_node("/root/MirrorState")
	_mirror_state.mirror_changed.connect(_on_mirror_changed)
	_mirror_state.reset_requested.connect(reset)
	_on_mirror_changed(_mirror_state.mirrored)

func _is_available() -> bool:
	return phase_independent or _mirror_state.mirrored == requires_mirror

func _on_mirror_changed(_value: bool) -> void:
	visible = true
	modulate.a = 1.0 if phase_independent or _mirror_state.mirrored == requires_mirror else 0.4

func _physics_process(_delta: float) -> void:
	var pressed := false
	if _is_available():
		for body in get_overlapping_bodies():
			if body.is_in_group(player_group):
				pressed = true
	_set_pressed(pressed or (latching and is_activated))

func _set_pressed(value: bool) -> void:
	if value == is_activated:
		return
	is_activated = value
	modulate = Color(1.2, 1.2, 1.2) if value else Color.WHITE
	_on_mirror_changed(_mirror_state.mirrored)
	pressure_changed.emit(value)
	if value:
		activated.emit()

func reset() -> void:
	_set_pressed(false)
