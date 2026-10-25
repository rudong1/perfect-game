extends SceneTree
## Start-screen and mid-run exit coverage: quit entry, pause overlay, save-and-quit, resume.

var _checks := 0
var _failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("UI FLOW FAILED: " + message)


func frames(count: int) -> void:
	for i in count:
		await process_frame


func press_escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)


func run() -> void:
	await process_frame
	var state: Node = root.get_node("GameState")
	var save_path: String = state.SAVE_PATH
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	var title: Control = load("res://scenes/ui/title_screen.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	check(title.get_node_or_null("MenuPanel/Quit") != null, "the start screen exposes a quit entry")
	check(not title.continue_button.visible, "continue stays hidden without a save")
	check(title.get_node("Title").text == state.GAME_TITLE, "the start screen keeps the poetic title")
	check(not title.name_edit.visible, "the start screen hides the name field until stepping in")

	title.begin_button.pressed.emit()
	await frames(2)
	check(title.name_edit.visible and not title.begin_button.visible, "踏入镜中 reveals the naming step")
	title.name_edit.text = "存档测试"
	title.confirm_button.pressed.emit()
	await frames(8)
	check(current_scene.scene_file_path.ends_with("opening.tscn"), "a new journey starts from the prologue")

	change_scene_to_file("res://scenes/gameplay/gameplay.tscn")
	await frames(10)
	var game: Node = current_scene
	var pause: Node = game.get_node_or_null("PauseMenu")
	check(pause != null, "gameplay includes the pause menu")

	press_escape()
	await frames(3)
	check(paused and pause._surface.visible, "Esc pauses the room and shows the pause overlay")
	press_escape()
	await frames(3)
	check(not paused and not pause._surface.visible, "Esc again resumes the room")

	press_escape()
	await frames(3)
	pause._save_and_quit()
	await frames(8)
	check(FileAccess.file_exists(save_path), "saving from the pause menu writes the run")
	var config := ConfigFile.new()
	var loaded := config.load(save_path) == OK
	check(loaded and int(config.get_value("game", "current_level", -1)) == 0, "the saved run records the current world")
	check(not paused, "leaving the pause menu releases the scene-tree pause")
	check(current_scene.scene_file_path.ends_with("title_screen.tscn"), "save-and-quit returns to the start screen")

	await frames(2)
	check(current_scene.continue_button.visible, "the start screen now offers to continue")
	current_scene.continue_button.pressed.emit()
	await frames(10)
	check(current_scene.scene_file_path.ends_with("gameplay.tscn"), "continue loads the saved room")
	check(not paused, "resuming from the start screen is not paused")

	state._on_close_requested()
	check(FileAccess.file_exists(save_path), "window-close autosave keeps the run file")

	print("UI FLOW TESTS: %d checks, %d failures" % [_checks, _failures])
	if is_instance_valid(current_scene):
		current_scene.free()
	# Release Ogg decoders before quitting, like the music test does.
	var music: Node = root.get_node_or_null("MusicDirector")
	if music != null and music.has_method("prepare_shutdown"):
		await music.prepare_shutdown()
	await process_frame
	quit(1 if _failures > 0 else 0)
