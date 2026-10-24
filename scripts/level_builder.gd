extends Node
## Builds the five single-screen mirror rooms at runtime.
##
## Keeping the rooms in one builder lets the rooms share the same component
## scripts, palette and goal flow. Each room is exactly one 1920x1080 screen
## with a fixed camera.

const MIRROR_PLATFORM = preload("res://scripts/mirror_platform.gd")
const MIRROR_GATE = preload("res://scripts/mirror_gate.gd")
const MIRROR_PLATE = preload("res://scripts/mirror_plate.gd")
const PUZZLE_DOOR = preload("res://scripts/puzzle_door.gd")
const GOAL_SCRIPT = preload("res://scripts/level_goal.gd")
const HAZARD_SCRIPT = preload("res://scripts/hazard.gd")
const FALL_SCRIPT = preload("res://scripts/fall_reset.gd")
const CHECKPOINT_SCRIPT = preload("res://scripts/checkpoint.gd")

const MIRROR_SLAB = preload("res://scripts/mirror_slab.gd")
const PRISM_CIRCUIT = preload("res://scripts/prism_circuit.gd")
const ROOM_PUZZLE = preload("res://scripts/room_puzzle.gd")

const FLOOR_Y := 900.0
const SCREEN_W := 1920.0
const SCREEN_H := 1080.0

var _palette: Dictionary = {}


func build(level_index: int, parent: Node2D) -> Dictionary:
	var state := get_node_or_null("/root/GameState")
	_palette = state.get_level(level_index) if state != null else {}
	_clear(parent)
	_side_walls(parent)
	_static_platform(parent, Vector2.ZERO, Vector2(SCREEN_W, 180), true)
	_fall_reset(parent)

	var spawn := Vector2(180, FLOOR_Y)
	var goal: Area2D

	match level_index:
		0:
			goal = _level_0(parent, spawn)
		1:
			goal = _level_1(parent, spawn)
		2:
			goal = _level_2(parent, spawn)
		3:
			goal = _level_3(parent, spawn)
		_:
			goal = _level_4(parent, spawn)

	_decor(parent, level_index)
	return {"spawn": spawn, "goal": goal}


# ---------------------------------------------------------------------------
# Rooms
# ---------------------------------------------------------------------------

func _level_0(parent: Node2D, _spawn: Vector2) -> Area2D:
	_ground(parent, 0, FLOOR_Y, SCREEN_W)
	_checkpoint(parent, 260)
	var lower := _pressure_plate(parent, Vector2(590, 888), false)
	var upper := _pressure_plate(parent, Vector2(730, 192), true)
	var door := _door(parent, 1100)
	var goal := _goal(parent, 1780)
	_puzzle(parent, "twins", goal, door, [lower, upper])
	_inscription(parent, Vector2(370, 470), "两颗星，一次回声。先越过，再回头。")
	return goal


func _level_1(parent: Node2D, _spawn: Vector2) -> Area2D:
	_ground(parent, 0, FLOOR_Y, 1330)
	_ground(parent, 1540, FLOOR_Y - 100, 380)
	_static_platform(parent, Vector2(1260, 840), Vector2(70, 60), true)
	_hazard(parent, 1330, 1540, 1000)
	_checkpoint(parent, 260)
	var slab := _slab(parent, 800, 660, 1200)
	var door := _door(parent, 1650)
	var goal := _goal(parent, 1800)
	goal.position.y = 710
	var puzzle := _puzzle(parent, "slab", goal, door)
	puzzle.slab = slab
	_target_zone(parent, 1040, 1120)
	_inscription(parent, Vector2(440, 470), "移动镜轴，出口也随之移动。")
	return goal


func _level_2(parent: Node2D, _spawn: Vector2) -> Area2D:
	return _light_room(parent, false, false)


func _level_3(parent: Node2D, _spawn: Vector2) -> Area2D:
	return _light_room(parent, true, false)


func _level_4(parent: Node2D, _spawn: Vector2) -> Area2D:
	return _light_room(parent, false, true)


func _light_room(parent: Node2D, twins: bool, transit: bool) -> Area2D:
	_ground(parent, 0, FLOOR_Y, SCREEN_W)
	_checkpoint(parent, 260)
	var slab := _slab(parent, 800, 740, 1180)
	var circuit := Node2D.new()
	circuit.name = "PrismCircuit"
	circuit.set_script(PRISM_CIRCUIT)
	parent.add_child(circuit)
	var door := _door(parent, 1660)
	var goal := _goal(parent, 1800)
	var plates: Array[Area2D] = []
	if twins:
		plates.append(_pressure_plate(parent, Vector2(380, 888), false))
		plates.append(_pressure_plate(parent, Vector2(520, 192), true))
	var kind := "twins_prism" if twins else ("transit_prism" if transit else "prism")
	var puzzle := _puzzle(parent, kind, goal, door, plates)
	puzzle.slab = slab
	puzzle.circuit = circuit
	_target_zone(parent, 980, 1080)
	_inscription(parent, Vector2(700, 370), "五颗沉星，借镜中的光回家。")
	return goal


