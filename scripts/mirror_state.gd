extends Node
## Global mirror state for the "镜" mechanic.
##
## M is handled here (not in the player controller), so any scene can register
## puzzle objects against one state source. ScreenMirror listens for rendering;
## MirrorPlatform / MirrorGate / MirrorPlate listen for puzzle logic.

signal mirror_changed(mirrored: bool)

const TOGGLE_COOLDOWN_MS := 180

var mirrored := false
var input_enabled := true

var _last_toggle_ms := -100000


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event.is_action_pressed("mirror"):
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


func reset() -> void:
	set_mirrored(false)
