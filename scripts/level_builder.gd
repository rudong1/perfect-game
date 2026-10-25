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
const REGION_DRESSING = preload("res://scripts/region_dressing.gd")
const PALETTE = preload("res://scripts/palette.gd")
const WORLD_WIDTH := 1920.0
var _palette: Dictionary
var _show_plate_roles := true

func build(index: int, parent: Node2D) -> Dictionary:
	_palette = get_node("/root/GameState").get_level(index)
	_show_plate_roles = index == 0
	for child in parent.get_children():
		child.free()
	get_node("/root/GameState").end_light_puzzle()
	_ground_runs(parent, [[0, WORLD_WIDTH]], [[0, WORLD_WIDTH]])
	var steps: Array = []
	match index:
		0:
			var lesson := _step(parent, [[430, false, false], [570, true, true]], 720, false)
			lesson.hint = "先越过两块踏板再折返，让晚半拍的她留在上方，你踩下方本体板。"
			steps.append(lesson)
			var ascent := _step(parent, [[980, true, false], [840, false, true]], 1190, true)
			ascent.hint = "第一道门已开。按 M 换面，再向右，让本体与倒影接力压住第二组。"
			steps.append(ascent)
			var return_step := _step(parent, [[1420, false, false, 56], [1560, true, true, 56]], 1660, false)
			return_step.hint = "回到地面，先走过窄踏板再折返。对齐时保持脚步，别急着停。"
			steps.append(return_step)
		1:
			var release := _step(parent, [[430, true, false], [570, false, true]], 690, true)
			release.hint = "先换面，越过双板再回头配合，解开通往立镜的栅门。"
			steps.append(release)
			var slab := _slab(parent)
			var transit := _step(parent, [], 1390, false)
			transit.kind = "slab"
			transit.slab = slab
			transit.plates.append(_plate(parent, 1230, false, false, "接引踏板"))
			transit.landing_x = 1230.0
			transit.calibration_x = 1080.0
			transit.marker = _mirror_target(parent, 1080, 930, "第一道镜印")
			transit.hint = "回到地面，推镜对准第一道刻度，再退回菱形印记，按 E 直接映上接引踏板。"
			steps.append(transit)
			var return_transit := _step(parent, [], 1660, false)
			return_transit.kind = "slab"
			return_transit.slab = slab
			return_transit.plates.append(_plate(parent, 810, false, false, "回映踏板"))
			return_transit.landing_x = 810.0
			return_transit.calibration_x = 940.0
			return_transit.marker = _mirror_target(parent, 940, 1070, "第二道镜印")
			return_transit.hint = "从右侧把镜子推回新刻度，再站上右侧菱形按 E，映回左侧踏板；解锁后再穿回右边。"
			steps.append(return_transit)
		2:
			var slab := _slab(parent)
			var light := _light_step(parent, slab, false, 1510)
			steps.append(light)
			var duet := _step(parent, [[1390, false, false], [1530, true, true]], 1660, false)
			duet.kind = "paired_prism"
			duet.circuit = light.circuit
			duet.hint = "三色齐亮后，回到地面，越过出口双板再折返：你踩本体，影子接住另一块。"
			steps.append(duet)
		_:
			var twins := _step(parent, [[380, true, false], [520, false, true]], 700, true)
			twins.hint = "按 M 后先越过两块踏板，再回头：你踩本体，影子靠延迟补上另一块。"
			steps.append(twins)
			var slab := _slab(parent)
			var final_duet := _light_step(parent, slab, true)
			final_duet.kind = "transit_paired_prism"
			final_duet.plates.append(_plate(parent, 1390, false, false))
			final_duet.plates.append(_plate(parent, 1530, true, true))
			final_duet.hint = "让影子开启三枚封印，带她穿镜，接通三色；最后回地面折返，共同压住出口双板。"
			steps.append(final_duet)
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
	if index == 0:
		_checkpoint(parent, 1240)
	elif index == 1:
		_checkpoint(parent, 740)
		_checkpoint(parent, 1300)
	return {"spawn": Vector2(180, 900), "goal": goal, "width": WORLD_WIDTH}

func _step(parent: Node2D, specifications: Array, door_x: float, mirrored: bool) -> Dictionary:
	var plates: Array[Area2D] = []
	for specification in specifications:
		plates.append(_plate(parent, float(specification[0]), bool(specification[1]), bool(specification[2]), "", float(specification[3]) if specification.size() > 3 else 76.0))
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

