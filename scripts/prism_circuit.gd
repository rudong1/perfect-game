extends Node2D
## Three geometric beams. M rotates only the mirror nearest the player's X;
## moving the slab changes occlusion, so orientation alone is insufficient.
signal channels_changed(mask: int)
const COLORS := [Color("#ff5c71"), Color("#69e39d"), Color("#51c8ff")]
var mirrors: Array[Vector2] = [Vector2(520, 410), Vector2(960, 530), Vector2(1400, 650)]
var upward: Array[bool] = [false, false, false]
var channel_mask := 0
var selected := -1
var _paths: Array = []
var _player: CharacterBody2D
var _state: Node

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	_state = get_node("/root/GameState")
	_state.begin_light_puzzle()
	get_node("/root/MirrorState").mirror_changed.connect(_on_flip)
	get_node("/root/MirrorState").reset_requested.connect(reset)

func reset() -> void:
	upward = [false, false, false]
	update_beams()

func _on_flip(_mirrored: bool) -> void:
	if _player.is_physics_processing() and get_node("/root/MirrorState").input_enabled:
		select_nearest()
		if selected >= 0:
			upward[selected] = not upward[selected]
		update_beams()

func select_nearest() -> void:
	selected = -1
	var best := 185.0
	for i in mirrors.size():
		var distance := absf(_player.global_position.x - mirrors[i].x)
		if distance < best:
			best = distance
			selected = i

func _physics_process(_delta: float) -> void:
	if not _player.is_physics_processing():
		return
	select_nearest()
	update_beams()

func update_beams() -> void:
	var mask := 0
	_paths.clear()
	for channel in 3:
		var start := mirrors[channel] - Vector2(300, 0)
		var direction := Vector2.RIGHT
		var points := PackedVector2Array([start])
		var previous := -1
		for bounce in 6:
			var end := start + direction * 2200
			var nearest := 2200.0
			var hit_type := ""
			var hit_index := -1
			for i in 3:
				if i == previous:
					continue
				var tangent := Vector2(1, -1 if upward[i] else 1).normalized() * 60
				var hit = Geometry2D.segment_intersects_segment(start, end, mirrors[i] - tangent, mirrors[i] + tangent)
				if hit != null and start.distance_to(hit) < nearest:
					nearest = start.distance_to(hit)
					hit_type = "mirror"
					hit_index = i
			for slab in get_tree().get_nodes_in_group("mirror_slabs"):
				var point: Vector2 = slab.global_position
				var hit = Geometry2D.segment_intersects_segment(start, end, point, point - Vector2(0, slab.height))
				if hit != null and start.distance_to(hit) < nearest:
					nearest = start.distance_to(hit)
					hit_type = "blocker"
			for i in 3:
				var receiver := Vector2(mirrors[i].x, 260)
				var hit = Geometry2D.segment_intersects_segment(start, end, receiver - Vector2(30, 0), receiver + Vector2(30, 0))
				if hit != null and start.distance_to(hit) < nearest:
					nearest = start.distance_to(hit)
					hit_type = "receiver"
					hit_index = i
			# Physical room boundaries terminate rays too.
			for edge in [[Vector2(20, 180), Vector2(1900, 180)], [Vector2(20, 900), Vector2(1900, 900)], [Vector2(1900, 180), Vector2(1900, 900)]]:
				var hit = Geometry2D.segment_intersects_segment(start, end, edge[0], edge[1])
				if hit != null and start.distance_to(hit) < nearest:
					nearest = start.distance_to(hit)
					hit_type = "wall"
			var point := start + direction * nearest
			points.append(point)
			if hit_type == "receiver" and hit_index == channel:
				mask |= 1 << channel
			if hit_type != "mirror":
				break
			var tangent := Vector2(1, -1 if upward[hit_index] else 1).normalized()
			var normal := Vector2(-tangent.y, tangent.x)
			direction = direction.bounce(normal)
			start = point + direction * 0.1
			previous = hit_index
		_paths.append(points)
	if channel_mask != mask:
		channel_mask = mask
		_state.set_light_channels(mask)
		channels_changed.emit(mask)
	else:
		_state.set_light_channels(mask)
	queue_redraw()

func _draw() -> void:
	for i in 3:
		var color: Color = COLORS[i]
		if i < _paths.size():
			draw_polyline(_paths[i], Color(color, 0.12), 16, true)
			draw_polyline(_paths[i], color, 3, true)
		var tangent := Vector2(1, -1 if upward[i] else 1).normalized() * 60
		draw_line(mirrors[i] - tangent, mirrors[i] + tangent, Color.WHITE if selected == i else color, 7, true)
		draw_circle(Vector2(mirrors[i].x, 260), 20, color if channel_mask & (1 << i) else Color(color, 0.15))
		draw_string(ThemeDB.fallback_font, mirrors[i] + Vector2(-45, 90), ["红", "绿", "蓝"][i] + (" · M" if selected == i else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, color)
