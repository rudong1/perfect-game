extends Node
## One world-space axis for physics, clones, HUD and screen rendering.

signal mirror_changed(mirrored: bool)
signal axis_changed(value: float)
signal reset_requested

const TOGGLE_COOLDOWN_MS := 180
var axis_y := 540.0:
	set(value):
		if is_equal_approx(axis_y, value):
			return
		axis_y = value
		axis_changed.emit(value)
var mirrored := false
var input_enabled := true
var _last_toggle_ms := -100000

func reflect_point(point: Vector2) -> Vector2:
	return Vector2(point.x, 2.0 * axis_y - point.y)

func _unhandled_input(event: InputEvent) -> void:
	if input_enabled and event.is_action_pressed("mirror") and not event.is_echo():
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_toggle_ms < TOGGLE_COOLDOWN_MS:
		return
	_last_toggle_ms = now
	set_mirrored(not mirrored)

func set_mirrored(value: bool) -> void:
	if value == mirrored:
		return
	mirrored = value
	mirror_changed.emit(mirrored)
	# Gates defer their collision changes; relocate after those changes land.
	_resolve_actors.call_deferred()

func _resolve_actors() -> void:
	for actor in get_tree().get_nodes_in_group("mirror_actors"):
		actor.resolve_overlap()

func reset() -> void:
	set_mirrored(false)
	_last_toggle_ms = -100000

func restart_room() -> void:
	reset()
	reset_requested.emit()
