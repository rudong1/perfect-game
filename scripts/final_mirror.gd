extends Node2D
## The ornate mirror and its fragments share the same generated artwork.
signal shattered
const ART = preload("res://assets/props/gothic_mirror.tres")
const ART_HEIGHT := 700.0
var is_broken := false
var impact_distance := 180.0
var _outline := PackedVector2Array()
var _collision: CollisionShape2D
var _portrait: Sprite2D
var _graphic: Sprite2D
var _art_rect := Rect2()
var _source_rect := Rect2()
var _shards: Array = []
var _age := 0.0
var _passage_tween: Tween

func _ready() -> void:
	_source_rect = ART.region
	var size := _source_rect.size * (ART_HEIGHT / _source_rect.size.y)
	_art_rect = Rect2(Vector2(-size.x * 0.5, -size.y), size)
	_outline = PackedVector2Array([_art_rect.position, _art_rect.position + Vector2(size.x, 0), _art_rect.end, _art_rect.position + Vector2(0, size.y)])
	impact_distance = size.x * 0.5 + 20
	_graphic = Sprite2D.new()
	_graphic.texture = ART
	_graphic.scale = Vector2.ONE * (ART_HEIGHT / _source_rect.size.y)
	_graphic.position = Vector2(0, -ART_HEIGHT * 0.5)
	add_child(_graphic)
	var body := StaticBody2D.new()
	body.name = "GlassBody"
	body.collision_layer = 1
	_collision = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(size.x * 0.90, ART_HEIGHT - 20)
	_collision.shape = shape
	_collision.position = Vector2(0, -shape.size.y * 0.5)
	body.add_child(_collision)
	add_child(body)
	_portrait = Sprite2D.new()
	_portrait.texture = preload("res://assets/characters/hero/hero_frames.tres").get_frame_texture("idle", 0)
	_portrait.centered = false
	_portrait.offset = Vector2(-160, -342)
	_portrait.scale = Vector2(0.70, 0.70)
	_portrait.position = Vector2(0, -105)
	_portrait.flip_h = true
	_portrait.modulate = Color(0.55, 0.65, 0.72, 0.20)
	add_child(_portrait)

func reset() -> void:
	if _passage_tween != null:
		_passage_tween.kill()
	is_broken = false
	_age = 0
	_shards.clear()
	_collision.set_deferred("disabled", false)
	_portrait.visible = true
	_portrait.position = Vector2(0, -105)
	_portrait.modulate.a = 0.20
	_portrait.texture = preload("res://assets/characters/hero/hero_frames.tres").get_frame_texture("idle", 0)
	_graphic.visible = true
	queue_redraw()

func attempt_passage() -> void:
	_portrait.texture = preload("res://assets/characters/hero/hero_frames.tres").get_frame_texture("push", 0)
	_passage_tween = create_tween()
	_passage_tween.tween_property(_portrait, "modulate:a", 0.72, 0.35)
	_passage_tween.parallel().tween_property(_portrait, "position:x", -20.0, 0.35)
	_passage_tween.tween_interval(0.3)
	_passage_tween.tween_property(_portrait, "modulate:a", 0.20, 0.4)
	_passage_tween.parallel().tween_property(_portrait, "position:x", 0.0, 0.4)
	_passage_tween.tween_callback(func() -> void:
		_portrait.texture = preload("res://assets/characters/hero/hero_frames.tres").get_frame_texture("idle", 0)
	)

func shatter() -> void:
	if is_broken:
		return
	is_broken = true
	if _passage_tween != null:
		_passage_tween.kill()
	_age = 0
	_collision.set_deferred("disabled", true)
	_portrait.visible = false
	_graphic.visible = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 8401
	var grid: Array[Vector2] = []
	for row in 7:
		for column in 5:
			var point := _art_rect.position + _art_rect.size * Vector2(column / 4.0, row / 6.0)
			if column > 0 and column < 4:
				point.x += rng.randf_range(-0.15, 0.15) * _art_rect.size.x / 4.0
			if row > 0 and row < 6:
				point.y += rng.randf_range(-16, 16)
			grid.append(point)
	for row in 6:
		for column in 4:
			var i := row * 5 + column
			for triangle in [PackedVector2Array([grid[i], grid[i + 1], grid[i + 6]]), PackedVector2Array([grid[i], grid[i + 6], grid[i + 5]])]:
				var point: Vector2 = (triangle[0] + triangle[1] + triangle[2]) / 3.0
				var local := PackedVector2Array()
				var uvs := PackedVector2Array()
				for vertex in triangle:
					local.append(vertex - point)
					var unit: Vector2 = (vertex - _art_rect.position) / _art_rect.size
					uvs.append((_source_rect.position + unit * _source_rect.size) / ART.atlas.get_size())
				_shards.append({"points": local, "uvs": uvs, "position": point, "velocity": Vector2(rng.randf_range(-160, 270), rng.randf_range(-240, -80)), "angle": 0.0, "spin": rng.randf_range(-3, 3)})
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
	if not is_broken:
		return
	var alpha := clampf(1.0 - _age / 1.8, 0, 1)
	for shard in _shards:
		draw_set_transform(shard.position, shard.angle)
		var colors := PackedColorArray()
		for point in shard.points:
			colors.append(Color(1, 1, 1, alpha))
		draw_polygon(shard.points, colors, shard.uvs, ART.atlas)
		var rim: PackedVector2Array = shard.points.duplicate()
		rim.append(rim[0])
		draw_polyline(rim, Color(0.8, 0.87, 0.94, alpha * 0.25), 1, true)
	draw_set_transform(Vector2.ZERO)
