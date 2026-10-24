extends SceneTree
## Run with --headless --fixed-fps 60 --script res://tests/mirror_mechanics.gd
## Set XDG_DATA_HOME to a disposable directory: this suite exercises real saves.
var failures := 0
var checks := 0
var game: Node2D
var state: Node
var mirror: Node

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

func drive(puzzle: Node, stage: int, flips: Array, jumping: bool) -> void:
	Input.action_press("move_right")
	Input.action_press("sprint")
	var trigger := 0
	var jumped := false
	for tick in 1100:
		await physics_frame
		var x: float = game.player.position.x
		if jumping and not jumped and x >= 650:
			Input.action_press("jump")
			jumped = true
		if trigger < flips.size() and x >= flips[trigger][0]:
			mirror.set_mirrored(flips[trigger][1])
			trigger += 1
			Input.action_release("jump")
		if puzzle.solved_steps > stage:
			break
	release_controls()
	await frames(8)

func run() -> void:
	await process_frame
	state = root.get_node("GameState")
	mirror = root.get_node("MirrorState")
	state.begin_game("测试")
	game = load("res://scenes/gameplay/gameplay.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames(8)
	var player: CharacterBody2D = game.player
	var shadow: CharacterBody2D = game.echo
	check(shadow.global_position.distance_to(mirror.reflect_point(player.global_position)) < 1, "shadow starts across shared mirror axis")
	check(shadow.hint.text.contains("影子") and shadow.sprite.material != null, "shadow has a distinct tint and readable identity")
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
	await key_p()
	check(state.current_level == 1, "P advances one room")
	check(state.collected_count() == 0, "developer skip does not invent a collected color")
	await key_p(true)
	check(state.current_level == 1, "held P does not repeatedly skip")
	for label in text_nodes(game):
		check(not label.text.contains("P") and not label.text.contains("落点") and not label.text.contains("穿镜") and not label.text.contains("光路"), "player text has no hidden shortcut, coordinates or removed mechanics")

	# Migrate an old save without reusing its incompatible checkpoint geometry.
	var legacy := ConfigFile.new()
	legacy.set_value("game", "current_level", 2)
	legacy.set_value("game", "completed_levels", 2)
	legacy.set_value("game", "has_checkpoint", true)
	legacy.set_value("game", "checkpoint_position", Vector2(1540, 900))
	legacy.save(state.SAVE_PATH)
	check(state.load_from_disk() and state.collected_count() == 2 and not state.has_checkpoint, "old saves retain progress and discard stale checkpoints")

	var frames_resource: SpriteFrames = player.sprite.sprite_frames
	check(frames_resource.get_frame_count("run") == 8 and frames_resource.get_frame_count("sprint") == 8, "eight actual run frames replace four-frame motion")
	check(frames_resource.get_frame_count("land") >= 3 and frames_resource.has_animation("apex") and frames_resource.has_animation("stop"), "landing, apex and braking transitions exist")
	for animation in frames_resource.get_animation_names():
		for i in frames_resource.get_frame_count(animation):
			check(frames_resource.get_frame_texture(animation, i).get_size() == Vector2(320, 380), "all poses share a stable logical canvas")
	await room(0)
	var bridge: Node2D = get_nodes_in_group("shadow_bridges")[0]
	check(bridge._active.count(true) == 0, "bridge starts physically absent")
	bridge.plate._set_pressed(true)
	bridge._physics_process(0.01)
	await frames(1)
	check(bridge.activated_once, "shadow pressure activates bridge")
	bridge.plate._set_pressed(false)
	await frames(120)
	check(bridge._active.count(true) == 0, "released bridge actually loses collision")
	state.save_checkpoint(0, Vector2(1760, 900), 2)
	player.respawn_position = Vector2(1760, 900)
	player.respawn()
	await frames(3)
	check(game.level_root.get_node("RoomPuzzle").solved_steps == 2, "death restores completed checkpoint sections")
	state.begin_game("同行")
	await room(0)
	var unique_colors: Array = []
	for index in 4:
		check(state.current_level == index, "room %d is reached in sequence" % (index + 1))
		check(get_nodes_in_group("mirror_slabs").is_empty() and not game.level_root.has_node("PrismCircuit"), "campaign uses only flips and shadow")
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
		for step_index in puzzle.steps.size():
			var step: Dictionary = puzzle.steps[step_index]
			match step.kind:
				"plate":
					await flip_to(step.mirrored)
					await walk_to(step.plates[0].position.x + 100)
					await frames(50)
				"reach":
					if index == 0:
						await drive(puzzle, step_index, [[1200.0, false]], false)
					elif index == 1 and step_index == 0:
						await drive(puzzle, step_index, [[700.0, true], [930.0, false]], true)
					elif index == 1:
						await drive(puzzle, step_index, [[1560.0, true], [1890.0, false]], false)
					elif index == 3:
						await drive(puzzle, step_index, [[700.0, true], [930.0, false]], true)
					else:
						mirror.set_mirrored(false)
						await drive(puzzle, step_index, [], false)
				"release":
					await walk_to(step.barrier.position.x + 200)
					await frames(55)
					check(step.barrier.stalled, "ceiling beam physically stops shadow")
					mirror.set_mirrored(true)
					await drive(puzzle, step_index, [], false)
				"bridge":
					mirror.set_mirrored(false)
					await frames(135)
					await drive(puzzle, step_index, [], false)
			check(puzzle.solved_steps > step_index and step.door.is_open, "actual terrain route solves world %d step %d" % [index + 1, step_index + 1])
		check(game._goal.enabled, "cooperation unlocks the room's color")
		await flip_to(false)
		await walk_to(3660)
		check(state.collected_count() == mini(index + 1, 3) and (index == 3 or state.has_color(index)), "three colors fill progress; green-world exit adds no extra color")
		check(not state.collect_current_color(), "duplicate collection cannot inflate prism progress")
		await frames(60)
		check(state.current_level == index + 1, "color pickup advances without prism intermission")
	check(unique_colors.size() == 3 and unique_colors[0].r > unique_colors[0].b and unique_colors[1].b > unique_colors[1].r and unique_colors[2].g > unique_colors[2].r, "collectibles are exactly red, blue, green in order")
	check(state.is_game_complete() and current_scene.scene_file_path.ends_with("ending_screen.tscn"), "green world reaches ending after three color transitions")
	check(state.load_from_disk() and state.collected_count() == 3 and state.current_level == 4, "color collection and final progress round-trip through save")
	print("MIRROR TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
