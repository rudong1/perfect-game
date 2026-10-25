extends SceneTree
## Run with --headless --fixed-fps 60 --script res://tests/mirror_mechanics.gd
## Set XDG_DATA_HOME to a disposable directory: this suite exercises real saves.
var failures := 0
var checks := 0
var game: Node2D
var state: Node
var mirror: Node
var _heard: Array[StringName] = []
var _music_tracks: Array[StringName] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame

func release_controls() -> void:
	for action in ["move_left", "move_right", "sprint", "jump"]:
		Input.action_release(action)

func room(index: int) -> void:
	release_controls()
	state.current_level = index
	state.has_checkpoint = false
	game.load_level()
	await frames(8)

func walk_to(x: float) -> void:
	var action := "move_right" if x > game.player.global_position.x else "move_left"
	Input.action_press(action)
	for i in 650:
		await physics_frame
		if game._busy or absf(game.player.global_position.x - x) < 5:
			break
		if (action == "move_right" and game.player.global_position.x >= x) or (action == "move_left" and game.player.global_position.x <= x):
			break
	Input.action_release(action)
	await frames(4)

func flip_to(value: bool) -> void:
	mirror.set_mirrored(value)
	await frames(135)

func key_p(echo_event: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_P
	event.keycode = KEY_P
	event.pressed = true
	event.echo = echo_event
	Input.parse_input_event(event)
	await frames(3)
	event = InputEventKey.new()
	event.physical_keycode = KEY_P
	event.keycode = KEY_P
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)

func text_nodes(node: Node) -> Array[Label]:
	var labels: Array[Label] = []
	if node is Label:
		labels.append(node)
	for child in node.get_children():
		labels.append_array(text_nodes(child))
	return labels

func key_e() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event = InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = false
	Input.parse_input_event(event)
	await frames(10)

func press_key(code: Key, repeat: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	event.echo = repeat
	Input.parse_input_event(event)
	await frames(2)
	event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)

func view_pickup(index: int, resume_save: bool = true) -> void:
	var cg: CanvasLayer = game.collection_cg
	var music: Node = root.get_node("MusicDirector")
	check(music.current_track == &"explore" and not music._credits.visible and (music._voices[0].playing or music._voices[1].playing), "exploration music keeps playing quietly behind the paused pickup without showing credit UI over the CG")
	var cues := [&"crystal_red", &"crystal_blue", &"crystal_green"]
	check(not _heard.is_empty() and _heard.back() == cues[index], "actual and developer pickups play the matching quiet colour chime before the CG pause")
	var heard_before := _heard.size()
	check(paused and cg.active and cg.art_index == index and state.current_level == index, "a real pickup pauses the room in the matching CG before advancing")
	var expected_art := ["collect_red.png", "collect_blue.png", "collect_green.png"]
	check(cg._art.texture.resource_path.ends_with(expected_art[index]) and cg._art.texture.get_width() >= 1600, "each RGB pickup uses its own full-resolution illustration")
	check(cg.layer > 110 and cg.process_mode == Node.PROCESS_MODE_ALWAYS and cg._heading.text.contains(state.get_level(index).color_name), "CG art and readable colour captions render above the mirrored world and HUD")
	check(cg._caption.text == cg.CAPTIONS[index] and not cg._caption.text.contains("darksky"), "each pickup has a different understated memory without revealing the companion's true name")
	var heroine_at: Vector2 = game.player.position
	var echo_at: Vector2 = game.echo.position
	var was_mirrored: bool = mirror.mirrored
	await press_key(KEY_ENTER)
	check(cg.active and not cg.armed, "input carried over from collection cannot instantly dismiss the CG")
	for code in [KEY_M, KEY_E, KEY_R, KEY_P]:
		await press_key(code)
	Input.action_press("move_right")
	Input.action_press("jump")
	await frames(12)
	release_controls()
	check(game.player.position == heroine_at and game.echo.position == echo_at and mirror.mirrored == was_mirrored and state.current_level == index, "movement, jump, flip, transport, restart and developer skip cannot alter a paused pickup")
	check(_heard.size() == heard_before, "blocked gameplay keys produce no sound behind the collection CG")
	await frames(120)
	check(cg.armed and cg._continue.visible and state.current_level == index, "the CG stays visible after its minimum viewing time until a fresh confirmation")
	await press_key(KEY_ENTER, true)
	check(cg.active and not cg._closing, "held Enter does not dismiss the memory")
	if index == 1 and resume_save:
		# Simulate closing the game during the CG, then use the actual Continue UI.
		change_scene_to_file("res://scenes/ui/title_screen.tscn")
		await frames(6)
		check(not paused, "removing an open CG releases its owned scene-tree pause")
		current_scene._continue()
		await frames(10)
		game = current_scene
		cg = game.collection_cg
		check(paused and cg.active and cg.art_index == index and state.current_level == index and state.collected_count() == 2, "Continue resumes the interrupted blue CG with the saved colour and no repeated puzzle")
		check(_heard.size() == heard_before, "Continue does not replay a pickup sound for a colour already saved")
		await frames(120)
	# Exercise both supported confirmation methods with real input events.
	if index == 1:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		Input.parse_input_event(click)
		await frames(2)
		click = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = false
		Input.parse_input_event(click)
	else:
		await press_key(KEY_ENTER)
	await frames(30)
	check(not paused and not cg.active and state.current_level == index + 1 and state.collected_count() == index + 1, "confirming the CG resumes the next colour world once without duplicate collection")

