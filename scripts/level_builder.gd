extends Node
## Four church rooms: twins, moving mirror, RGB light, then their combination.
const PLATE = preload("res://scripts/mirror_plate.gd")
const DOOR = preload("res://scripts/puzzle_door.gd")
const PUZZLE = preload("res://scripts/room_puzzle.gd")
const FRAGMENT = preload("res://scripts/color_fragment.gd")
const HINT = preload("res://scripts/readable_hint.gd")
const CHECKPOINT = preload("res://scripts/checkpoint.gd")
const SLAB = preload("res://scripts/mirror_slab.gd")
const CIRCUIT = preload("res://scripts/prism_circuit.gd")
const WORLD_WIDTH := 1920.0
var _palette: Dictionary

func build(index: int, parent: Node2D) -> Dictionary:
	_palette = get_node("/root/GameState").get_level(index)
	for child in parent.get_children():
		child.free()
	get_node("/root/GameState").end_light_puzzle()
	_ground_runs(parent, [[0, WORLD_WIDTH]], [[0, WORLD_WIDTH]])
	var steps: Array = []
	match index:
		0:
			var lesson := _step(parent, [[730, true, false], [590, false, true]], 1100, true)
			lesson.hint = "按 M 换面，向右走：你踩上方本体踏板，晚一步的影子踩下方踏板。"
			steps.append(lesson)
		1:
			var slab := _slab(parent)
			var transit := _step(parent, [], 1650, false)
			transit.kind = "slab"
			transit.slab = slab
			transit.hint = "A / D 推动立镜，移入地面的金色刻度，再靠近按 E 穿到镜中另一侧。"
			steps.append(transit)
			_mirror_target(parent)
		2:
			var slab := _slab(parent)
			var light := _light_step(parent, slab, false)
			steps.append(light)
		_:
			var twins := _step(parent, [[380, true, false], [520, false, true]], 700, true)
			twins.hint = "按 M 后先越过两块踏板，再回头：你踩本体，影子靠延迟补上另一块。"
			steps.append(twins)
			var slab := _slab(parent)
			steps.append(_light_step(parent, slab, true))
	_platform(parent, Vector2(-40, 180), Vector2(40, 720))
	_platform(parent, Vector2(WORLD_WIDTH, 180), Vector2(40, 720))
	_decor(parent)
	_checkpoint(parent)
	var goal := _fragment(parent, index == 3)
	var puzzle := Node.new()
	puzzle.name = "RoomPuzzle"
	puzzle.set_script(PUZZLE)
	puzzle.steps = steps
	puzzle.goal = goal
	parent.add_child(puzzle)
	return {"spawn": Vector2(180, 900), "goal": goal, "width": WORLD_WIDTH}

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
	_door_visual(door, shape.size)
	parent.add_child(door)
	return {"kind": "plate", "plates": plates, "door": door, "mirrored": mirrored, "hint": "先越过踏板，再回头，给影子留出半拍。"}

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
	_plate_visual(area, shape.size, tint)
	parent.add_child(area)
	_hint(area, "影子踏板" if shadow else "本体踏板", Vector2(0, 54 if ceiling else -52), tint)
	return area

func _fragment(parent: Node2D, is_exit: bool) -> Area2D:
	var fragment := Area2D.new()
	fragment.name = "Exit" if is_exit else "ColorFragment"
	fragment.position = Vector2(WORLD_WIDTH - 180, 810)
	fragment.set_script(FRAGMENT)
	fragment.is_exit = is_exit
	fragment.color = _palette.collect_color
	fragment.color_name = _palette.color_name
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(94, 160)
	collision.shape = shape
	fragment.add_child(collision)
	if is_exit:
		_exit_visual(fragment)
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
	_checkpoint_visual(area)
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
	_rect_visual(body, Vector2.ZERO, size, _palette.platform)
	_rect_visual(body, Vector2.ZERO, Vector2(size.x, 3), _palette.edge)
	if point.y == 0:
		_rect_visual(body, Vector2(0, size.y - 3), Vector2(size.x, 3), _palette.edge)
	parent.add_child(body)

