extends CanvasLayer
## Esc pause overlay: resume the room, or persist the run and return to the title.
## Mirrors CollectionCG's pause ownership, so two modals never release the same pause.

const START_SCENE := "res://scenes/ui/title_screen.tscn"
const HEADING_COLOR := Color("#E8E3D3")
const BODY_COLOR := Color(0.78, 0.84, 0.90)
const MUTED_COLOR := Color(0.62, 0.69, 0.78)
const LEAD := Color(0.76, 0.76, 0.76, 0.5)

var _surface: Control
var _owns_pause := false

func _ready() -> void:
	layer = 140
	process_mode = Node.PROCESS_MODE_ALWAYS
	_surface = Control.new()
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_surface)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.012, 0.016, 0.024, 0.86)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_surface.add_child(shade)
	var panel := PanelContainer.new()
	panel.position = Vector2(660, 330)
	panel.size = Vector2(600, 420)
	_surface.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_bottom", 36)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 16)
	margin.add_child(rows)
	var heading := _label("暂停", 34, HEADING_COLOR)
	rows.add_child(heading)
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 2)
	rule.color = LEAD
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(rule)
	rows.add_child(_label("镜中的时间暂时停驻。", 19, BODY_COLOR))
	var resume := _button("继续游戏")
	resume.pressed.connect(_close)
	rows.add_child(resume)
	var save_quit := _button("保存并返回标题")
	save_quit.pressed.connect(_save_and_quit)
	rows.add_child(save_quit)
	var hint := _label("Esc 继续 · 退出后可从标题继续旅程", 16, MUTED_COLOR)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rows.add_child(hint)
	_surface.hide()

func _label(text: String, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = tint
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 58)
	button.add_theme_font_size_override("font_size", 22)
	button.focus_mode = Control.FOCUS_NONE
	return button

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or event.is_echo():
		return
	# A collection CG (or any other modal) owns a different pause; never steal it.
	if get_tree().paused and not _surface.visible:
		return
	if _surface.visible:
		_close()
	else:
		_open()
	get_viewport().set_input_as_handled()

func _open() -> void:
	if get_tree().paused:
		return
	_surface.show()
	_owns_pause = true
	get_tree().paused = true

func _close() -> void:
	_surface.hide()
	_release_pause()

func _save_and_quit() -> void:
	var state := get_node_or_null("/root/GameState")
	if state != null:
		state.call("persist_run")
	_close()
	get_tree().change_scene_to_file.call_deferred(START_SCENE)

func _release_pause() -> void:
	if _owns_pause:
		get_tree().paused = false
		_owns_pause = false

func _exit_tree() -> void:
	_release_pause()
