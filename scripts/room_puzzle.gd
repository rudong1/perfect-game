extends Node
## Ordered mirror/shadow contact challenges. Each solved step opens one door.
var steps: Array = []
var goal: Area2D
var solved_steps := 0
var _hold := 0.0

func _ready() -> void:
	get_node("/root/MirrorState").reset_requested.connect(reset)
	reset()

func reset() -> void:
	solved_steps = 0
	_hold = 0.0
	goal.enabled = false
	for step in steps:
		step.door.close()

func _physics_process(delta: float) -> void:
	if solved_steps >= steps.size():
		goal.enabled = true
		return
	var step: Dictionary = steps[solved_steps]
	var pressed: bool = get_node("/root/MirrorState").mirrored == step.mirrored
	for plate in step.plates:
		pressed = pressed and plate.is_activated
	_hold = _hold + delta if pressed else 0.0
	if _hold >= 0.08:
		step.door.open()
		solved_steps += 1
		_hold = 0.0
		if solved_steps == steps.size():
			goal.enabled = true
