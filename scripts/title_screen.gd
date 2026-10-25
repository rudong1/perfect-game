extends Control
## Gothic start screen: the naming step appears only after choosing to step through,
## then a new journey, continuing a save, or quitting.

const MENU_HINT := "按 Enter 踏入镜中"
const NAMING_HINT := "留空则名为「无名」 · Enter 确认 · Esc 返回"

@onready var backdrop: TextureRect = $Backdrop
@onready var heading: Label = $MenuPanel/Heading
@onready var name_label: Label = $MenuPanel/NameLabel
@onready var name_edit: LineEdit = $MenuPanel/NameEdit
@onready var begin_button: Button = $MenuPanel/Begin
@onready var confirm_button: Button = $MenuPanel/Confirm
@onready var continue_button: Button = $MenuPanel/Continue
@onready var quit_button: Button = $MenuPanel/Quit
@onready var hint: Label = $MenuPanel/Hint

var _naming := false


func _ready() -> void:
	var palette := ShaderMaterial.new()
	palette.shader = preload("res://shaders/restricted_art.gdshader")
	backdrop.material = palette
	begin_button.pressed.connect(_open_naming)
	confirm_button.pressed.connect(_commit_name)
	continue_button.pressed.connect(_continue)
	quit_button.pressed.connect(_quit)
	name_edit.text_submitted.connect(_on_name_submitted)
	var state := get_node_or_null("/root/GameState")
	if state != null and bool(state.call("has_save")):
		continue_button.visible = true
	_set_naming(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and not _naming:
		_open_naming()
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed("ui_cancel") or event.is_echo():
		return
	if _naming:
		_set_naming(false)
	else:
		_quit()
	get_viewport().set_input_as_handled()


func _open_naming() -> void:
	_set_naming(true)
	name_edit.grab_focus()


func _set_naming(value: bool) -> void:
	_naming = value
	heading.text = "镜中姓名" if value else "开始旅程"
	name_label.visible = value
	name_edit.visible = value
	confirm_button.visible = value
	begin_button.visible = not value
	var state := get_node_or_null("/root/GameState")
	continue_button.visible = not value and state != null and bool(state.call("has_save"))
	quit_button.visible = not value
	hint.text = NAMING_HINT if value else MENU_HINT


func _on_name_submitted(_text: String) -> void:
	if _naming:
		_commit_name()


func _commit_name() -> void:
	if not _naming:
		return
	var state := get_node_or_null("/root/GameState")
	if state != null:
		state.call("begin_game", name_edit.text)
	# A new journey opens with the prologue, not the first room.
	get_tree().change_scene_to_file("res://scenes/opening/opening.tscn")


func _continue() -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null or not bool(state.call("load_from_disk")):
		return
	if state.is_finale_pending():
		get_tree().change_scene_to_file("res://scenes/finale/finale.tscn")
		return
	if state.is_game_complete():
		get_tree().change_scene_to_file("res://scenes/ui/ending_screen.tscn")
		return
	get_tree().change_scene_to_file("res://scenes/gameplay/gameplay.tscn")


func _quit() -> void:
	get_tree().quit()