func _plate(parent: Node2D, x: float, ceiling: bool, shadow: bool, caption: String = "", width: float = 76.0, compact: bool = false, color: Color = Color.TRANSPARENT) -> Area2D:
	var area := Area2D.new()
	area.name = ("ShadowPlate" if shadow else "PlayerPlate") + str(int(x))
	area.position = Vector2(x, 192 if ceiling else 888)
	area.set_script(PLATE)
	area.player_group = "mirror_self" if shadow else "player"
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, 24)
	collision.shape = shape
	area.add_child(collision)
	var tint := color if color.a > 0 else (Color("#bfbfbf") if shadow else Color("#efefef"))
	if compact:
		var plaque := _paint(area, func() -> void:
			var canvas: Node2D = get_meta("gothic_draw_target")
			canvas.draw_rect(Rect2(-shape.size * 0.5, shape.size), Color("#282C32"))
			canvas.draw_rect(Rect2(-shape.size * 0.5, shape.size), tint, false, 2)
			var glyph := PackedVector2Array([Vector2(0, -8), Vector2(9, 0), Vector2(0, 8), Vector2(-9, 0)])
			if area.is_activated:
				canvas.draw_colored_polygon(glyph, tint)
			else:
				glyph.append(glyph[0])
				canvas.draw_polyline(glyph, tint, 2, true)
		, Rect2(-shape.size * 0.5, shape.size), 3)
		area.pressure_changed.connect(func(_pressed: bool) -> void: plaque.queue_redraw())
	else:
		_plate_visual(area, shape.size, tint)
	parent.add_child(area)
	if _show_plate_roles or not caption.is_empty():
		_hint(area, caption if not caption.is_empty() else ("影子踏板" if shadow else "本体踏板"), Vector2(0, (92 if compact else 54) if ceiling else (-92 if compact else -52)), tint)
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
	fragment.hint = _hint(fragment, "出口" if is_exit else _palette.color_name + "碎片", Vector2(0, -110), _palette.collect_color)
	return fragment

func _checkpoint(parent: Node2D, x: float = 270.0) -> void:
	var area := Area2D.new()
	area.name = "Checkpoint" if is_equal_approx(x, 270) else "Checkpoint%d" % int(x)
	area.position = Vector2(x, 850)
	area.set_script(CHECKPOINT)
	area.respawn_position = Vector2(x, 900)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(60, 100)
	collision.shape = shape
	area.add_child(collision)
	_checkpoint_visual(area)
	parent.add_child(area)

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

func _light_step(parent: Node2D, slab: StaticBody2D, transit: bool, door_x: float = 1660.0) -> Dictionary:
	var circuit := Node2D.new()
	circuit.name = "PrismCircuit"
	circuit.set_script(CIRCUIT)
	var locks: Array[Area2D] = []
	for i in 3:
		var seal := _plate(parent, [490.0, 990.0, 1370.0][i], i != 1, true, "影子封印 · " + PALETTE.CHANNEL_NAMES[i], 76, true, CIRCUIT.COLORS[i])
		seal.latching = true
		locks.append(seal)
	circuit.shadow_locks = locks
	parent.add_child(circuit)
	# Late rooms let both actors cross the slab. Their shared horizontal delay,
	# gravity and collision roles stay unchanged after this deliberate regroup.
	slab.set_meta("carries_echo", true)
	slab.transported.connect(_carry_echo)
	var step := _step(parent, [], door_x, false)
	step.kind = "transit_prism" if transit else "prism"
	step.slab = slab
	step.circuit = circuit
	step.hint = "让影子依次踩上、下、上三枚封印；推镜避光，按 E 带她穿镜，再调整最近的反射镜。"
	if transit:
		step.hint = "双板已解开；推动立镜、按 E 穿镜，再用 M 调整三面反射镜，让三色同时抵达。"
	return step

func _carry_echo(body: CharacterBody2D) -> void:
	var echo := get_tree().get_first_node_in_group("mirror_self")
	if is_instance_valid(echo) and echo.source == body:
		echo.reset_echo.call_deferred()

func _mirror_target(parent: Node2D, axis: float, entry: float, caption: String) -> Node2D:
	var marker := Node2D.new()
	marker.name = "MirrorMark%d" % int(axis)
	parent.add_child(marker)
	_paint(marker, func() -> void:
		var canvas: Node2D = get_meta("gothic_draw_target")
		canvas.draw_line(Vector2(axis - 18, 897), Vector2(axis + 18, 897), Color("#D4D4D4"), 5)
		for x in [axis - 18, axis, axis + 18]:
			canvas.draw_line(Vector2(x, 882), Vector2(x, 900), Color("#D4D4D4"), 2)
	, Rect2(axis - 20, 880, 40, 23), 4)
	_hint(marker, caption + " · 对齐镜面", Vector2(axis, 960), Color("#D4D4D4"))
	_paint(marker, func() -> void:
		var canvas: Node2D = get_meta("gothic_draw_target")
		var points := PackedVector2Array([Vector2(entry, 879), Vector2(entry + 14, 890), Vector2(entry, 900), Vector2(entry - 14, 890), Vector2(entry, 879)])
		canvas.draw_polyline(points, Color("#D4D4D4"), 2, true)
		canvas.draw_line(Vector2(entry - 28, 899), Vector2(entry + 28, 899), Color("#D4D4D4"), 3)
	, Rect2(entry - 30, 877, 60, 25), 2)
	return marker

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
	var dressing := Node2D.new()
	dressing.name = "RegionDressing"
	dressing.set_script(REGION_DRESSING)
	dressing.region = get_node("/root/GameState").current_level
	dressing.stone = _palette.platform
	dressing.edge = _palette.edge
	dressing.z_index = -2
	parent.add_child(dressing)

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
	_paint(owner, func() -> void:
		var canvas: Node2D = get_meta("gothic_draw_target")
		var glyph := PackedVector2Array([Vector2(0, -55), Vector2(10, -40), Vector2(0, -25), Vector2(-10, -40), Vector2(0, -55)])
		canvas.draw_polyline(glyph, Color("#D4D4D4"), 2, true)
		canvas.draw_line(Vector2(-13, -15), Vector2(13, -15), Color("#D4D4D4"), 2)
	, Rect2(-15, -57, 30, 44), 2)

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
