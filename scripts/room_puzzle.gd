extends Node
## Ordered physical challenges: contact, landing, blocked shadow and live bridge.
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

func restore_completed(count: int) -> void:
	solved_steps = clampi(count, 0, steps.size())
	for i in solved_steps:
		steps[i].door.open()
	goal.enabled = solved_steps == steps.size()

func current_hint() -> String:
	return "和影子一起走向颜色。" if solved_steps >= steps.size() else str(steps[solved_steps].hint)

func _physics_process(delta: float) -> void:
	if solved_steps >= steps.size():
		goal.enabled = true
		return
	var step: Dictionary = steps[solved_steps]
	var ready := false
	match step.kind:
		"plate":
			ready = get_node("/root/MirrorState").mirrored == step.mirrored
			for plate in step.plates:
				ready = ready and plate.is_activated
		"reach":
			ready = _player.position.x >= step.target_x and _player.is_on_floor() and absf(_player.position.y - 900) < 12
		"release":
			ready = step.barrier.released
		"bridge":
			ready = step.bridge.activated_once and _player.position.x >= step.target_x and _player.is_on_floor() and absf(_player.position.y - 900) < 12
	_hold = _hold + delta if ready else 0
	if _hold >= 0.08:
		step.door.open()
		solved_steps += 1
		_hold = 0
		goal.enabled = solved_steps == steps.size()