func _pressure_plate(parent: Node2D, point: Vector2, mirrored: bool) -> Area2D:
	var area := Area2D.new()
	area.position = point
	area.name = "UpperPlate" if mirrored else "LowerPlate"
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(64, 24)
	collision.shape = shape
	area.add_child(collision)
	var graphic := Node2D.new()
	graphic.position = Vector2(-32, -12)
	_rect_visual(graphic, shape.size, _palette.accent, _palette.edge, 4)
	area.add_child(graphic)
	area.set_script(MIRROR_PLATE)
	area.requires_mirror = mirrored
	area.phase_independent = true
	parent.add_child(area)
	return area


func _slab(parent: Node2D, x: float, minimum: float, maximum: float) -> StaticBody2D:
	var slab := StaticBody2D.new()
	slab.name = "MirrorSlab"
	slab.position = Vector2(x, FLOOR_Y)
	slab.set_script(MIRROR_SLAB)
	slab.min_x = minimum
	slab.max_x = maximum
	slab.height = 640.0
	parent.add_child(slab)
	return slab


func _puzzle(parent: Node2D, kind: String, goal: Area2D, door: StaticBody2D, plates: Array[Area2D] = []) -> Node:
	var puzzle := Node.new()
	puzzle.name = "RoomPuzzle"
	puzzle.set_script(ROOM_PUZZLE)
	puzzle.kind = kind
	puzzle.goal = goal
	puzzle.door = door
	puzzle.plates = plates
	parent.add_child(puzzle)
	return puzzle


func _target_zone(parent: Node2D, from_x: float, to_x: float) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([Vector2(from_x, 890), Vector2(to_x, 890)])
	line.width = 6
	line.default_color = Color(0.45, 0.95, 0.75, 0.55)
	parent.add_child(line)


# ---------------------------------------------------------------------------
# Building blocks
# ---------------------------------------------------------------------------

func _clear(parent: Node2D) -> void:
	for child in parent.get_children():
		child.free()


func _side_walls(parent: Node2D) -> void:
	for x in [-24.0, SCREEN_W + 4.0]:
		var body := StaticBody2D.new()
		body.position = Vector2(x, 0)
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(40, SCREEN_H + 200)
		collision.shape = shape
		collision.position = Vector2(20, (SCREEN_H + 200) * 0.5)
		body.add_child(collision)
		parent.add_child(body)


func _fall_reset(parent: Node2D) -> void:
	var area := Area2D.new()
	area.position = Vector2(SCREEN_W * 0.5, 1200)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(SCREEN_W + 400, 80)
	collision.shape = shape
	area.add_child(collision)
	area.set_script(FALL_SCRIPT)
	parent.add_child(area)


func _ground(parent: Node2D, x: float, y: float, width: float) -> void:
	_static_platform(parent, Vector2(x, y), Vector2(width, 180), true)


func _static_platform(parent: Node2D, position: Vector2, size: Vector2, ledge: bool) -> void:
	var body := StaticBody2D.new()
	body.position = position
	var collision := CollisionShape2D.new()
	collision.name = "Collision"
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	collision.position = size * 0.5
	body.add_child(collision)
	_rect_visual(body, size, _palette.platform, _palette.edge, 4.0 if ledge else 2.0)
	if size.y >= 160.0:
		var seam_color := Color(_palette.edge.r, _palette.edge.g, _palette.edge.b, 0.09)
		var seam_x := 110.0
		while seam_x < size.x:
			var seam := ColorRect.new()
			seam.position = Vector2(seam_x, 8)
			seam.size = Vector2(1, size.y - 8)
			seam.color = seam_color
			seam.mouse_filter = Control.MOUSE_FILTER_IGNORE
			body.add_child(seam)
			seam_x += 160.0
	parent.add_child(body)


func _bridge(parent: Node2D, x0: float, x1: float, y: float) -> void:
	var size := Vector2(x1 - x0, 24)
	var body := StaticBody2D.new()
	body.position = Vector2(x0, y)
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	collision.position = size * 0.5
	body.add_child(collision)
	_rect_visual(body, size, _palette.accent, _palette.accent, 3.0, 0.35)
	body.set_script(MIRROR_PLATFORM)
	body.set("solid_when_mirrored", true)
	body.set("visible_when_mirrored", true)
	parent.add_child(body)


