extends Control
## Title and character-name entry.

@onready var backdrop: ColorRect = $Backdrop
@onready var prism_art: Control = $PrismArt
@onready var name_edit: LineEdit = $NameEdit
@onready var begin_button: Button = $Begin
@onready var continue_button: Button = $Continue


func _ready() -> void:
	var background := ShaderMaterial.new()
	background.shader = preload("res://shaders/level_backdrop.gdshader")
	background.set_shader_parameter("top_color", Color("#04060a"))
	background.set_shader_parameter("bottom_color", Color("#11151d"))
	background.set_shader_parameter("accent_color", Color("#dfe9f7"))
	background.set_shader_parameter("glow_strength", 0.7)
	backdrop.material = background

	var preview_colors: Array[Color] = [Color("#ff5c71"), Color("#69e39d"), Color("#51c8ff")]
	prism_art.call("set_state", 5, preview_colors, true)
	begin_button.pressed.connect(_begin)
	continue_button.pressed.connect(_continue)
	var state := get_node_or_null("/root/GameState")
	if state != null and bool(state.call("has_save")):
		continue_button.visible = true
	name_edit.text_submitted.connect(_on_name_submitted)
	name_edit.grab_focus()


func _on_name_submitted(_text: String) -> void:
	_begin()


func _begin() -> void:
	var state := get_node_or_null("/root/GameState")
	if state != null:
		state.call("begin_game", name_edit.text)
	get_tree().change_scene_to_file("res://scenes/gameplay/gameplay.tscn")


func _continue() -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null or not bool(state.call("load_from_disk")):
		return
	get_tree().change_scene_to_file("res://scenes/gameplay/gameplay.tscn")
