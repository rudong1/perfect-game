extends CanvasLayer
## Text is drawn after the screen mirror, at the projected world anchor.
var target: Node2D
var world_offset := Vector2.ZERO
var text := ""
var tint := Color.WHITE
var label: Label
var _mirror: Node

func _ready() -> void:
	layer = 108
	add_to_group("readable_hints")
	_mirror = get_node("/root/MirrorState")
	if target == null:
		target = get_parent() as Node2D
	label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_outline_color", Color("#090909"))
	label.add_theme_constant_override("outline_size", 6)
	add_child(label)

func screen_anchor() -> Vector2:
	var transform := get_viewport().get_canvas_transform()
	var point := transform * (target.global_position + world_offset)
	if _mirror.mirrored:
		var axis := transform * Vector2(0, _mirror.axis_y)
		point.y = 2.0 * axis.y - point.y
	return point

func _process(_delta: float) -> void:
	if not is_instance_valid(target):
		return
	label.text = text
	label.modulate = tint
	label.size = Vector2(480, 32)
	label.position = screen_anchor() - label.size * 0.5
	label.scale = Vector2.ONE
	label.visible = target.is_visible_in_tree()
