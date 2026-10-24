extends Node2D
## A real blocking mirror that breaks into deterministic, animated glass shards.
signal shattered
var is_broken := false
var _outline := PackedVector2Array()
var _collision: CollisionShape2D
var _portrait: Sprite2D
var _shards: Array = []
var _age := 0.0

func _ready() -> void:
	var scale_xy := Vector2(312.0 / 64.0, 680.0 / 143.4256)
	_outline.append(Vector2(-32, 0) * scale_xy)
	for i in 17:
		var angle := lerpf(PI, PI * 4.0 / 3.0, i / 16.0)
		_outline.append((Vector2(32, -88) + Vector2.from_angle(angle) * 64) * scale_xy)
	for i in 17:
		var angle := lerpf(-PI / 3.0, 0, i / 16.0)
		_outline.append((Vector2(-32, -88) + Vector2.from_angle(angle) * 64) * scale_xy)
	_outline.append(Vector2(32, 0) * scale_xy)
	# The two sampled arcs meet at the same apex. Remove near-duplicates at
	# this larger scale before triangulating the fill or generating shards.
	_outline = Geometry2D.convex_hull(_outline)
	_outline.remove_at(_outline.size() - 1)
	var body := StaticBody2D.new()
	body.name = "GlassBody"
	body.collision_layer = 1
	_collision = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(240, 660)
	_collision.shape = shape
	_collision.position = Vector2(0, -330)
	body.add_child(_collision)
	add_child(body)
	_portrait = Sprite2D.new()
	_portrait.texture = preload("res://assets/characters/hero/hero_frames.tres").get_frame_texture("idle", 0)
	_portrait.centered = false
	_portrait.offset = Vector2(-160, -342)
	_portrait.scale = Vector2(0.87, 0.87)
	_portrait.position = Vector2(0, -100)
	_portrait.flip_h = true
	_portrait.modulate = Color(0.65, 0.75, 0.84, 0.28)
	add_child(_portrait)

func reset() -> void:
	is_broken = false
	_age = 0
	_shards.clear()
	_collision.set_deferred("disabled", false)
	_portrait.visible = true
	queue_redraw()

func shatter() -> void:
	if is_broken:
		return
	is_broken = true
	_age = 0
	_collision.set_deferred("disabled", true)
	_portrait.visible = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 8401
	var grid: Array[Vector2] = []
	for row in 7:
		for column in 5:
			var point := Vector2(-156 + column * 78, -680 + row * (680.0 / 6.0))
			if column > 0 and column < 4:
				point.x += rng.randf_range(-16, 16)
			if row > 0 and row < 6:
				point.y += rng.randf_range(-20, 20)
			grid.append(point)
	for row in 6:
		for column in 4:
			var i := row * 5 + column
			var a := grid[i]
			var b := grid[i + 1]
			var c := grid[i + 6]
			var d := grid[i + 5]
			for triangle in [PackedVector2Array([a, b, c]), PackedVector2Array([a, c, d])]:
				for clipped in Geometry2D.intersect_polygons(triangle, _outline):
					if Geometry2D.triangulate_polygon(clipped).is_empty():
						continue
					var point := Vector2.ZERO
					for vertex in clipped:
						point += vertex
					point /= clipped.size()
					var local := PackedVector2Array()
					for vertex in clipped:
						local.append(vertex - point)
					_shards.append({"points": local, "position": point, "velocity": Vector2(rng.randf_range(-160, 270), rng.randf_range(-240, -80)), "angle": 0.0, "spin": rng.randf_range(-3, 3)})
	shattered.emit()
	queue_redraw()

func _process(delta: float) -> void:
	if not is_broken:
		return
	_age += delta
	for shard in _shards:
		shard.velocity.y += 700 * delta
		shard.position += shard.velocity * delta
		shard.angle += shard.spin * delta
	queue_redraw()

func _draw() -> void:
	if is_broken:
		var alpha := clampf(1.0 - _age / 1.8, 0, 1)
		for shard in _shards:
			draw_set_transform(shard.position, shard.angle)
			draw_colored_polygon(shard.points, Color(0.5, 0.65, 0.75, 0.42 * alpha))
			var rim: PackedVector2Array = shard.points.duplicate()
			rim.append(rim[0])
			draw_polyline(rim, Color(0.8, 0.87, 0.94, alpha), 1.5, true)
		draw_set_transform(Vector2.ZERO)
		return
	draw_colored_polygon(_outline, Color("#14252B"))
	var rim := _outline.duplicate()
	rim.append(rim[0])
	draw_polyline(rim, Color("#B7C5CF"), 8, true)
	var inner := PackedVector2Array()
	for point in rim:
		inner.append(Vector2(0, -340) + (point - Vector2(0, -340)) * 0.95)
	draw_polyline(inner, Color("#C9A227"), 2, true)
	for i in 3:
		var x := -62.0 + i * 62
		draw_line(Vector2(x, -580), Vector2(x + 35, -130), Color(0.65, 0.8, 0.9, 0.16), 9)
