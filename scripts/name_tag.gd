extends CanvasLayer
## Small, unflipped name tag that follows the heroine.
##
## It lives above ScreenMirror (layer 105) so the name stays readable while
## the world is mirrored. When the mirror is active its screen position is
## reflected so it still sits next to the character.

@onready var tag: Label = $NameTag

var _state: Node
var _mirror: Node
var _player: Node2D


func _ready() -> void:
	_player = get_parent() as Node2D
	_state = get_node_or_null("/root/GameState")
	_mirror = get_node_or_null("/root/MirrorState")
	var value := "无名"
	if _state != null:
		value = str(_state.get("player_name"))
	tag.text = value
	tag.visible = not value.is_empty()
	tag.add_theme_font_size_override("font_size", 16)
	tag.add_theme_color_override("font_color", Color("#e0e0e0"))
	tag.add_theme_color_override("font_outline_color", Color("#090909"))
	tag.add_theme_constant_override("outline_size", 4)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.size = Vector2(260, 24)


func _process(_delta: float) -> void:
	if _player == null or tag == null:
		return
	var gravity_sign := -1.0 if _mirror.mirrored else 1.0
	var world_head := _player.global_position + Vector2(0, -226.0 * gravity_sign)
	var transform := get_viewport().get_canvas_transform()
	var screen := transform * world_head
	if _mirror.mirrored:
		var axis_screen := transform * Vector2(0, _mirror.axis_y)
		screen.y = 2.0 * axis_screen.y - screen.y
	tag.position = screen - Vector2(tag.size.x * 0.5, tag.size.y * 0.5)
