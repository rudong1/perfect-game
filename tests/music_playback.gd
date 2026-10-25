extends "res://tests/audio_mix.gd"
## Real-time scene, loop and combined-mix checks. Do not pass --fixed-fps.

func wait_seconds(seconds: float) -> void:
	await create_timer(seconds).timeout

func run() -> void:
	await process_frame
	sound = root.get_node("SoundEffects")
	var music: Node = root.get_node("MusicDirector")
	var state: Node = root.get_node("GameState")
	state.begin_game("星宁")
	capture = AudioEffectCapture.new()
	capture.buffer_length = 2.2
	var effect_slot := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, capture)
	change_scene_to_file("res://scenes/ui/title_screen.tscn")
	await wait_seconds(2.1)
	var bus := AudioServer.get_bus_index(&"Music")
	check(bus > 0 and AudioServer.get_bus_volume_db(bus) < -12.99, "BGM has its own low-volume bus")
	check(music.current_track == &"explore" and music._credits.visible, "title plays exploration music and offers credits")
	check(music._credits._button.get_global_rect().intersects(Rect2(0, 0, 1920, 1080)), "the attribution button is inside the visible screen")
	music._credits._button.pressed.emit()
	check(music._credits.is_open and music._credits._modal.visible, "the actual credits button opens the attribution panel")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await wait_seconds(0.1)
	check(not music._credits.is_open, "Escape closes credits without starting the game")
	var slot: int = music._active
	var position: float = music._voices[slot].get_playback_position()
	change_scene_to_file("res://scenes/opening/opening.tscn")
	await wait_seconds(0.2)
	check(music.current_track == &"explore" and music._active == slot and music._voices[slot].get_playback_position() >= position, "prologue continues the same playing music without a scene-change restart")
	change_scene_to_file("res://scenes/gameplay/gameplay.tscn")
	await wait_seconds(0.2)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_P
	event.keycode = KEY_P
	event.pressed = true
	Input.parse_input_event(event)
	await wait_seconds(0.1)
	check(paused and current_scene.collection_cg.active and music._voices[music._active].playing, "music is still playing during the real paused collection CG")
	var measured := await record([], 0.9, "music_explore_mixed.wav")
	check(measured.peak > 0.0001 and measured.peak < 0.14, "exploration BGM reaches Master quietly behind the CG")
	await wait_seconds(1.0)
	current_scene.collection_cg._dismiss()
	await wait_seconds(0.45)
	check(not paused and music.current_track == &"explore", "continuing a pickup restores gameplay without replacing the exploration track")
	state.current_level = 4
	state.collected_mask = 7
	change_scene_to_file("res://scenes/finale/finale.tscn")
	await wait_seconds(0.2)
	var finale: Node2D = current_scene
	finale._start_chase()
	await wait_seconds(1.9)
	check(music.current_track == &"chase", "the pursuit plays the selected tension score even after a chase retry")
	music._voices[music._active].seek(30.0)
	measured = await record([], 1.0, "music_chase_mixed.wav")
	check(measured.peak > 0.0001 and measured.peak < 0.14, "the energetic chase score remains at a quiet output level")
	finale._break_mirror()
	await wait_seconds(0.35)
	check(music.current_track == &"" and not music._voices[0].playing and not music._voices[1].playing, "both music voices fade out promptly for the glass impact")
	await wait_seconds(0.8)
	check(music.current_track == &"explore", "confession brings back the restrained exploration atmosphere")
	finale._begin_fusion()
	await wait_seconds(1.9)
	check(music.current_track == &"reunion", "giving colours begins the warmer ending track")
	music._voices[music._active].seek(35.0)
	measured = await record([&"mirror_flip", &"mirror_shatter", &"mirror_pass", &"crystal_green"], 1.9, "music_with_four_effects.wav")
	check(measured.peak > 0.002 and measured.peak < 0.30, "music plus four effects stays quiet, ducked and unclipped at Master")
	var outgoing: int = music._active
	music._voices[outgoing].seek(music._voices[outgoing].stream.get_length() - 3.1)
	await wait_seconds(0.35)
	check(music._active != outgoing and music._voices[0].playing and music._voices[1].playing, "looping overlaps the end and beginning using both real audio players")
	await wait_seconds(3.2)
	check(not music._voices[outgoing].playing and music._voices[music._active].playing and music.current_track == &"reunion", "the loop finishes its crossfade without silence or a third voice")
	slot = music._active
	position = music._voices[slot].get_playback_position()
	change_scene_to_file("res://scenes/ui/ending_screen.tscn")
	await wait_seconds(0.25)
	check(music.current_track == &"reunion" and music._active == slot and music._voices[slot].get_playback_position() >= position and music._credits.visible, "the ending preserves the reunion playback position and exposes attribution")
	AudioServer.remove_bus_effect(0, effect_slot)
	print("MUSIC PLAYBACK TESTS: %d checks, %d failures" % [checks, failures])
	await music.prepare_shutdown()
	quit(1 if failures else 0)
