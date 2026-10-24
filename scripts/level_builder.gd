extends Node
## Four compact worlds using only gravity flips and the delayed shadow.
const PLATE = preload("res://scripts/mirror_plate.gd")
const DOOR = preload("res://scripts/puzzle_door.gd")
const PUZZLE = preload("res://scripts/room_puzzle.gd")
const FRAGMENT = preload("res://scripts/color_fragment.gd")
const HINT = preload("res://scripts/readable_hint.gd")
const CHECKPOINT = preload("res://scripts/checkpoint.gd")
const BRIDGE = preload("res://scripts/shadow_bridge.gd")
const BARRIER = preload("res://scripts/shadow_barrier.gd")
const WORLD_WIDTH := 3840.0
var _palette: Dictionary

func build(index: int, parent: Node2D) -> Dictionary:
	_palette = get_node("/root/GameState").get_level(index)
	for child in parent.get_children():
		child.free()
	var steps: Array = []
	match index:
		0:
			_ground_runs(parent, [[0, 1040], [1400, 2280], [2640, WORLD_WIDTH]], [[0, WORLD_WIDTH]])
			var lesson := _step(parent, [[650, false, true]], 920, true)
			lesson.hint = "鍏堟寜 M 璁╁奖瀛愭潵鍒板彟涓€闈紝璧拌繃褰卞瓙韪忔澘銆?
			steps.append(lesson)
			steps.append(_route(parent, 1510, 1660, "鏂矾涓婃柟鎸?M 鍥炴潵锛岃惤鍦ㄥ宀革紱涔熻鐓ч【鏅氫竴姝ョ殑褰卞瓙銆?))
			steps.append(_bridge_step(parent, 2280, 2640, 2080, 2900))
		1:
			_ground_runs(parent, [[0, 760], [1120, 2700], [3060, WORLD_WIDTH]], [[0, 1440], [1740, WORLD_WIDTH]])
			var first_route := _route(parent, 1260, 1360, "璺冲悜鏂彛锛屽崐绌烘寜 M锛涜蛋鍒扮己鍙ｄ笂鏂瑰啀缈诲洖鏉ャ€?)
			first_route.checkpoint_x = 1280.0
			steps.append(first_route)
			steps.append(_route(parent, 2130, 2250, "澶╄姳鏉夸篃鏈夋柇璺細鎺ヨ繎褰卞瓙鍓嶆柟鐨勭己鍙ｆ椂鎹㈤潰锛屽啀鍥炲湴闈€?))
			steps.append(_bridge_step(parent, 2700, 3060, 2500, 3330))
		2:
			_ground_runs(parent, [[0, 2240], [2640, WORLD_WIDTH]], [[0, WORLD_WIDTH]])
			steps.append(_release_step(parent, 900, 1350))
			steps.append(_route(parent, 1510, 1680, "鎶婂奖瀛愰噴鏀惧悗鍥炲埌鍦伴潰锛岃濂规潵鍒颁笂鏂圭殑鎾戞ˉ韪忔澘銆?))
			steps.append(_bridge_step(parent, 2240, 2640, 2040, 2920))
		_:
			_ground_runs(parent, [[0, 760], [1120, 2800], [3160, WORLD_WIDTH]], [[0, WORLD_WIDTH]])
			steps.append(_route(parent, 1250, 1360, "鍏堝畬鎴愪竴娆＄┖涓崲闈紝钀藉埌瀵瑰哺銆?))
			steps.append(_release_step(parent, 1600, 2030))
			steps.append(_bridge_step(parent, 2800, 3160, 2600, 3400))
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
	# A checkpoint after each section restores completed challenges on a retry.
	for step in steps:
		if step.door.position.x < 3400:
			_checkpoint_at(parent, step.get("checkpoint_x", step.door.position.x + 100))
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
	return {"kind": "plate", "plates": plates, "door": door, "mirrored": mirrored, "hint": "鍏堣秺杩囪笍鏉匡紝鍐嶅洖澶达紝缁欏奖瀛愮暀鍑哄崐鎷嶃€?}

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
	_hint(area, "褰卞瓙韪忔澘" if shadow else "鏈綋韪忔澘", Vector2(0, 54 if ceiling else -52), tint)
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
	fragment.hint = _hint(fragment, _palette.color_name + "纰庣墖", Vector2(0, -110), _palette.collect_color)
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
	_hint(area, "瀛樻。鐐?, Vector2(0, -36), Color("#cbcbcb"))

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

func _route(parent: Node2D, target_x: float, door_x: float, hint: String) -> Dictionary:
	var step := _step(parent, [], door_x, false)
	step.kind = "reach"
	step.target_x = target_x
	step.hint = hint
	return step

func _release_step(parent: Node2D, x: float, door_x: float) -> Dictionary:
	var barrier := StaticBody2D.new()
	barrier.name = "ShadowBarrier"
	barrier.position = Vector2(x, 180)
	barrier.set_script(BARRIER)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(42, 290)
	collision.shape = shape
	collision.position = shape.size * 0.5
	barrier.add_child(collision)
	_rect_visual(barrier, Vector2.ZERO, shape.size, _palette.platform)
	_rect_visual(barrier, Vector2(0, 286), Vector2(42, 4), _palette.edge)
	parent.add_child(barrier)
	_hint(barrier, "璁╁奖瀛愬仠鍦ㄨ繖閲岋紝鍐嶇炕杞甫濂圭粫杩?, Vector2(0, 340), _palette.edge)
	var step := _step(parent, [], door_x, true)
	step.kind = "release"
	step.barrier = barrier
	step.hint = "鍏堣褰卞瓙琚í姊佹尅浣忥紱浣犺蛋鍒板彟涓€渚у啀鎸?M锛屾妸濂瑰甫鍒板湴闈€?
	return step

func _bridge_step(parent: Node2D, start: float, finish: float, plate_x: float, door_x: float) -> Dictionary:
	var plate := _plate(parent, plate_x, true, true)
	var bridge := Node2D.new()
	bridge.name = "ShadowBridge"
	bridge.position = Vector2(start, 900)
	bridge.set_script(BRIDGE)
	bridge.plate = plate
	bridge.width = finish - start
	parent.add_child(bridge)
	_hint(plate, "褰卞瓙鎾戞ˉ 路 绂诲紑鍚庢ˉ浼氭秷閫€", Vector2(0, 100), _palette.edge)
	var step := _step(parent, [], door_x, false)
	step.kind = "bridge"
	step.bridge = bridge
	step.target_x = finish + 50
	step.hint = "鍥炲埌鍦伴潰锛屼繚鎸佸悜鍓嶏紱璁╁奖瀛愭拺璧锋ˉ锛屽湪妗ユ秷閫€鍓嶈窇鍒板宀搞€?
	return step

func _checkpoint_at(parent: Node2D, x: float) -> void:
	_checkpoint(parent)
	var checkpoint := parent.get_child(parent.get_child_count() - 1) as Area2D
	checkpoint.position.x = x
	checkpoint.respawn_position = Vector2(x, 900)

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
	_paint(parent as Node2D, func() -> void:
		var canvas: Node2D = get_meta("gothic_draw_target")
		canvas.draw_rect(Rect2(point, size), color)
		if size.y >= 100 and size.x >= 100:
			for i in 3:
				var x := point.x + (i + 1) * size.x / 4.0
				canvas.draw_line(Vector2(x, point.y + 5), Vector2(x, point.y + size.y - 5), Color(_palette.edge, 0.1), 1)
	, Rect2(point, size), 4 if size.y >= 100 and size.x >= 100 else 1)

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
			var glass := Color(tint, rng.randf_range(0.20, 0.40) * (1.0 - float(ring) * 0.18))
			for clipped in Geometry2D.intersect_polygons(pane, disk):
				canvas.draw_colored_polygon(clipped, glass)
	canvas.draw_circle(center, radius * 0.15, Color(tint, 0.62))
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
	var index: int = get_node("/root/GameState").current_level
	var background := parent.get_parent().get_node("Backdrop/Base").material as ShaderMaterial
	background.set_shader_parameter("platform_color", _palette.platform)
	background.set_shader_parameter("moss_enabled", index == 3)
	# Each world owns its light: colour, direction and atmosphere come from the palette.
	background.set_shader_parameter("light_color", _palette.get("light_color", _palette.accent))
	background.set_shader_parameter("light_dir", _palette.get("light_dir", -1.0))
	background.set_shader_parameter("saturation", _palette.get("saturation", 1.0))
	background.set_shader_parameter("fog_amount", _palette.get("fog", 0.0))
	var decor := Node2D.new()
	decor.name = "GothicChurch"
	decor.z_index = -3
	parent.add_child(decor)
	# Aisle arcade: recessive piers, brightest on the lit side.
	for x in [150.0, 430.0, 710.0, 1210.0, 1490.0, 1770.0]:
		var bay := _paint(decor, func() -> void:
			_arch_visual(Vector2(190, 640), Color(_palette.platform, 0.30), Color(_palette.edge, 0.26))
		, Rect2(-95, -640, 190, 640), 6)
		bay.position = Vector2(x, 900)
	_paint(decor, func() -> void: _rose_window(Vector2(960, 300), 210, _palette.accent, index), Rect2(744, 84, 432, 432), 68)
	for side in [-1.0, 1.0]:
		for i in 3:
			var base := Vector2(48 if side > 0 else 1872, 370 + i * 260)
			_paint(decor, func() -> void: _flying_buttress(base, side), Rect2(base - Vector2(110, 190), Vector2(220, 220)), 3)
	_candle_layer(parent)

func _door_visual(owner: Node2D, size: Vector2) -> void:
	var arch := _paint(owner, func() -> void: _arch_visual(Vector2(64, size.y), _palette.platform, _palette.edge), Rect2(-32, -size.y, 64, size.y), 2)
	arch.position = Vector2(size.x * 0.5, size.y)
	_vertical_glow(owner, size.x, size.y)
	_center_strip(owner, size.x, size.y)

func _plate_visual(owner: Node2D, size: Vector2, tint: Color) -> void:
	var support := _paint(owner, func() -> void: _arch_visual(Vector2(64, 143.4256), _palette.platform, Color(_palette.edge, 0.65)), Rect2(-32, -144, 64, 144), 2)
	support.position.y = 12
	if owner.position.y < 540:
		support.scale.y = -1
	_rect_visual(owner, -size * 0.5, size, tint)
	_center_strip(owner, size.x * 0.6, 5)

func _checkpoint_visual(owner: Node2D) -> void:
	var shrine := _paint(owner, func() -> void: _arch_visual(Vector2(64, 143.4256), _palette.platform, _palette.edge), Rect2(-32, -144, 64, 144), 2)
	shrine.position.y = 50

func _exit_visual(owner: Node2D) -> void:
	var portal := _paint(owner, func() -> void: _arch_visual(Vector2(64, 143.4256), _palette.platform, _palette.edge), Rect2(-32, -144, 64, 144), 2)
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
				canvas.draw_circle(centers[i], 18 + ring * 22, Color(Color("#C9A227"), 0.022 * breath))
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
