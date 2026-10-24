extends SceneTree
## Run with Godot .NET --headless --fixed-fps 60 --path . --script tests/mirror_mechanics.gd
## Use a disposable XDG_DATA_HOME so save tests cannot overwrite a real run.
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

func room(index: int) -> void:
	Input.action_release("move_right")
	Input.action_release("move_left")
	Input.action_release("sprint")
	Input.action_release("jump")
	state.current_level = index
	state.has_checkpoint = false
	game.load_level()
	await frames(8)

func push_to(slab: StaticBody2D, target_x: float) -> void:
	Input.action_press("move_right")
	for i in 360:
		await physics_frame
		if slab.global_position.x >= target_x:
			break
	Input.action_release("move_right")
	await frames(15)

func run() -> void:
	await process_frame
	state = root.get_node("GameState")
	mirror = root.get_node("MirrorState")
	state.begin_game("机制回归")
	game = load("res://scenes/gameplay/gameplay.tscn").instantiate()
	root.add_child(game)
	await frames(8)
	var player: CharacterBody2D = game.player
	var echo: CharacterBody2D = game.echo
	check(echo.global_position.distance_to(mirror.reflect_point(player.global_position)) < 1, "echo starts at shared axis reflection")
	check(player.collision_layer == 2 and echo.collision_layer == 4, "actors have separate collision layers")
	mirror.axis_y = 590.0
	await frames(2)
	var renderer: CanvasLayer = player.get_node("ScreenMirror")
	renderer._process(0)
	var projected: Vector2 = root.get_canvas_transform() * Vector2(0, mirror.axis_y)
	check(is_equal_approx(renderer._mirror_material.get_shader_parameter("axis_y"), projected.y / root.get_visible_rect().size.y), "shader projects the physics axis")
	mirror.axis_y = 540
	player.respawn()
	await frames(4)
	mirror.set_mirrored(true)
	await frames(130)
	check(player.up_direction == Vector2.DOWN and player.is_on_floor(), "inverted gravity treats ceiling as floor")
	check(absf(player.global_position.y - 180) < 2, "player reaches actual ceiling")
	check(echo.is_on_floor() and absf(echo.global_position.y - 900) < 2, "echo falls in opposite direction")
	Input.action_press("jump")
	await frames(4)
	check(player.velocity.y > 0, "jump moves away from ceiling")
	check(absf(echo.velocity.y) < 1, "echo does not share jump")
	Input.action_release("jump")
	await frames(60)
	player.global_position = Vector2(400, 930)
	mirror.set_mirrored(false)
	await frames(4)
	check(MirrorSafety.is_clear(player, player.global_position), "flip resolves an embedded capsule")
	await room(0)
	mirror.set_mirrored(true)
	await frames(130)
	Input.action_press("sprint")
	Input.action_press("move_right")
	await frames(120)
	Input.action_release("sprint")
	Input.action_release("move_right")
	var twin_puzzle: Node = game.level_root.get_node("RoomPuzzle")
	check(twin_puzzle.solved, "real movement + echo inertia solve simultaneous plates")
	check(twin_puzzle.door.is_open, "twin door latches after both pressures")
	await room(0)
	var lower: Area2D = game.level_root.get_node("LowerPlate")
	player.global_position = Vector2(590, 900)
	await frames(8)
	check(lower.is_activated, "player contact presses plate")
	player.global_position.x = 200
	await frames(8)
	check(not lower.is_activated, "plate releases rather than latching independently")
	check(not game._goal.unlocked, "one plate cannot unlock exit")

	await room(1)
	var slab: StaticBody2D = game.level_root.get_node("MirrorSlab")
	player.global_position = Vector2(740, 900)
	await frames(2)
	await push_to(slab, 1050)
	check(slab.global_position.x >= 1040 and slab.global_position.x <= 1120, "A/D pushes slab into solution interval")
	check(absf(slab.push_velocity) < 0.1, "slab friction stops released mirror")
	var entry := player.global_position
	var expected: Vector2 = slab.exit_for(entry)
	check(slab.try_transport(player), "clear reflection exit permits transit")
	check(player.global_position.distance_to(expected) < 0.01, "transit uses exact reflected X")
	await frames(12)
	check(game._goal.unlocked, "pushed mirror and actual transit unlock corridor")
	# Obstruct the reflected destination with a real body, not a mocked result.
	player.global_position = Vector2(slab.global_position.x + 100, 900)
	var blocked_point: Vector2 = slab.exit_for(player.global_position)
	var block := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(70, 170)
	collision.shape = shape
	block.add_child(collision)
	block.position = blocked_point - Vector2(0, 80)
	game.level_root.add_child(block)
	await frames(3)
	entry = player.global_position
	check(not slab.try_transport(player), "blocked portal refuses to embed player")
	check(player.global_position.distance_to(entry) < 0.01, "failed transit leaves actor in place")
	block.queue_free()
	await frames(2)

	await room(2)
	var circuit: Node2D = game.level_root.get_node("PrismCircuit")
	slab = game.level_root.get_node("MirrorSlab")
	check(state.restored_channel_count() == 0 and not state.has_rainbow(), "progression alone cannot power rays")
	player.global_position = Vector2(520, 900)
	mirror.set_mirrored(true)
	await frames(130)
	check(circuit.upward == [true, false, false], "M turns only nearest optical mirror")
	check(circuit.channel_mask == 1, "red beam reflects into red receiver")
	player.global_position.x = 740
	await push_to(slab, 1040)
	check(slab.global_position.x > 960 and slab.global_position.x < 1100, "slab can be pushed from ceiling")
	player.global_position.x = 960
	mirror.set_mirrored(false)
	await frames(130)
	check(circuit.channel_mask == 3, "second flip produces visible two-color near success")
	player.global_position.x = slab.global_position.x - 80
	check(slab.try_transport(player), "portal crosses the slab during optical sequence")
	player.global_position.x = 1400
	mirror.set_mirrored(true)
	await frames(12)
	check(circuit.channel_mask == 7 and state.has_rainbow(), "M push M move M solves geometric RGB circuit")
	check(state.colored_rays().size() == 3 and state.restored_channel_count() == 3, "live channels feed existing prism APIs")
	check(game._goal.unlocked, "rainbow powers exit")
	slab.global_position.x = 1160
	await frames(12)
	check(circuit.channel_mask == 3 and not state.has_rainbow(), "slab on blue path actually blocks the light")
	check(not game._goal.unlocked, "breaking light closes optical exit")
	player.respawn()
	await frames(12)
	check(circuit.upward == [false, false, false] and not slab.used and not game._goal.unlocked, "death resets all puzzle state")
	await room(3)
	var combined: Node = game.level_root.get_node("RoomPuzzle")
	circuit = game.level_root.get_node("PrismCircuit")
	slab = game.level_root.get_node("MirrorSlab")
	mirror.set_mirrored(true)
	await frames(130)
	Input.action_press("sprint")
	Input.action_press("move_right")
	await frames(75)
	Input.action_release("move_right")
	Input.action_release("sprint")
	check(combined.twins_latched, "fourth room remembers actual simultaneous twin contact")
	check(not game._goal.unlocked, "twin memory alone cannot bypass missing light")
	# Aim all three mirrors via the same nearest-mirror flip used by M.
	for i in 3:
		player.global_position = Vector2(circuit.mirrors[i].x, 500)
		if not circuit.upward[i]:
			mirror.set_mirrored(not mirror.mirrored)
		await frames(2)
	slab.global_position.x = 1040
	player.global_position = Vector2(1500, 500)
	await frames(12)
	check(game._goal.unlocked, "fourth room requires twins and three live colors")
	state.completed_levels = 4
	await room(4)
	circuit = game.level_root.get_node("PrismCircuit")
	slab = game.level_root.get_node("MirrorSlab")
	for i in 3:
		player.global_position = Vector2(circuit.mirrors[i].x, 500)
		mirror.set_mirrored(not mirror.mirrored)
		await frames(2)
	slab.global_position.x = 1040
	player.global_position = Vector2(1500, 500)
	await frames(12)
	check(state.has_rainbow() and not game._goal.unlocked, "fifth room also requires actual mirror transit")
	player.global_position = Vector2(960, 500)
	check(slab.try_transport(player), "final room transit is feasible")
	await frames(12)
	check(game._goal.unlocked, "final exit opens with transit and light together")
	# End on the real goal and let the normal progression/save/intermission run.
	player.global_position = Vector2(1800, 850)
	await frames(30)
	check(state.is_game_complete() and game.overlay.visible, "goal advances into final prism intermission")
	check(state.has_save(), "completion is written to save")
	check(state.load_from_disk() and state.current_level == 5 and state.completed_levels == 5, "final save round-trips full journey progress")
	current_scene = game
	game._on_prism_continue()
	await frames(5)
	check(current_scene.scene_file_path == "res://scenes/ui/ending_screen.tscn", "continue reaches ending scene")
	print("MIRROR TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