func _gate(parent: Node2D, x: float, solid_when_mirrored: bool) -> StaticBody2D:
	var height := 150.0
	var width := 30.0
	var body := StaticBody2D.new()
	body.position = Vector2(x, FLOOR_Y - height)
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, height)
	collision.shape = shape
	collision.position = Vector2(width * 0.5, height * 0.5)
	body.add_child(collision)
	_vertical_glow(body, width, height)
	_rect_visual(body, Vector2(width, height), _palette.platform, _palette.accent, 3.0)
	_center_strip(body, width, height)
	body.set_script(MIRROR_GATE)
	body.set("solid_when_mirrored", solid_when_mirrored)
	parent.add_child(body)
	return body


func _plate(parent: Node2D, x: float, requires_mirror: bool) -> Area2D:
	var area := Area2D.new()
	area.position = Vector2(x, FLOOR_Y - 12)
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(100, 24)
	collision.shape = shape
	area.add_child(collision)
	_rect_visual(area, Vector2(100, 24), _palette.accent, _palette.edge, 3.0, 0.7)
	area.set_script(MIRROR_PLATE)
	area.set("requires_mirror", requires_mirror)
	parent.add_child(area)
	return area


func _door(parent: Node2D, x: float) -> StaticBody2D:
	var height := 720.0
	var width := 30.0
	var body := StaticBody2D.new()
	body.position = Vector2(x, FLOOR_Y - height)
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, height)
	collision.shape = shape
	collision.position = Vector2(width * 0.5, height * 0.5)
	body.add_child(collision)
	_vertical_glow(body, width, height)
	_rect_visual(body, Vector2(width, height), _palette.platform, _palette.accent, 3.0)
	_center_strip(body, width, height)
	body.set_script(PUZZLE_DOOR)
	parent.add_child(body)
	return body


func _goal(parent: Node2D, x: float) -> Area2D:
	var area := Area2D.new()
	area.position = Vector2(x, 810)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(100, 180)
	collision.shape = shape
	area.add_child(collision)

	var halo := Polygon2D.new()
	halo.polygon = PackedVector2Array([
		Vector2(0, -98), Vector2(64, 0), Vector2(0, 98), Vector2(-64, 0)
	])
	halo.color = Color(_palette.accent.r, _palette.accent.g, _palette.accent.b, 0.10)
	area.add_child(halo)

	var diamond := Polygon2D.new()
	diamond.polygon = PackedVector2Array([
		Vector2(0, -72), Vector2(46, 0), Vector2(0, 72), Vector2(-46, 0)
	])
	diamond.color = _palette.accent
	area.add_child(diamond)

	var inner := Polygon2D.new()
	inner.polygon = PackedVector2Array([
		Vector2(0, -42), Vector2(26, 0), Vector2(0, 42), Vector2(-26, 0)
	])
	inner.color = _palette.bg_top
	area.add_child(inner)

	area.set_script(GOAL_SCRIPT)
	parent.add_child(area)
	return area


func _hazard(parent: Node2D, x0: float, x1: float, y: float) -> void:
	var area := Area2D.new()
	area.position = Vector2((x0 + x1) * 0.5, y)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(x1 - x0, 40)
	collision.shape = shape
	area.add_child(collision)

	var count := int((x1 - x0) / 48.0)
	var left := -(x1 - x0) * 0.5
	for i in count:
		var spike := Polygon2D.new()
		var sx := left + i * 48.0
		spike.polygon = PackedVector2Array([
			Vector2(sx, 20), Vector2(sx + 24, -22), Vector2(sx + 48, 20)
		])
		spike.color = _palette.hazard
		area.add_child(spike)
	area.set_script(HAZARD_SCRIPT)
	parent.add_child(area)


