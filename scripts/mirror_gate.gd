extends StaticBody2D
## A two-state gate. With solid_when_mirrored = false it blocks the normal
## world and dissolves while the reflection is active (the tutorial gate).

signal gate_state_changed(is_solid: bool)

@export var solid_when_mirrored := false
@export var fade_time := 0.16

var _collision: CollisionShape2D
var _tween: Tween
var _mirror_state: Node


func _ready() -> void:
	_collision = get_node_or_null("CollisionShape2D") as CollisionShape2D
	_mirror_state = get_node_or_null("/root/MirrorState")
	if _mirror_state == null:
		push_error("MirrorState autoload not found")
		return
	_mirror_state.connect("mirror_changed", _on_mirror_changed)
	_apply(bool(_mirror_state.get("mirrored")), true)


func _on_mirror_changed(is_mirrored: bool) -> void:
	_apply(is_mirrored, false)


func _apply(is_mirrored: bool, immediate: bool) -> void:
	var solid := is_mirrored if solid_when_mirrored else not is_mirrored
	if _collision != null:
		_collision.set_deferred("disabled", not solid)
	gate_state_changed.emit(solid)

	if immediate or not is_inside_tree() or fade_time <= 0.0:
		modulate.a = 1.0 if solid else 0.0
		visible = solid
		return

	if _tween != null:
		_tween.kill()
	if solid:
		visible = true
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0 if solid else 0.0, fade_time)
	if not solid:
		_tween.tween_callback(func() -> void: visible = false)
