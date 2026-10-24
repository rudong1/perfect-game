extends Control
## Full-screen prism/progress screen shown after every room.

signal continue_pressed

@onready var title: Label = $Title
@onready var story: Label = $Story
@onready var progress: Label = $Progress
@onready var hint: Label = $Hint
@onready var art: Control = $Art
@onready var button: Button = $Continue

var _state: Node


func _ready() -> void:
	visible = false
	_state = get_node_or_null("/root/GameState")
	button.pressed.connect(_on_continue_pressed)
	set_process_unhandled_input(false)


func show_result() -> void:
	if _state == null:
		return
	var completed := int(_state.get("completed_levels"))
	var is_final := bool(_state.call("is_game_complete"))
	var restored := int(_state.call("restored_channel_count"))
	var level_data: Dictionary = _state.call("get_level", maxi(completed - 1, 0))
	if is_final:
		title.text = "全部色彩"
	elif restored == 0:
		title.text = "第一束白光"
	elif restored == 1:
		title.text = "棱镜恢复：R"
	elif restored == 2:
		title.text = "棱镜恢复：R + B"
	else:
		title.text = "三原色归位"
	story.text = str(_state.call("format_story", level_data.story_after))
	progress.text = "RGB  %d / 3" % restored
	if is_final:
		hint.text = "R、G、B 已经回到棱镜里。"
	elif restored == 0:
		hint.text = "白光穿过棱镜。下一重镜面会带回 R 分量。"
	elif restored == 1:
		hint.text = "R 已恢复。下一重镜面会带回 B。"
	elif restored == 2:
		hint.text = "R、B 已恢复。还差 G。"
	else:
		hint.text = "R、G、B 全部归位。前面就是最后一重颜色。"
	button.text = "走向光" if is_final else "继续"
	art.call("set_state", completed, _state.call("colored_rays"), is_final)
	visible = true
	modulate.a = 0.0
	set_process_unhandled_input(true)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.25)
	button.grab_focus()


func hide_overlay() -> void:
	set_process_unhandled_input(false)
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_on_continue_pressed()


func _on_continue_pressed() -> void:
	set_process_unhandled_input(false)
	continue_pressed.emit()
