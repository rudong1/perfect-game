extends Node2D
const MIRROR_SELF = preload("res://scripts/mirror_self.gd")
const BACKDROP_SHADER = preload("res://shaders/level_backdrop.gdshader")
const CHURCH_BACKGROUNDS := [
	preload("res://assets/backgrounds/church_grey.png"),
	preload("res://assets/backgrounds/church_red.png"),
	preload("res://assets/backgrounds/church_blue.png"),
	preload("res://assets/backgrounds/church_green.png"),
]
@onready var level_root: Node2D = $LevelRoot
@onready var player: CharacterBody2D = $Player
@onready var builder: Node = $LevelBuilder
@onready var toast: Label = $HUD/Toast
var echo: CharacterBody2D
var _state: Node
var _mirror: Node
var _goal: Area2D
var _busy := false
var _toast_tween: Tween
var _background: ShaderMaterial
var _world_width := 1920.0

func _ready() -> void:
	_state = get_node("/root/GameState")
	_mirror = get_node("/root/MirrorState")
	_background = ShaderMaterial.new()
	_background.shader = BACKDROP_SHADER
	$Backdrop/Base.material = _background
	_state.checkpoint_saved.connect(_on_checkpoint_saved)
	echo = CharacterBody2D.new()
	echo.name = "MirrorSelf"
	echo.set_script(MIRROR_SELF)
	echo.source = player
	add_child(echo)
	player.respawned.connect(_restore_checkpoint)
	load_level()

func load_level() -> void:
	if _state.is_game_complete():
		get_tree().change_scene_to_file("res://scenes/ui/ending_screen.tscn")
		return
	_busy = false
	_mirror.input_enabled = true
	_mirror.reset()
	player.set_physics_process(true)
	var data: Dictionary = _state.get_level()
	_background.set_shader_parameter("top_color", data.bg_top)
	_background.set_shader_parameter("bottom_color", data.bg_bottom)
	_background.set_shader_parameter("accent_color", data.accent)
	_background.set_shader_parameter("light_color", data.get("light_color", data.accent))
	_background.set_shader_parameter("light_dir", data.get("light_dir", -1.0))
	_background.set_shader_parameter("saturation", data.get("saturation", 1.0))
	_background.set_shader_parameter("fog_amount", data.get("fog", 0.0))
	_background.set_shader_parameter("scene_texture", CHURCH_BACKGROUNDS[_state.current_level])
	_background.set_shader_parameter("use_scene_texture", true)
	$HUD/Chapter.text = data.title
	$HUD/Chapter.modulate = data.accent
	$HUD/Objective.text = data.objective
	$HUD/Story.text = data.story_before
	var result: Dictionary = builder.build(_state.current_level, level_root)
	_world_width = result.width
	var spawn: Vector2 = result.spawn
	if _state.has_checkpoint and _state.checkpoint_level == _state.current_level:
		spawn = _state.checkpoint_position
	player.set_respawn_position(spawn)
	player.respawn()
	_goal = result.goal
	_goal.collected.connect(_on_color_found)
	_hide_toast()

func _on_color_found() -> void:
	if _busy:
		return
	_busy = true
	_mirror.input_enabled = false
	player.set_physics_process(false)
	if _goal.is_exit:
		_show_toast("和影子一起走出镜面", _state.get_level().accent)
	else:
		_state.collect_current_color()
		_show_toast("找到" + _state.get_level().color_name, _state.get_level().collect_color)
	await get_tree().create_timer(0.75).timeout
	if not is_inside_tree():
		return
	_state.advance_level()
	load_level()

func _input(event: InputEvent) -> void:
	# Developer shortcut intentionally absent from all player-facing UI.
	if OS.is_debug_build() and not _busy and event.is_action_pressed("developer_skip") and not event.is_echo():
		_busy = true
		_skip_level.call_deferred()
		get_viewport().set_input_as_handled()

func _skip_level() -> void:
	_state.advance_level(true)
	load_level()

func _unhandled_input(event: InputEvent) -> void:
	if not _busy and event.is_action_pressed("restart_room") and not event.is_echo():
		load_level.call_deferred()
		get_viewport().set_input_as_handled()

func _hide_toast() -> void:
	if _toast_tween != null:
		_toast_tween.kill()
	toast.visible = false

func _show_toast(text: String, tint: Color = Color.WHITE) -> void:
	_hide_toast()
	toast.text = text
	toast.modulate = tint
	toast.visible = true

func _on_checkpoint_saved(_position: Vector2) -> void:
	if _busy:
		return
	_show_toast("已存档", Color("#b4cadf"))
	_toast_tween = create_tween()
	_toast_tween.tween_interval(0.8)
	_toast_tween.tween_callback(func() -> void: toast.visible = false)

func _restore_checkpoint() -> void:
	if _state.has_checkpoint and _state.checkpoint_level == _state.current_level:
		level_root.get_node("RoomPuzzle").restore_completed(_state.checkpoint_stage)

func _process(_delta: float) -> void:
	$Camera.position.x = clampf(player.position.x, 960, _world_width - 960)
	var puzzle := level_root.get_node_or_null("RoomPuzzle")
	if puzzle != null and not _busy:
		$HUD/Objective.text = puzzle.current_hint()
