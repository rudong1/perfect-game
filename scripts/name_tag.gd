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
	tag.add_theme_color_override("font_color", Color("#dce8ff"))
	tag.add_theme_color_override("font_outline_color", Color("#070a10"))
	tag.add_theme_constant_override("outline_size", 4)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.size = Vector2(260, 24)


func _process(_delta: float) -> void:
	if _player == null or tag == null:
		return
	var screen := _player.get_global_transform_with_canvas().origin
	var viewport_height := get_viewport().get_visible_rect().size.y
	if _mirror != null and bool(_mirror.get("mirrored")):
		screen.y = viewport_height - screen.y + 236.0
	else:
		screen.y -= 226.0
	tag.position = screen - Vector2(tag.size.x * 0.5, tag.size.y * 0.5)