func push_to(slab: StaticBody2D, target_x: float) -> void:
	var direction := 1.0 if target_x > slab.position.x else -1.0
	await walk_to(slab.position.x - direction * 55)
	var action := "move_right" if direction > 0 else "move_left"
	Input.action_press(action)
	for tick in 420:
		await physics_frame
		if direction * (slab.position.x - target_x) >= 0:
			break
	Input.action_release(action)
	await frames(15)

func solve_twins(index: int) -> void:
	if index == 0:
		await flip_to(false)
		await walk_to(650)
		await frames(40)
		await walk_to(430)
		await frames(12)
		var lesson: Node = game.level_root.get_node("RoomPuzzle")
		check(lesson.solved_steps == 1 and not game._goal.enabled, "the first reverse pair leaves two more cooperative gates locked")
		await flip_to(true)
		await walk_to(980)
		await frames(12)
		check(lesson.solved_steps == 2 and not game._goal.enabled, "a second ceiling pair still leaves the narrower return seal to solve")
		await walk_to(1240)
		await flip_to(false)
		check(state.has_checkpoint and state.checkpoint_stage == 2, "the midpoint checkpoint saves the two completed gates")
		await walk_to(1620)
		await frames(40)
		await walk_to(1420)
	else:
		await flip_to(true)
		await walk_to(605)
		await frames(40)
		await walk_to(380)
	await frames(12)

func solve_red_entry() -> void:
	await flip_to(true)
	await walk_to(640)
	await frames(40)
	await walk_to(430)
	await frames(12)
	var puzzle: Node = game.level_root.get_node("RoomPuzzle")
	check(puzzle.solved_steps == 1 and not game._goal.enabled, "red begins with a real twin-operated gate before the moving mirror")
	await flip_to(false)

func solve_red_return(slab: StaticBody2D) -> void:
	await push_to(slab, 940)
	if game.player.position.x < slab.position.x:
		await walk_to(810)
		await key_e()
	await walk_to(1070)
	await key_e()
	check(game.level_root.get_node("RoomPuzzle").solved_steps == 3 and game._goal.enabled, "the reverse calibration and actual arrival solve the third red mechanism")
	await key_e()

func solve_light() -> void:
	var circuit: Node2D = game.level_root.get_node("PrismCircuit")
	var slab: StaticBody2D = game.level_root.get_node("MirrorSlab")
	if mirror.mirrored:
		await walk_to(300)
		await flip_to(false)
	await walk_to(600)
	await frames(40)
	check(circuit.source_unlocked(0), "the ceiling echo physically unlocks the red source seal")
	await walk_to(520)
	mirror.set_mirrored(not mirror.mirrored)
	await frames(135)
	check(circuit.upward == [true, false, false] and circuit.channel_mask == 1, "first flip rotates only the nearby red reflector")
	await push_to(slab, 1040)
	await frames(40)
	check(slab.position.x >= 1040 and slab.position.x < 1100, "real A/D movement pushes the optical blocker out of the green beam")
	check(circuit.source_unlocked(1), "after the flip the floor echo opens the green source seal")
	await walk_to(960)
	mirror.set_mirrored(not mirror.mirrored)
	await frames(135)
	check(circuit.channel_mask == 3 and state.restored_channel_count() == 2, "two live colors give near-success feedback")
	var entry: Vector2 = game.player.position
	var expected: Vector2 = slab.exit_for(entry)
	await key_e()
	check(slab.used and absf(game.player.position.x - expected.x) < 2, "real E input transports across the moving X axis")
	check(absf(game.echo.position.x - game.player.position.x) < 2, "late-room transit brings the physical echo across the slab with the heroine")
	await walk_to(1460)
	await frames(40)
	check(circuit.unlocked_source_count() == 3, "the regrouped ceiling echo opens the final blue seal")
	await walk_to(1400)
	mirror.set_mirrored(not mirror.mirrored)
	await frames(135)
	check(circuit.channel_mask == 7 and state.has_rainbow() and state.colored_rays().size() == 3, "echo seals and M push M transit M restore three actual geometric rays")
	check(not game._goal.enabled, "three live colours alone cannot replace the final pair of actors")
	await solve_light_exit()

func solve_light_exit() -> void:
	await walk_to(1595)
	if mirror.mirrored:
		await flip_to(false)
	await frames(40)
	await walk_to(1390)
	await frames(12)
	check(game._goal.enabled, "a real return stride lets heroine and echo complete the live-light exit together")

func prepare_chase(scene: Node2D) -> void:
	check(scene.phase == scene.Phase.THRESHOLD and scene.shadow.scale.y < 0, "the finale starts with the companion still on the opposite side")
	check(scene.backdrop.color_mask == 7 and scene.backdrop._palettes[0].get_shader_parameter("color_mask") == 7, "the chase architecture receives all three collected colours")
	for i in scene.REVELATION_BEATS.size():
		await frames(21)
		if i == 1:
			check(scene._caption.text.contains("不算活着") and not scene._caption.text.contains("darksky"), "her failed passage explains the missing living colour before revealing her name")
		scene._next.pressed.emit()
	check(scene.phase == scene.Phase.CROSSOVER, "the request for colour leads into a visible crossing of the mirror boundary")
	await frames(85)
	check(scene.phase == scene.Phase.BETRAYAL and scene.shadow.scale.y > 0 and scene.shadow.position.x < scene.player.position.x, "the companion visibly reaches the same floor behind the protagonist")

