extends Node
## Quiet event-only sound design. Observe existing signals without changing rules.
signal effect_played(cue: StringName)

const MAX_VOICES := 4
const CUES := {
	&"mirror_flip": {"stream": preload("res://assets/audio/sfx/mirror_flip.wav"), "db": -6.0, "cooldown": 0.16},
	&"mirror_shatter": {"stream": preload("res://assets/audio/sfx/mirror_shatter.wav"), "db": -5.0, "cooldown": 0.4},
	&"mirror_pass": {"stream": preload("res://assets/audio/sfx/mirror_pass.wav"), "db": -7.0, "cooldown": 0.12},
	&"crystal_red": {"stream": preload("res://assets/audio/sfx/crystal_red.wav"), "db": -7.0, "cooldown": 0.3},
	&"crystal_blue": {"stream": preload("res://assets/audio/sfx/crystal_blue.wav"), "db": -7.0, "cooldown": 0.3},
	&"crystal_green": {"stream": preload("res://assets/audio/sfx/crystal_green.wav"), "db": -7.0, "cooldown": 0.3},
}

var _voices: Array[AudioStreamPlayer] = []
var _started: Array[float] = []
var _last_played: Dictionary = {}
var _time := 0.0
var _mirror_request_frame := -1
var _observed_mask := 0
var _scene_id := 0
var _state: Node
var _mirror: Node

# Identify patched nodes by script resource identity rather than by path string:
# renaming a script then fails loudly at parse time instead of silently dropping
# its sound.
const SLAB_SCRIPT = preload("res://scripts/mirror_slab.gd")
const FINAL_MIRROR_SCRIPT = preload("res://scripts/final_mirror.gd")

func _ready() -> void:
	# A crystal's sound must finish while its CG pauses the room.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_state = get_node("/root/GameState")
	_mirror = get_node("/root/MirrorState")
	_observed_mask = _state.collected_mask
	_state.changed.connect(_on_state_changed)
	_mirror.mirror_changed.connect(_on_mirror_changed)
	get_tree().node_added.connect(_on_node_added)
	for i in MAX_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.name = "Voice%d" % i
		voice.bus = &"SFX"
		voice.max_polyphony = 1
		add_child(voice)
		_voices.append(voice)
		_started.append(-100.0)

func _process(delta: float) -> void:
	_time += delta
	var scene := get_tree().current_scene
	var scene_id := scene.get_instance_id() if scene != null else 0
	if scene_id != _scene_id:
		# No residual glass or portal sound carries into another scene.
		for voice in _voices:
			voice.stop()
		_scene_id = scene_id
		_mirror_request_frame = -1
		_last_played.clear()

func _input(event: InputEvent) -> void:
	if not get_tree().paused and _is_gameplay() and _mirror.input_enabled:
		if event.is_action_pressed("mirror") and not event.is_echo():
			_mirror_request_frame = Engine.get_process_frames()

func _is_gameplay() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path == "res://scenes/gameplay/gameplay.tscn"

func _on_mirror_changed(_flipped: bool) -> void:
	# Resets and scene setup also change the mirror. Only a successful player M
	# event should whoosh; rejected cooldown presses produce no sound.
	if _mirror_request_frame == Engine.get_process_frames() and _is_gameplay() and _mirror.input_enabled:
		play_effect(&"mirror_flip")
	_mirror_request_frame = -1

func _on_state_changed() -> void:
	var next_mask: int = _state.collected_mask
	var gained := next_mask & ~_observed_mask
	_observed_mask = next_mask
	if not _is_gameplay() or get_tree().paused:
		return
	for i in 3:
		if gained & (1 << i):
			play_effect([&"crystal_red", &"crystal_blue", &"crystal_green"][i])

func _on_node_added(node: Node) -> void:
	var script: Script = node.get_script()
	if script == SLAB_SCRIPT:
		node.transported.connect(_on_transported)
	elif script == FINAL_MIRROR_SCRIPT:
		# A resumed ending reconstructs an already broken mirror in _ready().
		# Bind afterwards so loading that save stays quiet.
		_bind_final_mirror.call_deferred(weakref(node))

func _bind_final_mirror(reference: WeakRef) -> void:
	var node: Node = reference.get_ref()
	if is_instance_valid(node):
		node.shattered.connect(func() -> void: play_effect(&"mirror_shatter"))

func _on_transported(_body: CharacterBody2D) -> void:
	if _is_gameplay() and not get_tree().paused:
		play_effect(&"mirror_pass")

func play_effect(cue: StringName) -> void:
	if not CUES.has(cue):
		return
	var data: Dictionary = CUES[cue]
	if _time - float(_last_played.get(cue, -100.0)) < float(data.cooldown):
		return
	_last_played[cue] = _time
	var slot := 0
	for i in _voices.size():
		if not _voices[i].playing:
			slot = i
			break
		if _started[i] < _started[slot]:
			slot = i
	var voice := _voices[slot]
	voice.stop()
	voice.stream = data.stream
	voice.volume_db = float(data.db)
	voice.pitch_scale = 1.0
	_started[slot] = _time
	voice.play()
	effect_played.emit(cue)
