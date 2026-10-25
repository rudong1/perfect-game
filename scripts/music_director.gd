extends Node
## Scene presentation only: continuous, quiet music with two-player crossfades.
signal track_changed(track: StringName)
const CREDITS = preload("res://scripts/music_credits.gd")
const TRACKS := {
	&"explore": "res://assets/audio/music/ghost_story.ogg",
	&"chase": "res://assets/audio/music/the_descent.ogg",
	&"reunion": "res://assets/audio/music/teller_of_the_tales.ogg",
}
const LOOP_CROSSFADE := 3.0
var current_track: StringName = &""
var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _levels := [0.0, 0.0]
var _from := [0.0, 0.0]
var _targets := [0.0, 0.0]
var _transition := 0.0
var _duration := 1.8
var _active := 0
var _duck := 1.0
var _duck_hold := 0.0
var _context_gain := 1.0
var _credits: CanvasLayer
var _shutting_down := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key in TRACKS:
		var stream := load(TRACKS[key]) as AudioStreamOggVorbis
		if stream == null:
			push_error("Missing music: " + TRACKS[key])
			continue
		# The director overlaps the end and start; the decoder must not hard-loop.
		stream.loop = false
		_streams[key] = stream
	for i in 2:
		var voice := AudioStreamPlayer.new()
		voice.name = "Music%d" % i
		voice.bus = &"Music"
		voice.volume_db = -80
		add_child(voice)
		_voices.append(voice)
	_credits = CanvasLayer.new()
	_credits.name = "MusicCredits"
	_credits.set_script(CREDITS)
	add_child(_credits)
	get_node("/root/SoundEffects").effect_played.connect(_on_effect_played)
	get_tree().set_auto_accept_quit(false)
	get_tree().root.close_requested.connect(_quit_safely)

func _process(delta: float) -> void:
	if _shutting_down:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var wanted := _track_for(scene)
	if wanted != current_track:
		transition_to(wanted, 0.20 if wanted == &"" else 1.8)
	var path := scene.scene_file_path
	_credits.set_available(path in ["res://scenes/ui/title_screen.tscn", "res://scenes/ui/ending_screen.tscn"])
	var gain := _gain_for(scene)
	if get_tree().paused or _credits.is_open:
		gain *= 0.55
	_context_gain = lerpf(_context_gain, gain, 1.0 - exp(-delta * 5.0))
	_duck_hold = maxf(0, _duck_hold - delta)
	if _duck_hold <= 0:
		_duck = lerpf(_duck, 1.0, 1.0 - exp(-delta * 2.0))
	_transition = minf(_transition + delta, _duration)
	var t := smoothstep(0.0, 1.0, _transition / maxf(_duration, 0.01))
	for i in 2:
		_levels[i] = lerpf(float(_from[i]), float(_targets[i]), t)
		var level: float = _levels[i] * _duck * _context_gain
		_voices[i].volume_db = linear_to_db(maxf(level, 0.0001))
		if _transition >= _duration and _targets[i] == 0.0:
			_voices[i].stop()
	if current_track != &"" and _transition >= _duration:
		var voice := _voices[_active]
		if voice.playing and voice.get_playback_position() >= voice.stream.get_length() - LOOP_CROSSFADE:
			transition_to(current_track, LOOP_CROSSFADE, true)

func _track_for(scene: Node) -> StringName:
	match scene.scene_file_path:
		"res://scenes/ui/title_screen.tscn", "res://scenes/opening/opening.tscn", "res://scenes/gameplay/gameplay.tscn":
			return &"explore"
		"res://scenes/ui/ending_screen.tscn":
			return &"reunion"
		"res://scenes/finale/finale.tscn":
			if scene.phase == scene.Phase.SHATTER:
				return &""
			if scene.phase in [scene.Phase.FUSION, scene.Phase.REUNION, scene.Phase.EMBRACE, scene.Phase.DEPARTURE]:
				return &"reunion"
			if scene.phase == scene.Phase.CHASE or (scene.attempts > 0 and scene.phase == scene.Phase.BETRAYAL):
				return &"chase"
			return &"explore"
	return &""

func _gain_for(scene: Node) -> float:
	if scene.scene_file_path == "res://scenes/opening/opening.tscn":
		return 0.65
	if scene.scene_file_path == "res://scenes/finale/finale.tscn":
		if scene.phase in [scene.Phase.THRESHOLD, scene.Phase.CONFESSION, scene.Phase.CROSSOVER]:
			return 0.60
		if scene.phase in [scene.Phase.FUSION, scene.Phase.REUNION]:
			return 0.72
	return 1.0

func transition_to(track: StringName, seconds: float = 1.8, loop_restart: bool = false) -> void:
	if track != &"" and not _streams.has(track):
		return
	if track == current_track and not loop_restart:
		return
	var old_track := current_track
	current_track = track
	_from = _levels.duplicate()
	_targets = [0.0, 0.0]
	_transition = 0.0
	_duration = maxf(seconds, 0.01)
	if track != &"":
		var slot := 1 - _active
		if not loop_restart:
			for i in 2:
				if _voices[i].stream == _streams[track] and _voices[i].playing:
					slot = i
					break
		if loop_restart or _voices[slot].stream != _streams[track] or not _voices[slot].playing:
			_voices[slot].stop()
			_voices[slot].stream = _streams[track]
			_voices[slot].play()
			_levels[slot] = 0.0
			_from[slot] = 0.0
		_active = slot
		_targets[slot] = 1.0
	if old_track != track:
		track_changed.emit(track)

func _on_effect_played(cue: StringName) -> void:
	var amount := 0.70
	var hold := 0.22
	if cue == &"mirror_shatter":
		amount = 0.22
		hold = 1.0
	elif str(cue).begins_with("crystal_"):
		amount = 0.48
		hold = 0.7
	_duck = minf(_duck, amount)
	_duck_hold = maxf(_duck_hold, hold)

func _exit_tree() -> void:
	_release_streams()

func _release_streams() -> void:
	for voice in _voices:
		voice.stop()
		voice.stream = null
	_streams.clear()

func prepare_shutdown() -> void:
	_shutting_down = true
	_release_streams()
	# Give the audio thread two output blocks to release Ogg decoders before
	# the engine tears it down. Wall time also handles fixed-fps test runners.
	var deadline := Time.get_ticks_msec() + 200
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame

func _quit_safely() -> void:
	if _shutting_down:
		return
	await prepare_shutdown()
	get_tree().quit()
