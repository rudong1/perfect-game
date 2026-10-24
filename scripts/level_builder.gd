extends Node
## Four compact worlds using only gravity flips and the delayed shadow.
const PLATE = preload("res://scripts/mirror_plate.gd")
const DOOR = preload("res://scripts/puzzle_door.gd")
const PUZZLE = preload("res://scripts/room_puzzle.gd")
const FRAGMENT = preload("res://scripts/color_fragment.gd")
const HINT = preload("res://scripts/readable_hint.gd")
const CHECKPOINT = preload("res://scripts/checkpoint.gd")
var _palette: Dictionary

func build(index: int, parent: Node2D) -> Dictionary:
	_palette = get_node("/root/GameState").get_level(index)
	for child in parent.get_children():
		child.free()
	_platform(parent, Vector2(0, 900), Vector2(1920, 180))
	_platform(parent, Vector2.ZERO, Vector2(1920, 180))
	_platform(parent, Vector2(-40, 180), Vector2(40, 720))
	_platform(parent, Vector2(1920, 180), Vector2(40, 720))
	_decor(parent)
	_checkpoint(parent)
	var steps: Array = []
	match index:
		0:
			steps.append(_step(parent, [[600, false, true]], 1050, true))
		1:
			steps.append(_step(parent, [[620, true, false], [770, false, true]], 1120, true))
		2:
			steps.append(_step(parent, [[540, true, true]], 840, false))
			steps.append(_step(parent, [[1130, false, true]], 1470, true))
		3:
			steps.append(_step(parent, [[490, true, false], [640, false, true]], 870, true))
			steps.append(_step(parent, [[1070, false, false], [1220, true, true]], 1480, false))
		_:
			steps.append(_step(parent, [[490, true, false], [640, false, true]], 870, true))
			steps.append(_step(parent, [[1070, false, false], [1220, true, true]], 1480, false))
	var goal := _fragment(parent, index == 3)
	var puzzle := Node.new()
	puzzle.name = "RoomPuzzle"
	puzzle.set_script(PUZZLE)
	puzzle.steps = steps
	puzzle.goal = goal
	parent.add_child(puzzle)
	return {"spawn": Vector2(180, 900), "goal": goal}

func _step(parent: Node2D, specifications: Array, door_x: float, mirrored: bool) -> Dictionary:
	var plates: Array[Area2D] = []
	for specification in specifications:
		plates.append(_plate(parent, float(specification[0]), bool(specification[1]), bool(specification[2])))
	var door := StaticBody2D.new()
	door.name = "Door%d" % int(door_x)
	door.position = Vector2(door_x, 180)
	door.set_script(DOOR)
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(28, 720)
	collision.shape = shape
	collision.position = Vector2(14, 360)
	door.add_child(collision)
	_rect(door, Vector2.ZERO, shape.size, Color("#383838"))
	_rect(door, Vector2(10, 0), Vector2(8, 720), Color("#d6d6d6"))
	parent.add_child(door)
	return {"plates": plates, "door": door, "mirrored": mirrored}

func _plate(parent: Node2D, x: float, ceiling: bool, shadow: bool) -> Area2D:
	var area := Area2D.new()
	area.name = ("ShadowPlate" if shadow else "PlayerPlate") + str(int(x))
	area.position = Vector2(x, 192 if ceiling else 888)
	area.set_script(PLATE)
	area.phase_independent = true
	area.player_group = "mirror_self" if shadow else "player"
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(76, 24)
	collision.shape = shape
	area.add_child(collision)
	var tint := Color("#bfbfbf") if shadow else Color("#efefef")
	_rect(area, Vector2(-38, -12), shape.size, tint)
	_rect(area, Vector2(-24, -5), Vector2(48, 10), Color("#222222"))
	parent.add_child(area)
	_hint(area, "影子踏板" if shadow else "本体踏板", Vector2(0, 54 if ceiling else -52), tint)
	return area

func _fragment(parent: Node2D, is_exit: bool) -> Area2D:
	var fragment := Area2D.new()
	fragment.name = "Exit" if is_exit else "ColorFragment"
	fragment.position = Vector2(1760, 810)
	fragment.set_script(FRAGMENT)
	fragment.is_exit = is_exit
	fragment.color = _palette.collect_color
	fragment.color_name = _palette.color_name
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(94, 160)
	collision.shape = shape
	fragment.add_child(collision)
	parent.add_child(fragment)
	fragment.hint = _hint(fragment, _palette.color_name + "碎片", Vector2(0, -110), _palette.collect_color)
	return fragment

func _checkpoint(parent: Node2D) -> void:
	var area := Area2D.new()
	area.name = "Checkpoint"
	area.position = Vector2(270, 850)
	area.set_script(CHECKPOINT)
	area.respawn_position = Vector2(270, 900)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(60, 100)
	collision.shape = shape
	area.add_child(collision)
	_rect(area, Vector2(-18, 10), Vector2(36, 40), Color("#828282"))
	_rect(area, Vector2(-10, 0), Vector2(20, 8), Color("#dfdfdf"))
	parent.add_child(area)
	_hint(area, "存档点", Vector2(0, -36), Color("#cbcbcb"))

func _hint(target: Node2D, text: String, offset: Vector2, tint: Color) -> CanvasLayer:
	var hint := CanvasLayer.new()
	hint.set_script(HINT)
	hint.target = target
	hint.text = text
	hint.world_offset = offset
	hint.tint = tint
	target.add_child(hint)
	return hint

func _platform(parent: Node2D, point: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = point
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	collision.position = size * 0.5
	body.add_child(collision)
	_rect(body, Vector2.ZERO, size, _palette.platform)
	_rect(body, Vector2.ZERO, Vector2(size.x, 3), _palette.edge)
	if point.y == 0:
		_rect(body, Vector2(0, size.y - 3), Vector2(size.x, 3), _palette.edge)
	parent.add_child(body)

func _rect(parent: Node, point: Vector2, size: Vector2, color: Color) -> void:
	var graphic := ColorRect.new()
	graphic.position = point
	graphic.size = size
	graphic.color = color
	graphic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(graphic)

func _decor(parent: Node2D) -> void:
	var lines := Node2D.new()
	lines.z_index = -1
	parent.add_child(lines)
	for i in 8:
		_rect(lines, Vector2(130 + i * 240, 180), Vector2(1, 720), Color(0.65, 0.65, 0.65, 0.08))
	# The axis is visible but does not add another interaction or light puzzle.
	for i in 38:
		_rect(lines, Vector2(i * 52, 539), Vector2(24, 2), Color(0.75, 0.75, 0.75, 0.13))
