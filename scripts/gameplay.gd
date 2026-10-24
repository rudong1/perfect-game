extends Node2D
## Runs the five single-screen mirror rooms and the prism intermissions.

const BACKDROP_SHADER = preload("res://shaders/level_backdrop.gdshader")

@onready var base: ColorRect = $Backdrop/Base
@onready var level_root: Node2D = $LevelRoot
@onready var player: CharacterBody2D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var chapter: Label = $HUD/Chapter
@onready var objective: Label = $HUD/Objective
@onready var story: Label = $HUD/Story
@onready var colors_label: Label = $HUD/Colors
@onready var toast: Label = $HUD/Toast
@onready var overlay: Control = $PrismLayer/PrismOverlay
@onready var builder: Node = $LevelBuilder

var _state: Node
var _mirror: Node
var _background: ShaderMaterial
var _goal: Area2D
var _busy := false
var _toast_tween: Tween


func _ready() -> void:
	_state = get_node_or_null("/root/GameState")
	_mirror = get_node_or_null("/root/MirrorState")
	if _state == null:
		push_error("GameState autoload not found")
		return

	_background = ShaderMaterial.new()
	_background.shader = BACKDROP_SHADER
	base.material = _background

	overlay.continue_pressed.connect(_on_prism_continue)
	_state.connect("checkpoint_saved", _on_checkpoint_saved)
	toast.visible = false
	load_level()


func load_level() -> void:
	if bool(_state.call("is_game_complete")):
		get_tree().change_scene_to_file("res://scenes/ui/ending_screen.tscn")
		return

	_busy = false
	if _mirror != null:
		_mirror.set("input_enabled", true)
		_mirror.call("reset")

	var level_index := int(_state.get("current_level"))
	var data: Dictionary = _state.call("get_level", level_index)
	_apply_palette(data)
	_update_hud(data)

	var result: Dictionary = builder.call("build", level_index, level_root)
	var spawn: Vector2 = result["spawn"]
	if bool(_state.get("has_checkpoint")) and int(_state.get("checkpoint_level")) == level_index:
		spawn = _state.get("checkpoint_position")
	player.set_respawn_position(spawn)
	player.call("respawn")
	player.visible = true
	player.set_physics_process(true)
	_goal = result["goal"]
	if _goal != null:
		_goal.connect("reached", _on_goal_reached)
	overlay.hide_overlay()


func _apply_palette(data: Dictionary) -> void:
	_background.set_shader_parameter("top_color", data.bg_top)
	_background.set_shader_parameter("bottom_color", data.bg_bottom)
	_background.set_shader_parameter("accent_color", data.accent)
	_background.set_shader_parameter("glow_strength", 1.0)


func _update_hud(data: Dictionary) -> void:
	chapter.text = str(data.title)
	chapter.modulate = data.accent
	objective.text = str(data.objective)
	story.text = str(_state.call("format_story", data.story_before))
	var count := int(_state.call("restored_channel_count"))
	colors_label.text = "RGB  %d / 3" % count
	colors_label.modulate = data.accent


func _on_goal_reached() -> void:
	if _busy:
		return
	_busy = true
	if _mirror != null:
		_mirror.set("input_enabled", false)
		_mirror.call("set_mirrored", false)
	player.set_physics_process(false)
	_state.call("level_completed")
	await get_tree().create_timer(0.2).timeout
	overlay.show_result()


func _on_checkpoint_saved(_position: Vector2) -> void:
	toast.text = "存档点已点亮"
	toast.visible = true
	toast.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.1)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.45)
	_toast_tween.tween_callback(func() -> void: toast.visible = false)


func _on_prism_continue() -> void:
	if bool(_state.call("is_game_complete")):
		overlay.hide_overlay()
		get_tree().change_scene_to_file("res://scenes/ui/ending_screen.tscn")
		return
	overlay.hide_overlay()
	load_level()
