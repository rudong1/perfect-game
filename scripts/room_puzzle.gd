extends Node
## All room exits have an explicit gameplay prerequisite, including ceilings.
var kind := "twins"
var plates: Array[Area2D] = []
var door: StaticBody2D
var goal: Area2D
var slab: StaticBody2D
var circuit: Node2D
var solved := false
var _hold := 0.0
var twins_latched := false

func _ready() -> void:
	goal.set("unlocked", false)
	get_node("/root/MirrorState").reset_requested.connect(reset)

func reset() -> void:
	solved = false
	_hold = 0.0
	twins_latched = false
	goal.unlocked = false
	if is_instance_valid(door):
		door.close()

func _physics_process(delta: float) -> void:
	if solved:
		return
	var optical := kind.contains("prism")
	if plates.size() == 2 and plates[0].is_activated and plates[1].is_activated and get_node("/root/MirrorState").mirrored:
		twins_latched = true
	var satisfied := false
	match kind:
		"twins":
			satisfied = plates.size() == 2 and plates[0].is_activated and plates[1].is_activated and get_node("/root/MirrorState").mirrored
		"slab":
			satisfied = slab.used and slab.global_position.x >= 1040.0 and slab.global_position.x <= 1120.0
		"twins_prism":
			satisfied = twins_latched and get_node("/root/GameState").has_rainbow()
		"transit_prism":
			satisfied = slab.used and get_node("/root/GameState").has_rainbow()
		"prism":
			satisfied = get_node("/root/GameState").has_rainbow()
	_hold = _hold + delta if satisfied else 0.0
	if _hold >= 0.12:
		# Optical goals remain live: breaking a ray must close the exit again.
		if not optical:
			solved = true
		goal.unlocked = true
		if is_instance_valid(door):
			door.open()
	elif optical:
		goal.unlocked = false
		if is_instance_valid(door):
			door.close()