func _ground_runs(parent: Node2D, floors: Array, ceilings: Array) -> void:
	for span in floors:
		var start: float = span[0]
		var finish: float = span[1]
		_platform(parent, Vector2(start, 900), Vector2(finish - start, 180))
	for span in ceilings:
		_platform(parent, Vector2(span[0], 0), Vector2(span[1] - span[0], 180))

func _slab(parent: Node2D) -> StaticBody2D:
	var slab := StaticBody2D.new()
	slab.name = "MirrorSlab"
	slab.set_script(SLAB)
	slab.position = Vector2(800, 900)
	slab.min_x = 660.0
	slab.max_x = 1200.0
	slab.height = 640.0
	parent.add_child(slab)
	return slab

func _light_step(parent: Node2D, slab: StaticBody2D, transit: bool) -> Dictionary:
	var circuit := Node2D.new()
	circuit.name = "PrismCircuit"
	circuit.set_script(CIRCUIT)
	parent.add_child(circuit)
	var step := _step(parent, [], 1660, false)
	step.kind = "transit_prism" if transit else "prism"
	step.slab = slab
	step.circuit = circuit
	step.hint = "靠近反射镜按 M，只转动最近一面；推动立镜避开光束，让三色接收器同时亮起。"
	if transit:
		step.hint = "双板已解开；推动立镜、按 E 穿镜，再用 M 调整三面反射镜，让三色同时抵达。"
	return step

func _mirror_target(parent: Node2D) -> void:
	_paint(parent, func() -> void:
		var canvas: Node2D = get_meta("gothic_draw_target")
		canvas.draw_line(Vector2(1040, 897), Vector2(1120, 897), Color("#C9A227"), 5)
		for x in [1040.0, 1120.0]:
			canvas.draw_line(Vector2(x, 881), Vector2(x, 900), Color("#C9A227"), 2)
	, Rect2(1038, 879, 84, 23), 3)
	var marker := Node2D.new()
	marker.position = Vector2(1080, 900)
	parent.add_child(marker)
	_hint(marker, "将镜面推入刻度", Vector2(0, 60), Color("#D7C691"))

func _paint(parent: Node2D, painter: Callable, bounds: Rect2, calls: int) -> Node2D:
	var visual := Node2D.new()
	visual.add_to_group("gothic_visuals")
	visual.set_meta("draw_calls", calls)
	visual.set_meta("bounds", bounds)
	visual.draw.connect(func() -> void:
		set_meta("gothic_draw_target", visual)
		painter.call()
	)
	parent.add_child(visual)
	return visual

func _rect_visual(parent: Node, point: Vector2, size: Vector2, color: Color) -> void:
	var bays := mini(12, int(size.x / 160)) if size.y >= 100 else 0
	_paint(parent as Node2D, func() -> void:
		var canvas: Node2D = get_meta("gothic_draw_target")
		canvas.draw_rect(Rect2(point, size), color)
		if bays > 0:
			canvas.draw_rect(Rect2(point + Vector2(0, 8), Vector2(size.x, 12)), Color(_palette.edge, 0.07))
			for y in [34.0, size.y - 8]:
				canvas.draw_line(point + Vector2(0, y), point + Vector2(size.x, y), Color(_palette.edge, 0.18), 1)
			for i in bays:
				var x := (i + 0.5) * size.x / bays
				canvas.draw_line(point + Vector2(x - 68, 35), point + Vector2(x - 68, size.y - 9), Color(_palette.edge, 0.09), 1)
				canvas.draw_set_transform(point + Vector2(x, size.y - 14))
				_arch_visual(Vector2(86, 118), Color(color * 0.73, 1), Color(_palette.edge, 0.16))
			canvas.draw_set_transform(Vector2.ZERO)
	, Rect2(point, size), 4 + bays * 5 if bays > 0 else 1)

