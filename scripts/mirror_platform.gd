extends StaticBody2D
## A platform whose collision/visibility is driven by MirrorState.
##
## Use solid_when_mirrored = true for a "reflection bridge" that only exists
## while mirrored; use false for a barrier that dissolves in the reflection.

@export var solid_when_mirrored := true
@export var visible_when_mirrored := true
@export var fade_time := 0.12

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
	var shown := is_mirrored if visible_when_mirrored else not is_mirrored

	if _collision != null:
		_collision.set_deferred("disabled", not solid)

	if immediate or not is_inside_tree() or fade_time <= 0.0:
		modulate.a = 1.0 if shown else 0.0
		visible = shown
		return

	if _tween != null:
		_tween.kill()
	if shown:
		visible = true
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0 if shown else 0.0, fade_time)
	if not shown:
		_tween.tween_callback(func() -> void: visible = false)
