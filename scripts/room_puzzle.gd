extends Node
## The original three mechanics: twin pressure, moving reflection, live RGB.
var steps: Array = []
var goal: Area2D
var solved_steps := 0
var _hold := 0.0
var _player: CharacterBody2D

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	get_node("/root/MirrorState").reset_requested.connect(reset)
	reset()

func reset() -> void:
	solved_steps = 0
	_hold = 0
	goal.enabled = false
	for step in steps:
		step.door.close()
	_refresh_indicators()

func restore_completed(count: int) -> void:
	solved_steps = clampi(count, 0, steps.size())
	# A save never supplies missing live light channels.
	if solved_steps == steps.size() and _is_optical(steps.back()):
		solved_steps -= 1
	for i in solved_steps:
		steps[i].door.open()
	goal.enabled = solved_steps == steps.size()
	_refresh_indicators()

func _refresh_indicators() -> void:
	for i in steps.size():
		var step: Dictionary = steps[i]
		if step.has("marker"):
			step.marker.visible = i == solved_steps
			for plate in step.plates:
				plate.visible = i == solved_steps

func current_hint() -> String:
	if solved_steps >= steps.size():
		return "机关已解开，和影子一起走向出口。"
	var step: Dictionary = steps[solved_steps]
	var hint := str(step.hint)
	if _is_optical(step):
		hint += "  已抵达 %d / 3" % step.circuit.channel_count()
	return hint

func _is_optical(step: Dictionary) -> bool:
	return str(step.kind).contains("prism")

func _physics_process(delta: float) -> void:
	if solved_steps >= steps.size():
		if not _is_optical(steps.back()) or steps.back().circuit.channel_mask == 7:
			goal.enabled = true
			return
		# Optical exits close again if a pushed mirror interrupts the beam.
		solved_steps = steps.size() - 1
	var step: Dictionary = steps[solved_steps]
	var ready := false
	match step.kind:
		"plate":
			ready = get_node("/root/MirrorState").mirrored == step.mirrored
			for plate in step.plates:
				ready = ready and plate.is_activated
		"slab":
			ready = step.slab.used and absf(step.slab.position.x - step.calibration_x) <= 18
			ready = ready and absf(step.slab.last_exit.x - step.landing_x) <= 24 and absf(step.slab.last_exit.y - 900) < 8
			ready = ready and step.plates[0].is_activated
		"prism":
			ready = step.circuit.channel_mask == 7
		"transit_prism":
			ready = step.slab.used and step.circuit.channel_mask == 7
	_hold = _hold + delta if ready else 0
	if _hold >= 0.08:
		step.door.open()
		solved_steps += 1
		_hold = 0
		goal.enabled = solved_steps == steps.size()
		_refresh_indicators()
	elif _is_optical(step):
		step.door.close()
		goal.enabled = false