func _arch_visual(size: Vector2, fill: Color, edge: Color) -> void:
	var canvas: Node2D = get_meta("gothic_draw_target")
	var w := 64.0
	var h1 := 88.0
	var cap := sqrt(w * w - w * w * 0.25)
	var scale_xy := Vector2(size.x / w, size.y / (h1 + cap))
	var points := PackedVector2Array([Vector2(-w * 0.5, 0) * scale_xy])
	for i in 17:
		var angle := lerpf(PI, PI * 4.0 / 3.0, i / 16.0)
		points.append((Vector2(w * 0.5, -h1) + Vector2(cos(angle), sin(angle)) * w) * scale_xy)
	for i in 17:
		var angle := lerpf(-PI / 3.0, 0, i / 16.0)
		points.append((Vector2(-w * 0.5, -h1) + Vector2(cos(angle), sin(angle)) * w) * scale_xy)
	points.append(Vector2(w * 0.5, 0) * scale_xy)
	canvas.draw_colored_polygon(points, fill)
	points.append(points[0])
	canvas.draw_polyline(points, edge, 3, true)
	# Inner bevel: a second contour pulled in from the outline reads as carved stone.
	var center := Vector2(0, -size.y * 0.5)
	var inner := PackedVector2Array()
	for point in points:
		inner.append(center + (point - center) * 0.93)
	canvas.draw_polyline(inner, Color(edge, edge.a * 0.55), 1.5, true)
	# Keystone at the apex.
	var apex := Vector2(0, -size.y * 0.90)
	canvas.draw_colored_polygon(PackedVector2Array([
		apex + Vector2(-7, -6), apex + Vector2(7, -6), apex + Vector2(0, 12),
	]), Color(edge, edge.a * 0.9))

func _rose_window(center: Vector2, radius: float, tint: Color, seed: int) -> void:
	var canvas: Node2D = get_meta("gothic_draw_target")
	var lead := Color("#14151A")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var disk := PackedVector2Array()
	for i in 64:
		disk.append(center + Vector2.from_angle(TAU * i / 64.0) * radius)
	for ring in 3:
		for sector in 16:
			var r0 := radius * ring / 3.0
			var r1 := radius * (ring + 1) / 3.0
			var a0 := TAU * sector / 16.0
			var a1 := TAU * (sector + 1) / 16.0
			var pane := PackedVector2Array()
			if ring == 0:
				pane.append(center)
			else:
				for i in 5:
					pane.append(center + Vector2.from_angle(lerpf(a0, a1, i / 4.0)) * r0)
			for i in 5:
				pane.append(center + Vector2.from_angle(lerpf(a1, a0, i / 4.0)) * r1)
			var glass := Color(tint, rng.randf_range(0.10, 0.16))
			for clipped in Geometry2D.intersect_polygons(pane, disk):
				canvas.draw_colored_polygon(clipped, glass)
	canvas.draw_arc(center, radius, 0, TAU, 64, lead, 12, true)
	for ring in 3:
		canvas.draw_arc(center, radius * (ring + 1) / 3.0, 0, TAU, 64, lead, 4, true)
	for sector in 16:
		canvas.draw_line(center, center + Vector2.from_angle(TAU * sector / 16.0) * radius, lead, 4, true)

func _flying_buttress(point: Vector2, direction: float) -> void:
	var canvas: Node2D = get_meta("gothic_draw_target")
	var end := point + Vector2(direction * cos(deg_to_rad(62.0)), -sin(deg_to_rad(62.0))) * 180
	var normal := (end - point).orthogonal().normalized() * 7
	var stone := Color(_palette.platform.r * 0.8, _palette.platform.g * 0.8, _palette.platform.b * 0.8)
	canvas.draw_colored_polygon(PackedVector2Array([point - normal, point + normal, end + normal, end - normal]), stone)
	canvas.draw_colored_polygon(PackedVector2Array([end + Vector2(-12, 0), end + Vector2(12, 0), end + Vector2(0, -26)]), stone)