func _inscription(parent: Node2D, position: Vector2, text: String) -> void:
	var label := Label.new()
	label.position = position
	label.size = Vector2(560, 64)
	label.text = text
	label.scale = Vector2(1, -1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", _palette.accent)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)


func _decor(parent: Node2D, level_index: int) -> void:
	var decor := Node2D.new()
	decor.name = "Decor"
	decor.z_index = -1
	parent.add_child(decor)

	var accent: Color = _palette.accent
	var beam := Color(accent.r, accent.g, accent.b, 0.13)
	for i in 5:
		var x := 170.0 + i * 390.0
		var line := ColorRect.new()
		line.position = Vector2(x, 160)
		line.size = Vector2(3, 720)
		line.color = beam
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		decor.add_child(line)

	# Faint hanging glass shards: vertical threads with a small diamond.
	for i in 4:
		var x := 330.0 + i * 420.0
		var thread := ColorRect.new()
		thread.position = Vector2(x, 120)
		thread.size = Vector2(1, 200 + (i % 2) * 90)
		thread.color = Color(accent.r, accent.g, accent.b, 0.12)
		thread.mouse_filter = Control.MOUSE_FILTER_IGNORE
		decor.add_child(thread)
		var shard := Polygon2D.new()
		shard.polygon = PackedVector2Array([
			Vector2(0, -16), Vector2(10, 0), Vector2(0, 16), Vector2(-10, 0)
		])
		shard.position = Vector2(x, 336 + (i % 2) * 90)
		shard.color = Color(accent.r, accent.g, accent.b, 0.32)
		decor.add_child(shard)

	var diamond_color := Color(accent.r, accent.g, accent.b, 0.20)
	for i in 4:
		var diamond := Polygon2D.new()
		var x := 300.0 + i * 440.0
		var y := 470.0 + (i % 2) * 160.0
		diamond.polygon = PackedVector2Array([
			Vector2(0, -24), Vector2(15, 0), Vector2(0, 24), Vector2(-15, 0)
		])
		diamond.position = Vector2(x, y)
		diamond.color = diamond_color
		decor.add_child(diamond)

	# Thin room frame.
	for x in [34.0, 1886.0]:
		var frame := ColorRect.new()
		frame.position = Vector2(x, 150)
		frame.size = Vector2(2, 790)
		frame.color = Color(accent.r, accent.g, accent.b, 0.14)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		decor.add_child(frame)

	if level_index == 4:
		var rainbow := [Color("#ff5c71"), Color("#51c8ff"), Color("#69e39d")]
		for i in 3:
			var shard := Polygon2D.new()
			shard.polygon = PackedVector2Array([
				Vector2(0, -28), Vector2(16, 0), Vector2(0, 28), Vector2(-16, 0)
			])
			shard.position = Vector2(1120 + i * 120, 360 + i * 40)
			shard.color = rainbow[i]
			decor.add_child(shard)


func _rect_visual(owner: Node, size: Vector2, color: Color, edge: Color, edge_height: float, alpha: float = 1.0) -> void:
	var fill := ColorRect.new()
	fill.position = Vector2.ZERO
	fill.size = size
	fill.color = Color(color.r, color.g, color.b, color.a * alpha)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.add_child(fill)

	var line := ColorRect.new()
	line.position = Vector2.ZERO
	line.size = Vector2(size.x, edge_height)
	line.color = edge
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.add_child(line)


func _checkpoint(parent: Node2D, x: float) -> void:
	var area := Area2D.new()
	area.name = "Checkpoint"
	area.position = Vector2(x, 860)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(80, 140)
	collision.shape = shape
	area.add_child(collision)

	var halo := Polygon2D.new()
	halo.polygon = PackedVector2Array([
		Vector2(0, -60), Vector2(38, 0), Vector2(0, 60), Vector2(-38, 0)
	])
	halo.color = Color(_palette.accent.r, _palette.accent.g, _palette.accent.b, 0.10)
	area.add_child(halo)

	var diamond := Polygon2D.new()
	diamond.polygon = PackedVector2Array([
		Vector2(0, -30), Vector2(18, 0), Vector2(0, 30), Vector2(-18, 0)
	])
	diamond.color = Color(_palette.accent.r, _palette.accent.g, _palette.accent.b, 0.75)
	area.add_child(diamond)

	var base := ColorRect.new()
	base.position = Vector2(-28, 36)
	base.size = Vector2(56, 8)
	base.color = _palette.edge
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(base)

	var label := Label.new()
	label.text = "存档点"
	label.position = Vector2(-44, -92)
	label.size = Vector2(88, 22)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", _palette.accent)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(label)

	area.set_script(CHECKPOINT_SCRIPT)
	area.set("respawn_position", Vector2(x, FLOOR_Y))
	parent.add_child(area)


func _vertical_glow(owner: Node, width: float, height: float) -> void:
	var glow := ColorRect.new()
	glow.position = Vector2(-18, -8)
	glow.size = Vector2(width + 36, height + 16)
	glow.color = Color(_palette.accent.r, _palette.accent.g, _palette.accent.b, 0.09)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.add_child(glow)


func _center_strip(owner: Node, width: float, height: float) -> void:
	var strip := ColorRect.new()
	strip.position = Vector2(width * 0.5 - 2.0, 6)
	strip.size = Vector2(4, height - 12)
	strip.color = Color(_palette.accent.r, _palette.accent.g, _palette.accent.b, 0.75)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.add_child(strip)
