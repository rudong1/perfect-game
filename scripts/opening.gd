extends Control
## Prologue: the cathedral photo fills the screen and the lancet window in its
## middle is the mirror. No character here — just the place, waiting.

const NEXT_SCENE := "res://scenes/gameplay/gameplay.tscn"

@onready var gate: Sprite2D = $Gate
@onready var caption: Label = $Caption
@onready var fade: ColorRect = $Fade

var _gate_material: ShaderMaterial
var _entering := false
var _armed := false
var _clock := 0.0


func _ready() -> void:
	_gate_material = gate.material as ShaderMaterial
	# This is not the mirror world yet; keep M from flipping the frame.
	var mirror := get_node_or_null("/root/MirrorState")
	if mirror != null:
		mirror.set("input_enabled", false)
		mirror.call("set_mirrored", false)
	caption.modulate.a = 1.0
	fade.color = Color(0, 0, 0, 0)
	# Prompt pulses gently so it reads as an invitation.
	var pulse := create_tween().set_loops()
	pulse.tween_property(caption, "modulate:a", 0.55, 1.1)
	pulse.tween_property(caption, "modulate:a", 1.0, 1.1)
	# Swallow any stray input from the scene handover before listening.
	await get_tree().create_timer(0.7).timeout
	_armed = true


func _process(delta: float) -> void:
	if _entering:
		return
	_clock += delta
	# The glass breathes so the mirror reads as alive rather than a still frame.
	_gate_material.set_shader_parameter("ripple", 0.30 + 0.12 * sin(_clock * 1.3))

	if not _armed:
		return
	# Nothing polled here on purpose: a polled action picks up stray input from
	# the scene handover and skips the prologue. Input arrives via _unhandled_input.


func _unhandled_input(event: InputEvent) -> void:
	if not _armed or _entering:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_enter()
			return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_enter()


func _enter() -> void:
	if _entering:
		return
	_entering = true
	caption.text = ""
	_gate_material.set_shader_parameter("ripple", 1.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(gate, "modulate:a", 1.0, 0.7)
	tween.tween_property(fade, "color:a", 1.0, 0.9).set_delay(0.45)
	await get_tree().create_timer(1.4).timeout
	get_tree().change_scene_to_file(NEXT_SCENE)