func _decor(parent: Node2D) -> void:
	# The detailed cathedral is now a background plate, without baked actors,
	# gates, checkpoints or platforms. Only actual game nodes draw those.
	_candle_layer(parent)

func _door_visual(owner: Node2D, size: Vector2) -> void:
	var arch := _paint(owner, func() -> void: _arch_visual(Vector2(64, size.y), _palette.platform, _palette.edge), Rect2(-32, -size.y, 64, size.y), 4)
	arch.position = Vector2(size.x * 0.5, size.y)
	_vertical_glow(owner, size.x, size.y)
	_center_strip(owner, size.x, size.y)

func _plate_visual(owner: Node2D, size: Vector2, tint: Color) -> void:
	var support := _paint(owner, func() -> void: _arch_visual(Vector2(64, 143.4256), _palette.platform, Color(_palette.edge, 0.65)), Rect2(-32, -144, 64, 144), 4)
	support.position.y = 12
	if owner.position.y < 540:
		support.scale.y = -1
	_rect_visual(owner, -size * 0.5, size, tint)
	_center_strip(owner, size.x * 0.6, 5)

func _checkpoint_visual(owner: Node2D) -> void:
	var shrine := _paint(owner, func() -> void: _arch_visual(Vector2(64, 143.4256), _palette.platform, _palette.edge), Rect2(-32, -144, 64, 144), 4)
	shrine.position.y = 50

func _exit_visual(owner: Node2D) -> void:
	var portal := _paint(owner, func() -> void: _arch_visual(Vector2(64, 143.4256), _palette.platform, _palette.edge), Rect2(-32, -144, 64, 144), 4)
	portal.name = "ExitVisual"
	portal.position.y = 68

func _vertical_glow(owner: Node2D, width: float, height: float) -> void:
	_rect_visual(owner, Vector2(-8, 0), Vector2(width + 16, height), Color(_palette.accent, 0.035))

func _center_strip(owner: Node2D, width: float, height: float) -> void:
	_paint(owner, func() -> void:
		var canvas: Node2D = get_meta("gothic_draw_target")
		canvas.draw_line(Vector2(width * 0.5, 6), Vector2(width * 0.5, height - 6), Color("#14151A"), 3)
	, Rect2(0, 0, width, height), 1)

func _candle_layer(parent: Node2D) -> void:
	var layer := CanvasLayer.new()
	layer.name = "Candlelight"
	layer.layer = 5
	parent.add_child(layer)
	var canvas := Node2D.new()
	canvas.z_index = 5
	canvas.add_to_group("gothic_visuals")
	canvas.set_meta("draw_calls", 26)
	canvas.set_meta("bounds", Rect2(0, 0, 1920, 1080))
	layer.add_child(canvas)
	canvas.draw.connect(func() -> void:
		var centers := [Vector2(104, 360), Vector2(1816, 720), Vector2(960, 590)]
		var time := Time.get_ticks_msec() * 0.001
		for i in 3:
			var breath := 1.0 + 0.08 * sin(time * 1.7 + i * TAU / 3.0)
			for ring in range(8, 0, -1):
				canvas.draw_circle(centers[i], 14 + ring * 15, Color(Color("#C9A227"), 0.0075 * breath))
		for i in 2:
			var breath := 1.0 + 0.08 * sin(time * 1.7 + i * TAU / 3.0)
			var flame := PackedVector2Array()
			for sample in 16:
				var angle := TAU * sample / 16.0
				flame.append(centers[i] + Vector2(cos(angle) * 2.5, sin(angle) * 7 * breath))
			canvas.draw_colored_polygon(flame, Color(Color("#E8E3D3"), 0.7 * breath))
	)
	var redraw := func() -> void:
		layer.transform = parent.get_viewport().get_canvas_transform()
		canvas.queue_redraw()
	RenderingServer.frame_pre_draw.connect(redraw)
	canvas.tree_exiting.connect(func() -> void: RenderingServer.frame_pre_draw.disconnect(redraw))