func run() -> void:
	await process_frame
	state = root.get_node("GameState")
	mirror = root.get_node("MirrorState")
	var sound: Node = root.get_node("SoundEffects")
	sound.effect_played.connect(func(cue: StringName) -> void: _heard.append(cue))
	var music: Node = root.get_node("MusicDirector")
	music.track_changed.connect(func(track: StringName) -> void: _music_tracks.append(track))
	var effects_bus := AudioServer.get_bus_index(&"SFX")
	check(effects_bus > 0 and AudioServer.get_bus_volume_db(effects_bus) < -7.99 and is_zero_approx(AudioServer.get_bus_volume_db(0)), "effects use their own quiet bus without turning down the master output")
	var title: Control = load("res://scenes/ui/title_screen.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	check(title.get_node("Title").text == state.GAME_TITLE, "the title screen uses the poetic game name")
	check(title.backdrop.texture.resource_path.ends_with("mirror_hands.png"), "the title uses the generated girl-and-reflection illustration")
	title.name_edit.text = "测试"
	title.begin_button.pressed.emit()
	await frames(8)
	check(current_scene.scene_file_path.ends_with("opening.tscn"), "a new journey preserves the remote prologue")
	check(music.current_track == &"explore", "the prologue uses the same quiet exploration score as the title")
	check(current_scene.get_node("Photo").texture.resource_path.ends_with("mirror_hands.png"), "the prologue preserves the illustrated single-palm meeting")
	check(not mirror.input_enabled and not mirror.mirrored, "prologue keeps gameplay mirroring disabled")
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	Input.parse_input_event(enter)
	await frames(3)
	check(not current_scene._entering, "prologue ignores input carried over from the title")
	await frames(50)
	for i in current_scene.STORY_LINES.size():
		Input.parse_input_event(enter)
		await frames(2)
		if i == 1:
			check(current_scene.caption.text.contains("测试") and not current_scene.caption.text.contains("darksky"), "the named newcomer meets a reflection whose true name is still withheld")
	await frames(100)
	game = current_scene
	check(game.scene_file_path.ends_with("gameplay.tscn") and mirror.input_enabled, "Enter moves from the prologue into the playable church")
	check(music.current_track == &"explore" and _music_tracks.count(&"explore") == 1, "entering gameplay preserves the exploration music instead of restarting it")
	await frames(8)
	var player: CharacterBody2D = game.player
	var shadow: CharacterBody2D = game.echo
	check(shadow.global_position.distance_to(mirror.reflect_point(player.global_position)) < 1, "shadow starts across shared mirror axis")
	check(shadow.sprite.material != null, "shadow retains its distinct smoky tint")
	check(_heard.is_empty(), "title, prologue and initial mirror setup stay quiet")
	await press_key(KEY_M)
	check(mirror.mirrored and _heard.count(&"mirror_flip") == 1, "an actual successful M flip plays exactly one glass-and-air cue")
	await press_key(KEY_M, true)
	check(_heard.count(&"mirror_flip") == 1, "held mirror input does not repeat the sound")
	mirror.reset()
	await frames(3)
	check(_heard.count(&"mirror_flip") == 1, "programmatic mirror reset never plays a false flip sound")
	await room(0)
	Input.action_press("move_right")
	await frames(12)
	check(absf(shadow.velocity.x) < 1 and player.velocity.x > 100, "shadow visibly waits before following")
	await frames(35)
	check(shadow.velocity.x > 100 and player.position.x - shadow.position.x > 60, "shadow follows with a real delay")
	release_controls()
	await room(0)
	await flip_to(true)
	check(player.up_direction == Vector2.DOWN and player.is_on_floor(), "flipped ceiling is a physical floor")
	check(shadow.is_on_floor() and absf(shadow.global_position.y - 900) < 2, "shadow uses opposite gravity")
	Input.action_press("jump")
	await frames(4)
	check(player.velocity.y > 0 and absf(shadow.velocity.y) < 1, "only the protagonist jumps")
	Input.action_release("jump")
	await frames(60)
	for hint in get_nodes_in_group("readable_hints"):
		hint._process(0)
		check(hint.layer > 100 and hint.label.scale == Vector2.ONE, "world text stays upright above mirror")
		check((hint.label.position + hint.label.size * 0.5).distance_to(hint.screen_anchor()) < 0.1, "readable text tracks reflected world anchor")
	var renderer: CanvasLayer = player.get_node("ScreenMirror")
	mirror.axis_y = 590
	renderer._process(0)
	var projected: Vector2 = root.get_canvas_transform() * Vector2(0, mirror.axis_y)
	check(is_equal_approx(renderer._mirror_material.get_shader_parameter("axis_y"), projected.y / root.get_visible_rect().size.y), "render axis is projected from shared physics axis")
	mirror.axis_y = 540
	await room(0)
	player.global_position = Vector2(400, 930)
	mirror.set_mirrored(true)
	await frames(4)
	check(MirrorSafety.is_clear(player, player.global_position), "flip safely relocates an embedded capsule")

	# Retained pushable prop must not play run/sprint, even with Shift held.
	await room(0)
	var slab := StaticBody2D.new()
	slab.set_script(load("res://scripts/mirror_slab.gd"))
	slab.position = Vector2(650, 900)
	game.level_root.add_child(slab)
	player.position = Vector2(590, 900)
	await frames(3)
	Input.action_press("move_right")
	Input.action_press("sprint")
	await frames(55)
	check(slab.position.x > 690, "pushing still moves the prop")
	check(player.is_pushing and player.current_animation == "push", "pushing uses a stable stance instead of running")
	check(absf(player.velocity.x) <= player.PUSH_SPEED + 1 and player.sprite.speed_scale == 1, "Shift cannot accelerate push animation")
	release_controls()
	await frames(20)
	check(not player.is_pushing and absf(slab.push_velocity) < 0.1, "releasing push clears stance and friction stops prop")

	await room(0)
	check(not game._goal.enabled, "developer colour pickup starts with the ordinary puzzle still locked")
	await key_p()
	check(state.current_level == 0 and state.has_color(0) and game.collection_cg.active, "P immediately grants the actual red colour and opens its CG without solving the room")
	await key_p(true)
	check(state.current_level == 0 and state.collected_count() == 1, "held P cannot repeat a pickup or advance past its CG")
	await view_pickup(0, false)
	await key_p(true)
	check(state.current_level == 1 and not state.has_color(1), "held P carried into the next room cannot collect its colour")
	for index in [1, 2]:
		await key_p()
		check(state.current_level == index and state.has_color(index) and game.collection_cg.active, "P grants the corresponding colour in each later collectible room")
		await view_pickup(index, false)
	check(state.current_level == 3 and state.collected_mask == 7, "three developer pickups retain a real full RGB inventory for the finale")
	for label in text_nodes(game):
		check(not label.text.contains("P") and not label.text.contains("落点 x"), "player text keeps the developer shortcut and debug coordinates hidden")

	# Migrate an old save without reusing its incompatible checkpoint geometry.
	var legacy := ConfigFile.new()
	legacy.set_value("game", "current_level", 2)
	legacy.set_value("game", "completed_levels", 2)
	legacy.set_value("game", "has_checkpoint", true)
	legacy.set_value("game", "checkpoint_position", Vector2(1540, 900))
	legacy.save(state.SAVE_PATH)
	check(state.load_from_disk() and state.collected_count() == 2 and not state.has_checkpoint, "old saves retain progress and discard stale checkpoints")
	legacy.set_value("game", "version", 3)
	legacy.set_value("game", "checkpoint_position", Vector2(3100, 900))
	legacy.set_value("game", "checkpoint_stage", 2)
	legacy.set_value("game", "collected_mask", 3)
	legacy.save(state.SAVE_PATH)
	check(state.load_from_disk() and state.collected_count() == 2 and not state.has_checkpoint, "scrolling-room saves migrate safely into the restored single-screen rooms")
	legacy.set_value("game", "version", 4)
	legacy.set_value("game", "current_level", 4)
	legacy.set_value("game", "collected_mask", 7)
	legacy.save(state.SAVE_PATH)
	check(state.load_from_disk() and state.is_finale_pending() and state.collected_count() == 3, "previously finished saves can enter the new finale with their colours preserved")
	legacy.set_value("game", "version", 5)
	legacy.set_value("game", "ending_reached", true)
	legacy.save(state.SAVE_PATH)
	check(state.load_from_disk() and state.is_finale_pending() and not state.darksky_revived and state.collected_count() == 3, "a completed old disappearance ending can resume the new rescue with its colours")
	legacy.set_value("game", "current_level", 1)
	legacy.set_value("game", "checkpoint_level", 1)
	legacy.set_value("game", "checkpoint_stage", 1)
	legacy.save(state.SAVE_PATH)
	check(state.load_from_disk() and not state.has_checkpoint, "old early-room checkpoints do not bypass the new mechanisms")
	legacy.set_value("game", "version", 6)
	legacy.set_value("game", "current_level", 4)
	legacy.set_value("game", "collected_mask", 0)
	legacy.set_value("game", "offered_mask", 7)
	legacy.set_value("game", "darksky_revived", true)
	legacy.save(state.SAVE_PATH)
	check(state.load_from_disk() and state.is_finale_pending() and state.darksky_revived and state.collected_count() == 0, "a completed older rescue resumes the new face and embrace without refunding the colours")
	legacy.set_value("game", "current_level", 3)
	legacy.set_value("game", "collected_mask", 7)
	legacy.set_value("game", "offered_mask", 0)
	legacy.set_value("game", "darksky_revived", false)
	legacy.set_value("game", "checkpoint_level", 3)
	legacy.set_value("game", "checkpoint_stage", 1)
	legacy.save(state.SAVE_PATH)
	check(state.load_from_disk() and state.current_level == 3 and state.collected_count() == 3 and not state.has_checkpoint, "old late-room checkpoints retain colours while restarting the new shadow mechanisms")
	state.begin_game("测试")

	var frames_resource: SpriteFrames = player.sprite.sprite_frames
	check(frames_resource.get_frame_count("run") == 8 and frames_resource.get_frame_count("sprint") == 8, "eight actual run frames replace four-frame motion")
	var running_texture := frames_resource.get_frame_texture("run", 0) as AtlasTexture
	check(running_texture.atlas.resource_path.ends_with("hero_run.png"), "locomotion uses the redrawn arm-swing cycle instead of the chest-fist poses")
	HeroAnimation.play(player.sprite, "run")
	player.sprite.set_frame_and_progress(4, 0.37)
	HeroAnimation.play(player.sprite, "sprint")
	check(player.sprite.frame == 4 and absf(player.sprite.frame_progress - 0.37) < 0.01, "sprinting preserves both arm and leg phase without restarting the stride")
	var normal_scale: Vector2 = player.sprite.scale
	var normal_offset: Vector2 = player.sprite.offset
	player._play("reach")
	HeroAnimation.play(player.sprite, "reach")
	check(absf(player.sprite.scale.y) < absf(normal_scale.y) and not frames_resource.get_animation_loop("reach"), "the calm single-palm pose normalizes once and holds instead of looping a push")
	player._play("idle")
	check(player.sprite.scale.is_equal_approx(normal_scale) and player.sprite.offset == normal_offset, "returning from the farewell gesture restores the normal actor scale and foot origin")
	check(frames_resource.get_frame_count("land") >= 3 and frames_resource.has_animation("apex") and frames_resource.has_animation("stop"), "landing, apex and braking transitions exist")
	for animation in frames_resource.get_animation_names():
		for i in frames_resource.get_frame_count(animation):
			var frame_texture: AtlasTexture = frames_resource.get_frame_texture(animation, i)
			var canvas_size := Vector2(400, 500) if animation == &"reach" else Vector2(320, 380)
			check(frame_texture.get_size() == canvas_size, "each pose uses its stable logical canvas")
			if animation == &"reach":
				check(Rect2(Vector2.ZERO, canvas_size).encloses(Rect2(frame_texture.margin.position, frame_texture.region.size)), "the larger farewell canvas contains the entire hair, head and soles")
	# A translated portal destination is checked against actual world collision.
	await room(1)
	var transport: StaticBody2D = game.level_root.get_node("MirrorSlab")
	var red_puzzle: Node = game.level_root.get_node("RoomPuzzle")
	check(red_puzzle.steps.size() == 3 and not red_puzzle.steps[1].marker.visible and not red_puzzle.steps[2].marker.visible, "red's two calibration marks remain hidden until their own mechanism is active")
	await solve_red_entry()
	check(red_puzzle.steps[1].marker.visible, "opening the entry gate reveals the first calibration mark")
	await push_to(transport, 1080)
	check(transport.position.x >= 1040 and transport.position.x <= 1120, "pushing reaches the marked transport interval")
	var before: Vector2 = player.position
	var exit: Vector2 = transport.exit_for(before)
	await key_e()
	check(transport.used and absf(player.position.x - exit.x) < 2, "E uses the exact horizontal reflection formula")
	check(_heard.back() == &"mirror_pass", "successful physical transport plays its quiet portal cue")
	check(not game._goal.enabled, "crossing a calibrated mirror without landing on the receiver does not open the corridor")
	await walk_to(1230)
	check(not game._goal.enabled, "walking onto the receiver cannot substitute for the correctly reflected arrival")
	await key_e()
	await key_e()
	check(red_puzzle.solved_steps == 2 and not game._goal.enabled, "a correct first transit still leaves the reverse-mirror mechanism locked")
	check(not red_puzzle.steps[1].marker.visible and red_puzzle.steps[2].marker.visible, "the return mechanism reveals a different mirror calibration")
	check(absf(transport.push_velocity) < 0.1, "friction stops the mirror after input releases")
	await walk_to(1300)
	check(state.checkpoint_stage == 2, "red's second checkpoint remembers the entry gate and outward transit")
	player.respawn()
	await frames(12)
	check(red_puzzle.solved_steps == 2 and not transport.used and not game._goal.enabled, "retry restores earned doors without inventing the return transit")
	await walk_to(930)
	await key_e()
	await solve_red_return(transport)
	player.position = Vector2(transport.position.x + 100, 900)
	exit = transport.exit_for(player.position)
	var blocker := StaticBody2D.new()
	blocker.position = exit - Vector2(0, 80)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(70, 170)
	collision.shape = shape
	blocker.add_child(collision)
	game.level_root.add_child(blocker)
	await frames(3)
	before = player.position
	var sounds_before_blocked := _heard.size()
	check(not transport.try_transport(player), "a real body at the exit blocks unsafe transport")
	check(player.position.distance_to(before) < 0.1, "failed transit leaves the player in place")
	check(_heard.size() == sounds_before_blocked, "a rejected portal does not sound like a successful crossing")
	blocker.queue_free()
	await frames(2)

	await room(2)
	var circuit: Node2D = game.level_root.get_node("PrismCircuit")
	transport = game.level_root.get_node("MirrorSlab")
	check(not state.has_rainbow() and circuit.channel_mask == 0, "saved color progress cannot power a new optical puzzle")
	player.set_physics_process(false)
	player.position = Vector2(490, 210)
	await frames(8)
	check(circuit.shadow_locks[0].get_overlapping_bodies().has(player) and not circuit.source_unlocked(0), "physical protagonist contact cannot impersonate the echo at a shadow seal")
	for i in 3:
		circuit.upward[i] = true
	circuit.update_beams()
	check(circuit.channel_mask == 0, "correct reflector angles cannot bypass the three closed shadow shutters")
	await room(2)
	circuit = game.level_root.get_node("PrismCircuit")
	transport = game.level_root.get_node("MirrorSlab")
	await solve_light()
	check(game._goal.enabled, "three live beams enable the color fragment")
	transport.position.x = 1160
	await frames(12)
	check(circuit.channel_mask == 3 and not state.has_rainbow(), "moving the slab onto the blue path physically occludes it")
	check(not game._goal.enabled and not game.level_root.get_node("RoomPuzzle").steps.back().door.is_open, "breaking a beam closes the paired exit and fragment again")
	transport.position.x = 1040
	await frames(12)
	check(not game._goal.enabled, "restoring the beam alone does not invent a new completed duet")
	await solve_light_exit()
	for hint in get_nodes_in_group("readable_hints"):
		hint._process(0)
		check(hint.layer > 100 and hint.label.scale == Vector2.ONE, "restored mirror and receiver labels stay upright")
	player.respawn()
	await frames(12)
	check(circuit.upward == [false, false, false] and not transport.used and not game._goal.enabled, "death resets mirror transit and optical orientations")
	check(circuit.unlocked_source_count() == 0, "retry also clears every latched shadow-operated source seal")
	check(not state.has_rainbow() and state.restored_channel_count() == 0, "reset clears transient light state")
	await room(3)
	var finale: Node = game.level_root.get_node("RoomPuzzle")
	await solve_twins(3)
	check(finale.solved_steps == 1 and not game._goal.enabled, "twin cooperation alone cannot bypass the combined optical finale")
	state.save_checkpoint(3, Vector2(270, 900), 1)
	player.respawn_position = Vector2(270, 900)
	player.respawn()
	await frames(3)
	check(finale.solved_steps == 1 and not game._goal.enabled, "checkpoints restore twin progress without supplying missing rays")
	state.begin_game("同行")
	await room(0)
	var unique_colors: Array = []
	for index in 4:
		check(state.current_level == index, "room %d is reached in sequence" % (index + 1))
		check(get_nodes_in_group("shadow_bridges").is_empty() and not game.level_root.has_node("ShadowBarrier"), "campaign restores the original three mechanics")
		check(bool(game._background.get_shader_parameter("use_scene_texture")) and game._background.get_shader_parameter("scene_texture") == game.CHURCH_BACKGROUNDS[index], "world uses its authored cathedral background")
		check(game.CHURCH_BACKGROUNDS[index].get_width() >= 1600 and game._world_width == 1920, "background and room retain the single-screen composition")
		check(game.level_root.get_node("RegionDressing").region == index, "each colour region has distinct physical-looking set dressing")
		check(not game.level_root.has_node("Candlelight"), "no procedural candle flames or amber glows remain")
		var draw_calls := 80
		for visual in get_nodes_in_group("gothic_visuals"):
			draw_calls += int(visual.get_meta("draw_calls"))
		check(draw_calls < 300, "region set dressing remains inside the drawing budget")
		var has_save_label := false
		for label in text_nodes(game):
			has_save_label = has_save_label or label.text == "存档点"
		check(not has_save_label, "save shrines use a symbol without a floating text label")
		if index < 3:
			unique_colors.append(state.get_level().collect_color)
		var puzzle: Node = game.level_root.get_node("RoomPuzzle")
		check(not game._goal.enabled, "color/exit stays locked before cooperating")
		var palette: Dictionary = state.get_level()
		if index == 0:
			check(absf(palette.bg_bottom.r - palette.bg_bottom.b) < 0.04, "initial world has a monochrome palette")
		elif index == 1:
			check(palette.bg_bottom.r > palette.bg_bottom.b, "red pickup leads to red atmosphere")
		elif index == 2:
			check(palette.bg_bottom.b > palette.bg_bottom.r, "blue pickup leads to blue atmosphere")
		else:
			check(palette.bg_bottom.g > palette.bg_bottom.r and state.collected_count() == 3, "green pickup enters a playable green world with full progress")
		if index == 0:
			await solve_twins(0)
		elif index == 1:
			await solve_red_entry()
			var campaign_slab: StaticBody2D = game.level_root.get_node("MirrorSlab")
			await push_to(campaign_slab, 1080)
			await walk_to(930)
			await key_e()
			check(puzzle.solved_steps == 2 and not game._goal.enabled, "outward reflection alone does not finish the harder red room")
			await solve_red_return(campaign_slab)
		elif index == 2:
			await solve_light()
		else:
			await solve_twins(3)
			check(puzzle.solved_steps == 1 and not game._goal.enabled, "final room first requires real twin contact")
			await solve_light()
		for step in puzzle.steps:
			check(step.door.is_open, "actual inputs solve world %d %s challenge" % [index + 1, step.kind])
		check(game._goal.enabled, "cooperation unlocks the room's color")
		await flip_to(false)
		await walk_to(1740)
		check(state.collected_count() == mini(index + 1, 3) and (index == 3 or state.has_color(index)), "three colors fill progress; green-world exit adds no extra color")
		check(not state.collect_current_color(), "duplicate collection cannot inflate prism progress")
		if index < 3:
			await view_pickup(index)
		else:
			await frames(80)
		check(state.current_level == index + 1, "a colour advances after its illustrated memory, while the final exit goes directly to the finale")
	check(unique_colors.size() == 3 and unique_colors[0].r > unique_colors[0].b and unique_colors[1].b > unique_colors[1].r and unique_colors[2].g > unique_colors[2].r, "collectibles are exactly red, blue, green in order")
	check(state.is_finale_pending() and not state.is_game_complete() and current_scene.scene_file_path.ends_with("finale.tscn"), "green-world exit leads to the playable betrayal instead of prematurely completing the story")
	check(state.load_from_disk() and state.is_finale_pending() and state.collected_count() == 3, "an unfinished finale resumes with all colours intact")
	change_scene_to_file("res://scenes/ui/title_screen.tscn")
	await frames(6)
	state.collected_mask = 0
	state.ending_reached = true
	current_scene._continue()
	await frames(6)
	check(current_scene.scene_file_path.ends_with("finale.tscn") and state.collected_count() == 3, "Continue actually reloads the saved chase instead of restarting the puzzles")
	var chase: Node2D = current_scene
	var glass_cues := _heard.count(&"mirror_shatter")
	check(not Geometry2D.triangulate_polygon(chase.mirror_body._outline).is_empty(), "the generated mirror has valid fragmentation bounds")
	check(chase.mirror_body._graphic.texture is AtlasTexture, "the giant mirror uses the generated Gothic artwork")
	await prepare_chase(chase)
	await frames(50)
	Input.action_press("move_right")
	await frames(40)
	Input.action_release("move_right")
	for tick in 180:
		await physics_frame
		if chase.attempts > 0:
			break
	check(chase.attempts == 1 and state.collected_count() == 3, "being caught retries the chase without losing any collected colour")
	await frames(45)
	Input.action_press("move_right")
	Input.action_press("sprint")
	var parallax_seen := false
	for tick in 900:
		await physics_frame
		if not parallax_seen and chase.camera.position.x > 1300:
			check(chase.backdrop.near_strip.position.x < chase.backdrop.far_strip.position.x and chase.backdrop.far_strip.position.x < 0, "both architecture layers move with the camera at different depths")
			check(music.current_track == &"chase", "the real running chase crossfades to the tension score")
			parallax_seen = true
		if chase.phase == chase.Phase.SHATTER:
			break
	release_controls()
	check(parallax_seen, "the chase actually scrolls the church instead of only shifting the paving")
	check(chase.mirror_body.is_broken and chase.player.position.x >= chase.MIRROR_X - chase.mirror_body.impact_distance - 8, "actual rightward movement reaches and shatters the giant blocking mirror")
	check(_heard.count(&"mirror_shatter") == glass_cues + 1, "the actual giant-mirror impact plays one soft shatter with a falling-glass tail")
	chase.mirror_body.shatter()
	check(_heard.count(&"mirror_shatter") == glass_cues + 1, "an already shattered mirror cannot replay the impact sound")
	await frames(2)
	check(music.current_track == &"", "music falls away at the giant-mirror impact so glass remains audible")
	var glass_is_valid: bool = not chase.mirror_body._shards.is_empty()
	for shard in chase.mirror_body._shards:
		glass_is_valid = glass_is_valid and not Geometry2D.triangulate_polygon(shard.points).is_empty() and shard.uvs.size() == shard.points.size()
	check(glass_is_valid, "all clipped glass fragments remain valid renderable polygons")
	await frames(70)
	check(chase.phase == chase.Phase.CONFESSION and not chase.shadow.visible, "breaking the mirror stops the pursuit and leaves an image in a shard")
	check(music.current_track == &"explore", "the confession returns to a restrained, quiet atmosphere")
	check(chase._caption.text.contains("赠予") and chase._memory_glass.visible, "the mirror's newly revealed inscription explains voluntary giving before the rescue")
	check(not state.is_game_complete(), "the finale waits for the rescue before marking the journey complete")
	chase._next.pressed.emit()
	check(chase.confession_index == 0, "the shatter input cannot accidentally skip her explanation")
	var heard_apology := false
	var heard_response := false
	var heard_history := false
	for i in chase.CONFESSION_BEATS.size():
		check(not chase._caption.text.contains("darksky"), "the reflection's true name stays hidden while her history and the gift are explained")
		if chase._caption.text.contains("对不起"):
			heard_apology = true
		if chase._caption.text.contains("我还在生气"):
			heard_response = true
		if chase._caption.text.contains("自己的身体"):
			heard_history = true
		await frames(23)
		chase._next.pressed.emit()
	check(heard_history and heard_apology and heard_response, "the heroine hears her trapped companion's history and responds before choosing the gift")
	check(chase.phase == chase.Phase.FUSION and state.collected_count() == 0 and state.has_offered_colors(), "voluntarily giving spends all three collected colours and starts their fusion")
	await frames(2)
	check(music.current_track == &"reunion", "voluntary giving begins the warmer reunion score before the new character appears")
	check(chase.player.current_animation == "reach" and chase._memory.animation == &"reach", "the colour gift recalls their opening single-palm gesture")
	check(not state.offer_colors() and not state.darksky_revived, "the gift cannot be spent twice or grant life before the transformation")
	check(state.load_from_disk() and state.offered_mask == 7 and state.collected_count() == 0 and not state.darksky_revived, "a save during the gift preserves the spent colours and unfinished revival")
	change_scene_to_file("res://scenes/ui/title_screen.tscn")
	await frames(6)
	current_scene._continue()
	await frames(6)
	chase = current_scene
	check(chase.phase == chase.Phase.FUSION and state.collected_count() == 0, "Continue resumes the saved colour fusion without replaying the chase or refunding the gift")
	chase._next.pressed.emit()
	await frames(10)
	check(chase.phase == chase.Phase.FUSION and not state.darksky_revived, "dialogue input cannot skip the visible colour transformation")
	await frames(255)
	check(chase.phase == chase.Phase.REUNION and state.darksky_revived and state.collected_count() == 0, "the three colours fuse into a real life instead of disappearing with the mirror")
	check(chase._memory.material == null and chase._memory_glass.modulate.a == 1, "the revived girl is opaque and no longer uses the smoky reflection material")
	check(chase._memory.sprite_frames == chase.DARKSKY_FRAMES and chase._memory.sprite_frames != chase.player.sprite.sprite_frames, "revival restores darksky's own character art instead of another heroine clone")
	for animation in chase.DARKSKY_FRAMES.get_animation_names():
		for i in chase.DARKSKY_FRAMES.get_frame_count(animation):
			var pose: AtlasTexture = chase.DARKSKY_FRAMES.get_frame_texture(animation, i)
			check(Rect2(Vector2.ZERO, pose.get_size()).encloses(Rect2(pose.margin.position, pose.region.size)), "darksky's entire hair, hands and shoes stay inside every atlas frame")
	check(chase._cg.texture == chase.REVIVAL_CG and chase._cg.modulate.a == 1, "the revival uses the generated resurrection CG")
	check(chase._topshade.modulate.a == 0 and chase.backdrop._palettes[0].get_shader_parameter("monochrome_amount") == 1.0, "the donated corridor loses colour and the CG faces remain clear of the gameplay header shade")
	check(not state.is_game_complete(), "revival is saved before the girls finish their reunion")
	change_scene_to_file("res://scenes/ui/title_screen.tscn")
	await frames(6)
	current_scene._continue()
	await frames(6)
	chase = current_scene
	check(chase.phase == chase.Phase.REUNION and state.darksky_revived and state.collected_count() == 0, "Continue after revival resumes the reunion without resurrecting or spending again")
	check(_heard.count(&"mirror_shatter") == glass_cues + 1, "loading fusion and reunion saves does not sound like shattering the mirror again")
	for i in chase.REUNION_BEATS.size():
		check(chase._caption.text.contains("darksky") == (i == chase.REUNION_BEATS.size() - 1), "her true name is revealed only in the last reunion line")
		if chase.phase == chase.Phase.EMBRACE:
			chase._next.pressed.emit()
			await frames(10)
			check(chase.phase == chase.Phase.EMBRACE, "an extra dialogue click cannot skip the visible embrace")
			await frames(150)
			check(chase._cg.texture == chase.EMBRACE_CG and chase._memory.animation == &"hug", "a dedicated embrace CG and companion pose play before the girls leave")
		await frames(23)
		chase._next.pressed.emit()
	check(chase.phase == chase.Phase.DEPARTURE and not state.is_game_complete(), "the two girls leave together through a transition before the ending is saved")
	var tracks_before_ending := _music_tracks.size()
	await frames(85)
	check(state.is_game_complete() and current_scene.scene_file_path.ends_with("ending_screen.tscn"), "leaving together completes the resurrection ending")
	check(music.current_track == &"reunion" and _music_tracks.size() == tracks_before_ending and music._credits.visible, "embrace, departure and ending share continuous music with accessible attribution on the final card")
	check(current_scene.backdrop.texture.resource_path.ends_with("ending_together.png"), "the final card displays the generated hand-in-hand departure CG")
	check(state.load_from_disk() and state.ending_reached and state.darksky_revived and state.has_offered_colors() and state.collected_count() == 0 and state.current_level == 4, "the completed resurrection and actually spent colours round-trip through save")
	change_scene_to_file("res://scenes/ui/title_screen.tscn")
	await frames(6)
	current_scene._continue()
	await frames(6)
	check(current_scene.scene_file_path.ends_with("ending_screen.tscn") and state.is_game_complete(), "a completed save resumes at the two-girl ending CG")
	state.begin_game("新旅程")
	check(not state.has_offered_colors() and not state.darksky_revived and state.collected_count() == 0, "a new journey resets the gift, revival and inventory")
	state.current_level = 4
	state.collected_mask = 3
	check(not state.offer_colors() and state.collected_mask == 3 and not state.revive_darksky(), "an incomplete RGB inventory cannot be consumed or revive the girl")
	state.complete_journey()
	check(not state.is_game_complete(), "an unrevived journey cannot bypass the rescue by completing early")
	state.begin_game("新旅程")
	state.current_level = 3
	change_scene_to_file("res://scenes/gameplay/gameplay.tscn")
	await frames(8)
	game = current_scene
	await key_p()
	await frames(80)
	check(state.current_level == 4 and state.collected_count() == 0 and state.is_finale_pending() and not paused, "P at the final exit enters the finale without inventing a fourth colour or leaving a modal pause")
	state.begin_game("新旅程")
	print("MIRROR TESTS: %d checks, %d failures" % [checks, failures])
	await music.prepare_shutdown()
	quit(1 if failures else 0)
